// On-device OCR via our own channel (Kotlin Ocr.kt, Tesseract). Bytes go over the channel in memory; no plaintext
// image file is written. Returns null when OCR isn't available (tests, iOS until M10) or fails.
import 'package:flutter/services.dart';

const _ch = MethodChannel('ledgerlock/files');

Future<String?> recognizeText(Uint8List imageBytes) async {
  try {
    return await _ch.invokeMethod<String>('ocr', {'bytes': imageBytes});
  } on PlatformException {
    return null;
  } on MissingPluginException {
    return null;
  }
}
