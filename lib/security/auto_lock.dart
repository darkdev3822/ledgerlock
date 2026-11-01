// Auto-lock after N minutes in the background (SPEC §1, default 1 min), and a
// privacy cover flag for the app switcher. Uses a monotonic clock, so changing the
// phone's time can't skip the lock (SECURITY.md T3).
import 'package:flutter/widgets.dart';

class AutoLock with WidgetsBindingObserver {
  Duration timeout;
  final VoidCallback onLock;
  final ValueNotifier<bool> coverVisible = ValueNotifier(false);

  /// Monotonic time since an arbitrary origin.
  final Duration Function() _elapsed;
  Duration? _backgroundedAt;

  static final Stopwatch _clock = Stopwatch()..start();

  AutoLock({required this.onLock, this.timeout = const Duration(minutes: 1), Duration Function()? elapsed})
    : _elapsed = elapsed ?? (() => _clock.elapsed);

  void attach() => WidgetsBinding.instance.addObserver(this);
  void detach() => WidgetsBinding.instance.removeObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        coverVisible.value = true;
      case AppLifecycleState.paused:
        coverVisible.value = true;
        _backgroundedAt ??= _elapsed();
      case AppLifecycleState.resumed:
        final since = _backgroundedAt;
        _backgroundedAt = null;
        if (since != null && _elapsed() - since >= timeout) onLock();
        coverVisible.value = false;
      case AppLifecycleState.detached:
        onLock();
    }
  }
}
