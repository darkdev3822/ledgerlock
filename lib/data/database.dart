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

  /// Income only: false = invoiced, not paid yet (excluded from totals: cash basis). SPEC §2.13.
  BoolColumn get paid => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Estimated tax payments made to the IRS (payment log, SPEC §2.6). taxYear = the year the payment is for.
@DataClassName('TaxPayment')
class TaxPayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get taxYear => integer()();
  TextColumn get quarter => text().withDefault(const Constant(''))(); // 'Q1'..'Q4' or ''
  TextColumn get date => text().withLength(min: 10, max: 10)();
  IntColumn get amountCents => integer()();
  TextColumn get method => text().withDefault(const Constant(''))(); // Direct Pay, EFTPS, check…
  TextColumn get notes => text().withDefault(const Constant(''))();
}

/// Business trips for the standard mileage rate (Schedule C line 9). Miles in tenths.
@DataClassName('Trip')
class Trips extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get date => text().withLength(min: 10, max: 10)();
  IntColumn get milesTenths => integer()();
  TextColumn get purpose => text().withDefault(const Constant(''))();
  TextColumn get route => text().withDefault(const Constant(''))();
}

/// 1099 forms received, to reconcile with recorded income (1099 tracker).
@DataClassName('Form1099')
class Forms1099 extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get year => integer()();
  TextColumn get kind => text()(); // '1099-K', '1099-NEC', '1099-MISC'
  TextColumn get payer => text()(); // matched against entry platform/party (case-insensitive)
  IntColumn get amountCents => integer()();
  IntColumn get attachmentId => integer().nullable().references(Attachments, #id, onDelete: KeyAction.setNull)();
}

/// Smart rules (SPEC §3): "payee contains X -> category Y". Manual ones from Settings, learned ones from the
/// user's corrections. Applied when typing a payee and to imports.
@DataClassName('CategoryRule')
class CategoryRules extends Table {
  IntColumn get id => integer().autoIncrement()();
  BoolColumn get isIncome => boolean()();
  TextColumn get contains => text()(); // lower-case, trimmed
  TextColumn get category => text()();
  IntColumn get businessPct => integer().nullable()(); // expenses only; null = leave as is
  BoolColumn get learned => boolean().withDefault(const Constant(false))();
}

/// Receipts and vault documents. Bytes live encrypted in EncryptedFileStore; only ids and metadata here.
@DataClassName('Attachment')
class Attachments extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 'receipt', 'tax_form' (W-2/1099), 'prior_return', 'letter', 'other'.
  TextColumn get folder => text()();
  IntColumn get year => integer()();

  /// Linked ledger entry (receipts); null = unmatched.
  IntColumn get entryId => integer().nullable().references(LedgerEntries, #id, onDelete: KeyAction.setNull)();
  TextColumn get fileId => text()();
  TextColumn get thumbId => text().nullable()();
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get mime => text()();
  IntColumn get sizeBytes => integer()();
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
    paid: paid,
  );
}

String isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class NotEncrypted implements Exception {
  @override
  String toString() => 'SQLCipher not available: refusing to open an unencrypted database';
}

