// Receipts and vault documents: encrypted bytes in EncryptedFileStore, metadata in the database.
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;

import '../data/database.dart';
import '../security/encrypted_file_store.dart';
import 'receipt_image.dart';

/// Vault folders (SPEC §2.8). 'receipt' items can link to a ledger entry.
const vaultFolders = <String, String>{
  'tax_form': 'W-2 & 1099s',
  'receipt': 'Receipts',
  'prior_return': 'Prior returns',
  'letter': 'Letters',
  'other': 'Other',
};

class Documents {
  final AppDatabase db;
  final EncryptedFileStore files;
  Documents(this.db, this.files);

  Future<int> saveReceipt(
    ProcessedReceipt r, {
    required int year,
    int? entryId,
    String name = 'Receipt',
  }) async {
    final fileId = await files.put(r.jpeg);
    final thumbId = await files.put(r.thumbJpeg);
    return db.addAttachment(
      AttachmentsCompanion.insert(
        folder: 'receipt',
        year: year,
        entryId: Value(entryId),
        fileId: fileId,
        thumbId: Value(thumbId),
        name: Value(name),
        mime: 'image/jpeg',
        sizeBytes: r.jpeg.length,
      ),
    );
  }

  Future<int> importFile({
    required String name,
    required String mime,
    required Uint8List bytes,
    required String folder,
    required int year,
    int? entryId,
  }) async {
    final fileId = await files.put(bytes);
    final thumb = mime.startsWith('image/') ? thumbnailFor(bytes) : null;
    final thumbId = thumb == null ? null : await files.put(thumb);
    return db.addAttachment(
      AttachmentsCompanion.insert(
        folder: folder,
        year: year,
        entryId: Value(entryId),
        fileId: fileId,
        thumbId: Value(thumbId),
        name: Value(name),
        mime: mime,
        sizeBytes: bytes.length,
      ),
    );
  }

  Future<Uint8List> read(Attachment a) => files.get(a.fileId);

  Future<Uint8List?> thumbnail(Attachment a) async => a.thumbId == null ? null : files.get(a.thumbId!);

  Future<void> delete(Attachment a) async {
    await db.deleteAttachmentRow(a.id);
    await files.delete(a.fileId);
    if (a.thumbId != null) await files.delete(a.thumbId!);
  }
}
