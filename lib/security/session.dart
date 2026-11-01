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
  final List<Uint8List> _keys;

  Session._(this.db, this.files, this._keys);

  /// Unlocks (or, on first launch, creates) the vault in [dir].
  static Future<Session> open(Directory dir, String password, {Vault? vault}) async {
    final v = vault ?? Vault(dir);
    final dataKey = v.exists ? await v.unlock(password) : await v.create(password);
    try {
      final dbKey = await LedgerCrypto.subkey(dataKey, 'db');
      final fileKey = await LedgerCrypto.subkey(dataKey, 'files');
      final db = AppDatabase.open(File('${dir.path}/ledger.db'), dbKey);
      await db.customSelect('SELECT 1').get(); // surface key errors now
      return Session._(db, EncryptedFileStore(Directory('${dir.path}/files'), fileKey), [dbKey, fileKey]);
    } finally {
      LedgerCrypto.zero(dataKey);
    }
  }

  Future<void> lock() async {
    await db.close();
    for (final k in _keys) {
      LedgerCrypto.zero(k);
    }
  }
}
