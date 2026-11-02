// Streams backup files to/from a place the user picks (Android "save as" / "open"), via our own channel. Backups
// are already encrypted; they are staged inside app storage only.
import 'dart:io';

import 'package:flutter/services.dart';

const _ch = MethodChannel('ledgerlock/files');

/// Returns true if saved, false if the user cancelled.
Future<bool> saveBackupWithPicker(File staged, String name) async =>
    await _ch.invokeMethod<bool>('saveBackup', {'path': staged.path, 'name': name}) ?? false;

/// Copies the picked file to [dest]. Returns true if a file was picked.
Future<bool> pickBackupTo(File dest) async => await _ch.invokeMethod<bool>('pickBackup', {'dest': dest.path}) ?? false;
