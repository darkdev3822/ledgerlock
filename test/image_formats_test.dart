// Found in the OCR device check: a 16-bit RGBA PNG came out of the receipt pipeline as colour noise.
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:ledgerlock/media/receipt_image.dart';

/// White page with a black bar, in the given format.
img.Image _page(img.Format format, int channels) {
  final im = img.Image(width: 120, height: 80, format: format, numChannels: channels);
  final max = format == img.Format.uint16 ? 65535 : 255;
  for (final p in im) {
    final ink = p.y > 30 && p.y < 50 && p.x > 20 && p.x < 100;
    final v = ink ? 0 : max;
    p
      ..r = v
      ..g = v
      ..b = v;
    if (channels == 4) p.a = max;
  }
  return im;
}

void main() {
  for (final (name, fmt, ch) in [
    ('16-bit RGBA', img.Format.uint16, 4),
    ('16-bit RGB', img.Format.uint16, 3),
    ('8-bit RGBA', img.Format.uint8, 4),
  ]) {
    test('$name PNG survives decode -> JPEG as a readable 8-bit page', () {
      final decoded = safeDecode(img.encodePng(_page(fmt, ch)))!;
      expect(decoded.format, img.Format.uint8);
      expect(decoded.numChannels, 3);
      final back = img.decodeJpg(img.encodeJpg(decoded, quality: 90))!;
      expect(back.getPixel(5, 5).luminance, greaterThan(230), reason: 'paper stays white');
      expect(back.getPixel(60, 40).luminance, lessThan(40), reason: 'ink stays dark');
    });
  }

  test('transparent areas become white, not black', () {
    final im = img.Image(width: 10, height: 10, numChannels: 4); // all transparent
    final d = safeDecode(img.encodePng(im))!;
    expect(d.getPixel(3, 3).luminance, greaterThan(240));
  });
}
