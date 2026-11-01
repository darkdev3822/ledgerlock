// Picks a file and returns its bytes WITHOUT a plaintext copy in app storage.
// Android: MainActivity's "ledgerlock/files" channel (SAF content URI -> bytes). iOS: to do (M10).
import 'package:flutter/services.dart';

class PickedFile {
  final String name;
  final String mime;
  final Uint8List bytes;
  const PickedFile(this.name, this.mime, this.bytes);
}

class PickTooLarge implements Exception {
  const PickTooLarge();
}

abstract class DocumentPicker {
  Future<PickedFile?> pick({List<String> mimeTypes = const ['image/*', 'application/pdf']});
}

class ChannelDocumentPicker implements DocumentPicker {
  static const _ch = MethodChannel('ledgerlock/files');

  @override
  Future<PickedFile?> pick({List<String> mimeTypes = const ['image/*', 'application/pdf']}) async {
    try {
      final r = await _ch.invokeMapMethod<String, Object?>('pick', {'mimeTypes': mimeTypes});
      if (r == null) return null;
      return PickedFile(r['name'] as String, r['mime'] as String, r['bytes'] as Uint8List);
    } on PlatformException catch (e) {
      if (e.code == 'too_large') throw const PickTooLarge();
      rethrow;
    }
  }
}
