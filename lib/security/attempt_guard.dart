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

class AttemptGuard {
  final File file;
  final DateTime Function() _now;
  AttemptGuard(Directory dir, {DateTime Function()? now})
    : file = File('${dir.path}/attempts.json'),
      _now = now ?? DateTime.now;

  /// Lockout after the Nth consecutive failure (N >= 5).
  static Duration lockoutFor(int failures) => switch (failures) {
    < 5 => Duration.zero,
    5 => const Duration(seconds: 30),
    6 => const Duration(minutes: 1),
    7 => const Duration(minutes: 5),
    8 => const Duration(minutes: 15),
    _ => const Duration(hours: 1),
  };

  (int, DateTime?) _read() {
    try {
      final j = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final t = j['last'] as int?;
      return (j['failures'] as int? ?? 0, t == null ? null : DateTime.fromMillisecondsSinceEpoch(t));
    } catch (_) {
      return (0, null);
    }
  }

  void _write(int failures, DateTime? last) {
    final tmp = File('${file.path}.tmp');
    tmp.writeAsStringSync(
      jsonEncode({'failures': failures, 'last': last?.millisecondsSinceEpoch}),
      flush: true,
    );
    tmp.renameSync(file.path);
  }

  /// Time left before another guess is allowed (zero if allowed now).
  Duration remaining() {
    final (failures, last) = _read();
    if (last == null) return Duration.zero;
    final lock = lockoutFor(failures);
    if (lock == Duration.zero) return Duration.zero;
    final now = _now();
    // Clock moved backwards: don't let that shorten the lockout.
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
    final (failures, _) = _read();
    _write(failures + 1, _now());
  }

  void reset() {
    if (file.existsSync()) _write(0, null);
  }

  int get failures => _read().$1;
}
