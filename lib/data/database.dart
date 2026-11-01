// SQLCipher database via drift. Opened with a raw 256-bit key (no SQLCipher
// passphrase KDF needed: the key already comes from Argon2id + HKDF).
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'ledger.dart';

part 'database.g.dart';

/// Key/value app settings (e.g. auto-lock minutes).
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}

/// Income and expense records (SPEC §2.2). Money in integer cents; dates as 'YYYY-MM-DD'.
@DataClassName('LedgerEntry')
class LedgerEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  BoolColumn get isIncome => boolean()();
  TextColumn get date => text().withLength(min: 10, max: 10)();
  IntColumn get amountCents => integer()();
  IntColumn get feeCents => integer().withDefault(const Constant(0))();
  IntColumn get businessPct => integer().withDefault(const Constant(100))();
  TextColumn get category => text()();
  TextColumn get party => text().withDefault(const Constant(''))();
  TextColumn get platform => text().withDefault(const Constant(''))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

extension LedgerEntryMaths on LedgerEntry {
  DateTime get day => DateTime.parse(date);
  EntryData get data => EntryData(
    isIncome: isIncome,
    date: day,
    amountCents: amountCents,
    feeCents: feeCents,
    businessPct: businessPct,
    category: category,
  );
}

String isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class NotEncrypted implements Exception {
  @override
  String toString() => 'SQLCipher not available: refusing to open an unencrypted database';
}

@DriftDatabase(tables: [Settings, LedgerEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Opens [file] encrypted with [key]. Fails closed if SQLCipher isn't linked.
  /// A wrong key surfaces as an error on the first query.
  factory AppDatabase.open(File file, Uint8List key) {
    final hex = key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return AppDatabase(
      NativeDatabase.createInBackground(
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
      ),
    );
  }

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement('CREATE INDEX entries_date ON ledger_entries(date)');
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(ledgerEntries);
        await customStatement('CREATE INDEX entries_date ON ledger_entries(date)');
      }
    },
  );

  // ---------- ledger ----------

  /// All entries for a tax year, newest first.
  Stream<List<LedgerEntry>> watchYear(int year) =>
      (select(ledgerEntries)
            ..where((e) => e.date.like('$year-%'))
            ..orderBy([(e) => OrderingTerm.desc(e.date), (e) => OrderingTerm.desc(e.id)]))
          .watch();

  Future<int> addEntry(LedgerEntriesCompanion e) => into(ledgerEntries).insert(e);

  Future<void> saveEntry(LedgerEntry e) => update(ledgerEntries).replace(e);

  Future<void> deleteEntry(int id) => (delete(ledgerEntries)..where((e) => e.id.equals(id))).go();

  /// Undo for a delete: puts the row back with its original id.
  Future<void> restoreEntry(LedgerEntry e) => into(ledgerEntries).insert(e, mode: InsertMode.insertOrReplace);

  /// Smart default (SPEC §5): the category last used for this payee, else for this kind.
  Future<String?> suggestCategory({required bool isIncome, String party = ''}) async {
    Future<String?> last(Expression<bool> Function($LedgerEntriesTable) where) async =>
        (await (select(ledgerEntries)
                  ..where(where)
                  ..orderBy([(e) => OrderingTerm.desc(e.id)])
                  ..limit(1))
                .getSingleOrNull())
            ?.category;
    final p = party.trim();
    return (p.isEmpty
            ? null
            : await last((e) => e.isIncome.equals(isIncome) & e.party.lower().equals(p.toLowerCase()))) ??
        await last((e) => e.isIncome.equals(isIncome));
  }

  /// Distinct recent payees/platforms for autocomplete.
  Future<List<String>> recentValues(GeneratedColumn<String> column, {int limit = 20}) async {
    final q = selectOnly(ledgerEntries, distinct: true)
      ..addColumns([column])
      ..where(column.equals('').not())
      ..orderBy([OrderingTerm.desc(ledgerEntries.id)])
      ..limit(limit);
    return [for (final r in await q.get()) r.read(column)!];
  }

  Future<String?> getSetting(String k) async =>
      (await (select(settings)..where((s) => s.key.equals(k))).getSingleOrNull())?.value;

  Future<void> setSetting(String k, String v) =>
      into(settings).insertOnConflictUpdate(SettingsCompanion.insert(key: k, value: v));
}
