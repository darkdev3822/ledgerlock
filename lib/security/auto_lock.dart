// Auto-lock after N minutes in the background (SPEC §1, default 1 min), and a
// privacy cover flag for the app switcher.
import 'package:flutter/widgets.dart';

class AutoLock with WidgetsBindingObserver {
  Duration timeout;
  final VoidCallback onLock;
  final ValueNotifier<bool> coverVisible = ValueNotifier(false);
  final DateTime Function() _now;
  DateTime? _backgroundedAt;

  AutoLock({required this.onLock, this.timeout = const Duration(minutes: 1), DateTime Function()? now})
    : _now = now ?? DateTime.now;

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
        _backgroundedAt ??= _now();
      case AppLifecycleState.resumed:
        final since = _backgroundedAt;
        _backgroundedAt = null;
        if (since != null && _now().difference(since) >= timeout) onLock();
        coverVisible.value = false;
      case AppLifecycleState.detached:
        onLock();
    }
  }
}
