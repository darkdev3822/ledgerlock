// An unlocked session: the data key plus everything opened with it.
// lock() closes the database and wipes the keys we hold.
import 'dart:io';
import 'dart:typed_data';

import '../data/database.dart';
import 'crypto.dart';
import 'encrypted_file_store.dart';
import 'vault.dart';

class Session {
  final AppDatabase db;
  final EncryptedFileStore files;
  final Vault vault;

  /// Kept while unlocked so recovery methods can be (re)configured.
  final Uint8List dataKey;
  final List<Uint8List> _keys;

  Session._(this.db, this.files, this.vault, this.dataKey, this._keys);

  /// Unlocks (or, on first launch, creates) the vault with the master password.
  static Future<Session> open(Directory dir, String password, {Vault? vault}) async {
    final v = vault ?? Vault(dir);
    final dataKey = v.exists ? await v.unlock(password) : await v.create(password);
    return fromDataKey(dir, dataKey, v);
  }

  /// Opens the encrypted stores with a data key from any vault slot. Takes ownership of [dataKey].
  static Future<Session> fromDataKey(Directory dir, Uint8List dataKey, Vault vault) async {
    try {
      final dbKey = await LedgerCrypto.subkey(dataKey, 'db');
      final fileKey = await LedgerCrypto.subkey(dataKey, 'files');
      final db = AppDatabase.open(File('${dir.path}/ledger.db'), dbKey);
      await db.customSelect('SELECT 1').get(); // surface key errors now
      return Session._(db, EncryptedFileStore(Directory('${dir.path}/files'), fileKey), vault, dataKey, [
        dbKey,
        fileKey,
        dataKey,
      ]);
    } catch (_) {
      LedgerCrypto.zero(dataKey);
      rethrow;
    }
  }

  Future<void> lock() async {
    files.close(); // first, synchronously: nothing may encrypt with the key once zeroing starts
    await db.close();
    for (final k in _keys) {
      LedgerCrypto.zero(k);
    }
  }
}
