// Screenshot / screen-recording / recents-thumbnail blocking (SECURITY.md T22). On by default from app start
// (MainActivity.onCreate); the user may allow screenshots while unlocked. Always back on when locked.
import 'package:flutter/services.dart';

const _ch = MethodChannel('ledgerlock/files');

Future<void> setSecureWindow(bool on) async {
  try {
    await _ch.invokeMethod<void>('setSecure', {'on': on});
  } on MissingPluginException {
    // tests / non-Android
  } on PlatformException {
    // best effort
  }
}
