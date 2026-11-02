// Fuzz: safeDecode / normalize8 with valid, mutated, truncated and dimension-forged images of every format
// the image package auto-detects (PNG, JPEG, GIF, BMP, TGA, TIFF, ICO, PNM, PSD, EXR, WebP headers).
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:ledgerlock/media/receipt_image.dart';

import 'fuzz_util.dart';

img.Image sample(Random r, img.Format f, int ch, {bool palette = false}) {
  final w = 1 + r.nextInt(24), h = 1 + r.nextInt(24);
  var im = img.Image(width: w, height: h, format: f, numChannels: ch);
  for (final p in im) {
    p
      ..r = r.nextInt(p.maxChannelValue.toInt() + 1)
      ..g = r.nextInt(p.maxChannelValue.toInt() + 1)
      ..b = r.nextInt(p.maxChannelValue.toInt() + 1)
      ..a = r.nextInt(p.maxChannelValue.toInt() + 1);
  }
  if (palette) im = img.quantize(im, numberOfColors: 16);
  return im;
}

List<Uint8List> seeds(Random r) {
  final out = <Uint8List>[];
  for (final (f, ch, pal) in [
    (img.Format.uint8, 3, false),
    (img.Format.uint8, 4, false),
    (img.Format.uint8, 1, false),
    (img.Format.uint8, 2, false),
    (img.Format.uint16, 4, false),
    (img.Format.uint16, 3, false),
    (img.Format.uint16, 1, false),
    (img.Format.uint8, 3, true),
  ]) {
    final im = sample(r, f, ch, palette: pal);
    out.add(img.encodePng(im));
    if (f == img.Format.uint8) {
      out
        ..add(img.encodeJpg(im.convert(numChannels: 3)))
        ..add(img.encodeBmp(im))
        ..add(img.encodeTga(im))
        ..add(img.encodeTiff(im))
        ..add(img.encodeIco(im.convert(numChannels: 4)))
        ..add(img.encodeGif(im.convert(numChannels: 3)));
    }
  }
  out
    ..add(img.encodePng(img.Image(width: 1, height: 1)))
    ..add(Uint8List.fromList('P1\n2 2\n0 1 1 0\n'.codeUnits))
    ..add(Uint8List.fromList('P6\n2 1\n255\n\x00\x01\x02\x03\x04\x05'.codeUnits))
    ..add(Uint8List.fromList([...'RIFF'.codeUnits, 30, 0, 0, 0, ...'WEBPVP8 '.codeUnits, ...List.filled(18, 7)]));
  return out;
}

/// Hand-built PNG of all-zero pixels (tiny when compressed): [depth] bits, [color] PNG colour type.
Uint8List chunk(String type, List<int> data) {
  final b = BytesBuilder();
  final len = ByteData(4)..setUint32(0, data.length);
  b.add(len.buffer.asUint8List());
  final td = [...type.codeUnits, ...data];
  b.add(td);
  var c = 0xFFFFFFFF;
  for (final x in td) {
    c ^= x;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? (c >> 1) ^ 0xEDB88320 : c >> 1;
    }
  }
  b.add((ByteData(4)..setUint32(0, c ^ 0xFFFFFFFF)).buffer.asUint8List());
  return b.toBytes();
}

Uint8List png16(int w, int h, {int depth = 16, int color = 6}) {
  final bpp = (depth ~/ 8) * {6: 4, 2: 3, 0: 1, 4: 2}[color]!;
  final row = Uint8List(1 + w * bpp);
  final out = BytesBuilder();
  final sink = ZLibEncoder().startChunkedConversion(
    ChunkedConversionSink<List<int>>.withCallback((cs) {
      for (final c in cs) {
        out.add(c);
      }
    }),
  );
  for (var y = 0; y < h; y++) {
    sink.add(row);
  }
  sink.close();
  final ihdr =
      (ByteData(13)
            ..setUint32(0, w)
            ..setUint32(4, h)
            ..setUint8(8, depth)
            ..setUint8(9, color))
          .buffer
          .asUint8List();
  return Uint8List.fromList([
    137,
    80,
    78,
    71,
    13,
    10,
    26,
    10,
    ...chunk('IHDR', ihdr),
    ...chunk('IDAT', out.toBytes()),
    ...chunk('IEND', []),
  ]);
}

