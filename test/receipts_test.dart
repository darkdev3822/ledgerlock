import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:ledgerlock/data/database.dart';
import 'package:ledgerlock/media/documents.dart';
import 'package:ledgerlock/media/receipt_image.dart';
import 'package:ledgerlock/security/crypto.dart';
import 'package:ledgerlock/security/encrypted_file_store.dart';

/// Dark background with a bright, slightly rotated "receipt".
img.Image scene() {
  final im = img.Image(width: 600, height: 800);
  img.fill(im, color: img.ColorRgb8(40, 45, 50));
  final corners = [img.Point(170, 110), img.Point(470, 140), img.Point(440, 700), img.Point(130, 670)];
  img.fillPolygon(im, vertices: corners, color: img.ColorRgb8(245, 245, 240));
  return im;
}

bool containsJpegMagic(List<int> b) {
  for (var i = 0; i + 2 < b.length; i++) {
    if (b[i] == 0xFF && b[i + 1] == 0xD8 && b[i + 2] == 0xFF) return true;
  }
  return false;
}

void main() {
  test('YUV420 with padded strides converts to the right colours and rotates', () {
    const w = 4, h = 2, pad = 3;
    // Y=235 (bright) everywhere, neutral chroma -> near-white.
    final y = Uint8List((w + pad) * h)..fillRange(0, (w + pad) * h, 235);
    final uv = Uint8List((w + pad) * (h ~/ 2))..fillRange(0, (w + pad) * (h ~/ 2), 128);
    final f = YuvFrame(
      width: w,
      height: h,
      y: y,
      u: uv,
      v: Uint8List.fromList(uv),
      yRowStride: w + pad,
      uvRowStride: w + pad,
      uvPixelStride: 2,
      rotationDegrees: 90,
    );
    final im = yuvToImage(f);
    expect((im.width, im.height), (2, 4), reason: 'rotated 90°');
    final p = im.getPixel(0, 0);
    expect([p.r, p.g, p.b], [235, 235, 235]);
  });

  test('detects the receipt corners within a few percent', () {
    final q = detectCorners(scene());
    final want = [
      const math.Point(170.0, 110.0),
      const math.Point(470.0, 140.0),
      const math.Point(440.0, 700.0),
      const math.Point(130.0, 670.0),
    ];
    for (var i = 0; i < 4; i++) {
      expect(q.points[i].distanceTo(want[i]), lessThan(25), reason: 'corner $i: ${q.points[i]}');
    }
  });

  test('falls back to an inset frame when there is no clear receipt', () {
    final flat = img.Image(width: 300, height: 400);
    img.fill(flat, color: img.ColorRgb8(128, 128, 128));
    final q = detectCorners(flat);
    expect(q.points.first.x, closeTo(300 * 0.06, 1));
  });

  test('rectify produces an upright receipt-shaped JPEG and thumbnail', () {
    final src = scene();
    final r = finishReceipt(src, detectCorners(src));
    final out = img.decodeJpg(r.jpeg)!;
    expect(out.height, greaterThan(out.width), reason: 'portrait receipt');
    final centre = out.getPixel(out.width ~/ 2, out.height ~/ 2);
    expect(centre.r, greaterThan(200), reason: 'cropped to the bright paper');
    expect(math.max(img.decodeJpg(r.thumbJpeg)!.width, img.decodeJpg(r.thumbJpeg)!.height), 320);
  });

  group('Documents (encrypted on disk)', () {
    late Directory dir;
    late AppDatabase db;
    late Documents docs;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('ll_docs');
      db = AppDatabase.open(File('${dir.path}/d.db'), LedgerCrypto.randomBytes(32));
      docs = Documents(db, EncryptedFileStore(Directory('${dir.path}/files'), LedgerCrypto.randomBytes(32)));
    });
    tearDown(() async {
      await db.close();
      dir.deleteSync(recursive: true);
    });

    test('no plaintext JPEG/PDF bytes anywhere on disk; delete removes files', () async {
      final r = finishReceipt(scene(), detectCorners(scene()));
      final id = await docs.saveReceipt(r, year: 2026);
      final pdf = Uint8List.fromList('%PDF-1.7 W-2 Wage and Tax Statement'.codeUnits);
      await docs.importFile(name: 'w2.pdf', mime: 'application/pdf', bytes: pdf, folder: 'tax_form', year: 2026);

      final files = dir.listSync(recursive: true).whereType<File>().toList();
      for (final f in files) {
        final b = f.readAsBytesSync();
        expect(containsJpegMagic(b), isFalse, reason: f.path);
        expect(String.fromCharCodes(b).contains('%PDF'), isFalse, reason: f.path);
        expect(String.fromCharCodes(b).contains('Wage and Tax'), isFalse, reason: f.path);
      }

      final a = (await db.attachment(id))!;
      expect(await docs.read(a), r.jpeg);
      expect(await docs.thumbnail(a), r.thumbJpeg);
      await docs.delete(a);
      expect(await db.attachment(id), isNull);
      expect(Directory('${dir.path}/files').listSync().length, 1, reason: 'only the PDF remains');
    });

    test('deleting a record keeps its receipt as unmatched', () async {
      final entry = await db.addEntry(
        LedgerEntriesCompanion.insert(
          isIncome: false,
          date: '2026-05-01',
          amountCents: 999,
          category: 'supplies',
          party: const Value('Staples'),
        ),
      );
      final r = finishReceipt(scene(), detectCorners(scene()));
      final id = await docs.saveReceipt(r, year: 2026, entryId: entry);
      expect((await db.watchEntryAttachments(entry).first).single.id, id);
      await db.deleteEntry(entry);
      expect((await db.attachment(id))!.entryId, isNull);
      expect(await db.receiptCount(2026), 1);
    });
  });
}
