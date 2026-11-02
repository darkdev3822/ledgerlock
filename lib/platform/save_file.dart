// Saves bytes where the user chooses (Android "save as" picker) via our own channel. No storage permission,
// no copy in app storage. Returns true if saved, false if cancelled.
import 'package:flutter/services.dart';

const _ch = MethodChannel('ledgerlock/files');

Future<bool> saveWithPicker(String name, Uint8List bytes, {String mime = 'text/csv'}) async {
  final ok = await _ch.invokeMethod<bool>('save', {'name': name, 'bytes': bytes, 'mime': mime});
  return ok ?? false;
}
