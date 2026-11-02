// Throttles guesses at the password / recovery key / security answers (SECURITY.md T1).
// Argon2id already costs ~0.5 s per guess; this adds escalating lockouts after 5 misses.
// State is a tiny non-secret file next to the vault so restarting the app doesn't reset it.
import 'dart:convert';
import 'dart:io';

class TooManyAttempts implements Exception {
  final Duration wait;
  const TooManyAttempts(this.wait);
  @override
  String toString() => 'TooManyAttempts(${wait.inSeconds}s)';
}

/// Time since boot from /proc/uptime (Linux/Android, readable without permissions). The user can't set it, unlike
/// the wall clock. Null where unavailable.
Duration? bootUptime() {
  try {
    final secs = double.parse(File('/proc/uptime').readAsStringSync().split(' ').first);
    return Duration(milliseconds: (secs * 1000).round());
  } catch (_) {
    return null;
  }
}

class AttemptGuard {
  final File file;
  final DateTime Function() _now;
  final Duration? Function() _uptime;
  AttemptGuard(Directory dir, {DateTime Function()? now, Duration? Function()? uptime})
    : file = File('${dir.path}/attempts.json'),
      _now = now ?? DateTime.now,
      _uptime = uptime ?? bootUptime;

  /// Lockout after the Nth consecutive failure (N >= 5).
  static Duration lockoutFor(int failures) => switch (failures) {
    < 5 => Duration.zero,
    5 => const Duration(seconds: 30),
    6 => const Duration(minutes: 1),
    7 => const Duration(minutes: 5),
    8 => const Duration(minutes: 15),
    _ => const Duration(hours: 1),
  };

  (int, DateTime?, int?) _read() {
    try {
      final j = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final t = j['last'] as int?;
      return (j['failures'] as int? ?? 0, t == null ? null : DateTime.fromMillisecondsSinceEpoch(t), j['up'] as int?);
    } catch (_) {
      return (0, null, null);
    }
  }

  void _write(int failures, DateTime? last, int? up) {
    final tmp = File('${file.path}.tmp');
    tmp.writeAsStringSync(
      jsonEncode({'failures': failures, 'last': last?.millisecondsSinceEpoch, 'up': up}),
      flush: true,
    );
    tmp.renameSync(file.path);
  }

  /// Time left before another guess is allowed (zero if allowed now).
  ///
  /// Measured on time-since-boot when available, so changing the wall clock (backwards OR forwards) can't shorten
  /// a lockout (SECURITY.md T1, T20). After a reboot that clock restarts and we can't know how long the phone was
  /// off, so the lockout restarts in full from the first check after boot: rebooting gains an attacker nothing.
  Duration remaining() {
    final (failures, last, up) = _read();
    if (last == null) return Duration.zero;
    final lock = lockoutFor(failures);
    if (lock == Duration.zero) return Duration.zero;
    final upNow = _uptime();
    if (upNow != null && up != null) {
      if (upNow.inMilliseconds < up) {
        _write(failures, _now(), upNow.inMilliseconds); // rebooted: restart the lockout from now
        return lock;
      }
      final left = lock - Duration(milliseconds: upNow.inMilliseconds - up);
      return left.isNegative ? Duration.zero : left;
    }
    final now = _now();
    // No boot clock (tests, other platforms): wall clock, and a clock moved backwards never shortens the lockout.
    if (now.isBefore(last)) return lock;
    final left = last.add(lock).difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  /// Throws [TooManyAttempts] while locked out.
  void check() {
    final r = remaining();
    if (r > Duration.zero) throw TooManyAttempts(r);
  }

  void recordFailure() {
    final (failures, _, _) = _read();
    _write(failures + 1, _now(), _uptime()?.inMilliseconds);
  }

  void reset() {
    if (file.existsSync()) _write(0, null, null);
  }

  int get failures => _read().$1;
}