void checkResult(img.Image? im) {
  if (im == null) return;
  expect(im.format, img.Format.uint8);
  expect(im.numChannels, 3);
  expect(im.hasPalette, isFalse);
  expect(im.width * im.height, lessThanOrEqualTo(maxDecodePixels));
}

void main() {
  test('safeDecode: valid seeds of every format decode to 8-bit RGB', () {
    final r = Random(30);
    final failed = <String>[];
    for (var it = 0; it < 4; it++) {
      for (final (i, s) in seeds(r).indexed) {
        final im = timed(() => safeDecode(s), input: s.take(16).toList());
        checkResult(im);
        // ICO is never decoded (IcoInfo reports 0x0, safeDecode rejects it); the WebP seed is junk on purpose.
        final expectNull = (s[0] == 0 && s[1] == 0 && s[2] == 1) || s[0] == 0x52;
        if (im == null && !expectNull) {
          failed.add('seed $i ${String.fromCharCodes(s.take(4).where((c) => c > 31 && c < 127))}');
        }
      }
    }
    expect(failed, isEmpty);
  });

  test('safeDecode: mutated / truncated / spliced bytes never throw, hang or return odd formats', () {
    final r = Random(31);
    final base = seeds(r);
    for (var it = 0; it < 6000; it++) {
      final s = Uint8List.fromList(base[r.nextInt(base.length)]);
      Uint8List b;
      switch (r.nextInt(4)) {
        case 0:
          for (var k = 0; k < 1 + r.nextInt(8); k++) {
            s[r.nextInt(s.length)] = r.nextInt(256);
          }
          b = s;
        case 1:
          b = Uint8List.sublistView(s, 0, r.nextInt(s.length + 1));
        case 2:
          // Header field smash: bytes 0..40 hold the dimensions in most formats.
          final i = r.nextInt(min(40, s.length));
          s[i] = 0xFF;
          if (i + 1 < s.length) s[i + 1] = 0xFF;
          b = s;
        default:
          b = Uint8List.fromList([...s.take(r.nextInt(64)), ...List.generate(r.nextInt(400), (_) => r.nextInt(256))]);
      }
      checkResult(timed(() => safeDecode(b), input: b.take(24).toList()));
    }
  });

  test('safeDecode: pure random bytes', () {
    final r = Random(32);
    for (var it = 0; it < 5000; it++) {
      final b = Uint8List.fromList(List.generate(r.nextInt(600), (_) => r.nextInt(256)));
      checkResult(timed(() => safeDecode(b), input: b.take(24).toList()));
    }
  });

  test('forged dimensions are refused before decoding (T2 regression), odd 1x1 formats normalise', () {
    final huge = png16(1, 1);
    // Patch IHDR width/height to 100000 x 100000 (CRC now wrong too: must still be refused, fast).
    final bd = ByteData.sublistView(huge);
    bd.setUint32(16, 100000);
    bd.setUint32(20, 100000);
    expect(timed(() => safeDecode(huge)), isNull);
    for (final (d, c) in [(16, 6), (16, 4), (16, 0), (8, 4), (8, 0), (16, 2), (8, 6)]) {
      final im = timed(
        () => safeDecode(png16(1, 1, depth: d, color: c)),
        input: '$d/$c',
      );
      checkResult(im);
      expect(im, isNotNull, reason: 'depth $d colour $c');
      // Transparent black on white paper -> white.
      if (c == 6 || c == 4) expect(im!.getPixel(0, 0).r, 255);
    }
  });

  test('F9 a 300 KB 16-bit RGBA PNG under the 40 MP cap costs ~450 MB and ~2 s (cap counts pixels, not bytes)', () {
    final b = png16(6324, 6324); // 39.99 MP, 311 KB file
    final rss0 = ProcessInfo.currentRss;
    final sw = Stopwatch()..start();
    final im = safeDecode(b);
    expect(
      im == null,
      isTrue,
      reason: 'decoded in ${sw.elapsedMilliseconds} ms, +${(ProcessInfo.maxRss - rss0) >> 20} MB peak',
    );
  });
}
