// SQLCipher database via drift. Opened with a raw 256-bit key (no SQLCipher
// passphrase KDF needed: the key already comes from Argon2id + HKDF).
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

part 'database.g.dart';

/// Key/value app settings (e.g. auto-lock minutes). Ledger tables arrive in M3.
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}

class NotEncrypted implements Exception {
  @override
  String toString() => 'SQLCipher not available: refusing to open an unencrypted database';
}

@DriftDatabase(tables: [Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Opens [file] encrypted with [key]. Fails closed if SQLCipher isn't linked.
  /// A wrong key surfaces as an error on the first query.
  factory AppDatabase.open(File file, Uint8List key) {
    final hex = key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return AppDatabase(NativeDatabase.createInBackground(
      file,
      setup: (db) {
        final v = db.select('PRAGMA cipher_version');
        if (v.isEmpty || (v.first.values.first as String?)?.isEmpty != false) {
          throw NotEncrypted();
        }
        db.execute("PRAGMA key = \"x'$hex'\"");
        // Verifies the key now (throws "file is not a database" if wrong).
        db.select('SELECT count(*) FROM sqlite_master');
        db.execute('PRAGMA foreign_keys = ON');
      },
    ));
  }

  @override
  int get schemaVersion => 1;

  Future<String?> getSetting(String k) async =>
      (await (select(settings)..where((s) => s.key.equals(k))).getSingleOrNull())?.value;

  Future<void> setSetting(String k, String v) =>
      into(settings).insertOnConflictUpdate(SettingsCompanion.insert(key: k, value: v));
}