@DriftDatabase(tables: [Settings, LedgerEntries, Attachments, TaxPayments, Trips, Forms1099, CategoryRules])
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
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement('CREATE INDEX entries_date ON ledger_entries(date)');
      await customStatement('CREATE INDEX attachments_year ON attachments(year, folder)');
      await _createSearchIndex();
      await customStatement('CREATE INDEX attachments_entry ON attachments(entry_id)');
      await _v6Indexes();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(ledgerEntries);
        await customStatement('CREATE INDEX entries_date ON ledger_entries(date)');
      }
      if (from < 3) {
        await m.createTable(attachments);
        await customStatement('CREATE INDEX attachments_year ON attachments(year, folder)');
      }
      if (from < 4) await _createSearchIndex();
      if (from < 5) await customStatement('CREATE INDEX attachments_entry ON attachments(entry_id)');
      if (from < 6) {
        // Tables created above (from < 2) already have the column.
        if (from >= 2) await m.addColumn(ledgerEntries, ledgerEntries.paid);
        await m.createTable(taxPayments);
        await m.createTable(trips);
        await m.createTable(forms1099);
        await _v6Indexes();
      }
      if (from < 7) await m.createTable(categoryRules);
    },
  );

  /// FTS5 full-text index inside the encrypted DB (SPEC §4). rowid = entry id, or -attachment id.
  /// Kept in sync by triggers, so every write path is covered.
  Future<void> _createSearchIndex() async {
    const entryBody = "new.party || ' ' || new.platform || ' ' || new.notes || ' ' || replace(new.category, '_', ' ')";
    const attBody = "new.name || ' ' || replace(new.folder, '_', ' ')";
    for (final sql in [
      "CREATE VIRTUAL TABLE search_fts USING fts5(body, tokenize = 'unicode61 remove_diacritics 2')",
      'CREATE TRIGGER le_ai AFTER INSERT ON ledger_entries BEGIN '
          'INSERT INTO search_fts(rowid, body) VALUES (new.id, $entryBody); END',
      'CREATE TRIGGER le_ad AFTER DELETE ON ledger_entries BEGIN DELETE FROM search_fts WHERE rowid = old.id; END',
      'CREATE TRIGGER le_au AFTER UPDATE ON ledger_entries BEGIN DELETE FROM search_fts WHERE rowid = old.id; '
          'INSERT INTO search_fts(rowid, body) VALUES (new.id, $entryBody); END',
      'CREATE TRIGGER at_ai AFTER INSERT ON attachments BEGIN '
          'INSERT INTO search_fts(rowid, body) VALUES (-new.id, $attBody); END',
      'CREATE TRIGGER at_ad AFTER DELETE ON attachments BEGIN DELETE FROM search_fts WHERE rowid = -old.id; END',
      'CREATE TRIGGER at_au AFTER UPDATE ON attachments BEGIN DELETE FROM search_fts WHERE rowid = -old.id; '
          'INSERT INTO search_fts(rowid, body) VALUES (-new.id, $attBody); END',
      // Backfill rows that existed before the index.
      "INSERT INTO search_fts(rowid, body) SELECT id, party || ' ' || platform || ' ' || notes || ' ' || "
          "replace(category, '_', ' ') FROM ledger_entries",
      "INSERT INTO search_fts(rowid, body) SELECT -id, name || ' ' || replace(folder, '_', ' ') FROM attachments",
    ]) {
      await customStatement(sql);
    }
  }

  // ---------- attachments ----------

  Stream<List<Attachment>> watchAttachments(int year, {String? folder}) {
    final q = select(attachments)..where((a) => a.year.equals(year));
    if (folder != null) q.where((a) => a.folder.equals(folder));
    q.orderBy([(a) => OrderingTerm.desc(a.createdAt), (a) => OrderingTerm.desc(a.id)]);
    return q.watch();
  }

  Stream<List<Attachment>> watchEntryAttachments(int entryId) =>
      (select(attachments)..where((a) => a.entryId.equals(entryId))).watch();

  Future<int> addAttachment(AttachmentsCompanion a) => into(attachments).insert(a);

  Future<void> linkAttachment(int id, int? entryId) =>
      (update(attachments)..where((a) => a.id.equals(id))).write(AttachmentsCompanion(entryId: Value(entryId)));

  Future<Attachment?> attachment(int id) => (select(attachments)..where((a) => a.id.equals(id))).getSingleOrNull();

  Future<void> deleteAttachmentRow(int id) => (delete(attachments)..where((a) => a.id.equals(id))).go();

  /// Receipts stored for a year (the free tier allows 50; enforced in M7).
  Future<int> receiptCount(int year) async {
    final c = attachments.id.count();
    final q = selectOnly(attachments)
      ..addColumns([c])
      ..where(attachments.year.equals(year) & attachments.folder.equals('receipt'));
    return (await q.getSingle()).read(c) ?? 0;
  }

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
    final rule = matchRule(await allRules(), isIncome: isIncome, party: p);
    if (rule != null) return rule.category;
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

  Future<void> _v6Indexes() async {
    await customStatement('CREATE INDEX payments_year ON tax_payments(tax_year)');
    await customStatement('CREATE INDEX trips_date ON trips(date)');
    await customStatement('CREATE INDEX forms1099_year ON forms1099(year)');
  }

  // ---------- M6: payments, trips, 1099s ----------
  Stream<List<TaxPayment>> watchPayments(int taxYear) =>
      (select(taxPayments)
            ..where((p) => p.taxYear.equals(taxYear))
            ..orderBy([(p) => OrderingTerm.asc(p.date), (p) => OrderingTerm.asc(p.id)]))
          .watch();
  Future<int> addPayment(TaxPaymentsCompanion p) => into(taxPayments).insert(p);
  Future<void> deletePayment(int id) => (delete(taxPayments)..where((p) => p.id.equals(id))).go();

  Stream<List<Trip>> watchTrips(int year) =>
      (select(trips)
            ..where((t) => t.date.like('$year-%'))
            ..orderBy([(t) => OrderingTerm.desc(t.date), (t) => OrderingTerm.desc(t.id)]))
          .watch();
  Future<int> addTrip(TripsCompanion t) => into(trips).insert(t);
  Future<void> deleteTrip(int id) => (delete(trips)..where((t) => t.id.equals(id))).go();

  Stream<List<Form1099>> watchForms1099(int year) =>
      (select(forms1099)
            ..where((f) => f.year.equals(year))
            ..orderBy([(f) => OrderingTerm.asc(f.payer)]))
          .watch();
  Future<int> addForm1099(Forms1099Companion f) => into(forms1099).insert(f);
  Future<void> deleteForm1099(int id) => (delete(forms1099)..where((f) => f.id.equals(id))).go();

  // ---------- M7: smart rules ----------
  Future<List<CategoryRule>> allRules() => select(categoryRules).get();
  Stream<List<CategoryRule>> watchRules() => (select(
    categoryRules,
  )..orderBy([(r) => OrderingTerm.asc(r.learned), (r) => OrderingTerm.asc(r.contains)])).watch();
  Future<int> addRule(CategoryRulesCompanion r) => into(categoryRules).insert(r);
  Future<void> deleteRule(int id) => (delete(categoryRules)..where((r) => r.id.equals(id))).go();

  /// Called after the user saves an entry. If rules would have suggested a different category for this payee,
  /// the user corrected it: remember the correction for this exact payee (an exact-payee rule beats a broader
  /// "contains" rule because it is longer or equal). Nothing is learned while rules and choice agree.
  Future<void> learnFromSave({required bool isIncome, required String party, required String category}) async {
    final p = party.trim().toLowerCase();
    if (p.isEmpty) return;
    final rules = await allRules();
    final hit = matchRule(rules, isIncome: isIncome, party: p);
    if (hit?.category == category) return;
    final exact = rules.where((r) => r.isIncome == isIncome && r.contains == p).firstOrNull;
    if (exact != null) {
      await (update(
        categoryRules,
      )..where((r) => r.id.equals(exact.id))).write(CategoryRulesCompanion(category: Value(category)));
    } else if (hit != null) {
      // Only a correction of an existing rule teaches; first-time payees use the "last used" fallback.
      await addRule(
        CategoryRulesCompanion.insert(isIncome: isIncome, contains: p, category: category, learned: const Value(true)),
      );
    }
  }
}

/// Best rule for a payee: the longest matching "contains" text wins; on a tie, manual beats learned, then newest.
CategoryRule? matchRule(Iterable<CategoryRule> rules, {required bool isIncome, required String party}) {
  final p = party.trim().toLowerCase();
  if (p.isEmpty) return null;
  CategoryRule? best;
  for (final r in rules) {
    if (r.isIncome != isIncome || r.contains.isEmpty || !p.contains(r.contains)) continue;
    if (best == null) {
      best = r;
      continue;
    }
    final byLen = r.contains.length.compareTo(best.contains.length);
    if (byLen > 0 || (byLen == 0 && (best.learned && !r.learned || (best.learned == r.learned && r.id > best.id)))) {
      best = r;
    }
  }
  return best;
}
