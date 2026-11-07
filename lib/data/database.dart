// SQLCipher database via drift. Opened with a raw 256-bit key (no SQLCipher
// passphrase KDF needed: the key already comes from Argon2id + HKDF).
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'ledger.dart';
import 'recurring.dart';

part 'database.g.dart';

/// Separate businesses (SPEC §3), each with its own Schedule C. Row 1 always exists and can't be deleted.
@DataClassName('Business')
class Businesses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
}

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

  /// Made by a repeating record (Recurrings.id); null for everything typed or imported. Not a foreign key: stopping
  /// a repeat keeps the records it already made and just clears this.
  IntColumn get recurringId => integer().nullable()();

  /// Tags as ' a b ' (normalizeTags): lower-case words, space-separated, padded so `LIKE '% a %'` matches exactly.
  TextColumn get tags => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// v11: which business (Businesses.id) this belongs to. 1 = the main business every existing row moves to.
  IntColumn get businessId => integer().withDefault(const Constant(1))();
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

  /// v11: which business (Businesses.id) this belongs to. 1 = the main business every existing row moves to.
  IntColumn get businessId => integer().withDefault(const Constant(1))();
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

  /// v11: which business (Businesses.id) this belongs to. 1 = the main business every existing row moves to.
  IntColumn get businessId => integer().withDefault(const Constant(1))();
}

/// Repeating records (SPEC §3: subscriptions, rent share). A template plus a schedule; copies are added on unlock
/// for every due date up to today (lib/data/recurring.dart).
@DataClassName('Recurring')
class Recurrings extends Table {
  IntColumn get id => integer().autoIncrement()();
  BoolColumn get isIncome => boolean()();
  IntColumn get amountCents => integer()();
  IntColumn get feeCents => integer().withDefault(const Constant(0))();
  IntColumn get businessPct => integer().withDefault(const Constant(100))();
  TextColumn get category => text()();
  TextColumn get party => text().withDefault(const Constant(''))();
  TextColumn get platform => text().withDefault(const Constant(''))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  TextColumn get every => text()(); // 'week' | 'month' | 'year'
  IntColumn get anchorDay => integer()(); // day of month it started on (1-31)
  TextColumn get nextDate => text().withLength(min: 10, max: 10)();

  /// v10: copies keep the first record's tags, and repeating income can make unpaid invoices (paid = false).
  TextColumn get tags => text().withDefault(const Constant(''))();
  BoolColumn get paid => boolean().withDefault(const Constant(true))();

  /// v11: which business (Businesses.id) this belongs to. 1 = the main business every existing row moves to.
  IntColumn get businessId => integer().withDefault(const Constant(1))();
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

final _days = Expando<DateTime>('entryDay');

DateTime _parseDay(String d) {
  if (d.length == 10 && d.codeUnitAt(4) == 0x2D && d.codeUnitAt(7) == 0x2D) {
    final y = int.tryParse(d.substring(0, 4)), m = int.tryParse(d.substring(5, 7)), dd = int.tryParse(d.substring(8));
    if (y != null && m != null && dd != null) return DateTime(y, m, dd);
  }
  return DateTime.parse(d);
}

extension LedgerEntryMaths on LedgerEntry {
  /// Stored as 'YYYY-MM-DD'. Building a local DateTime is slow (time zone lookup) and this runs for every record on
  /// every summary, so each row object parses once (scale test: 10,000 records).
  DateTime get day => _days[this] ??= _parseDay(date);
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

/// At most [n] UTF-16 units of [s] without splitting a surrogate pair (an emoji cut in half is malformed text that
/// throws when drawn; UI review U9).
String safeTake(String s, int n) {
  if (s.length <= n) return s;
  var end = n;
  final last = s.codeUnitAt(end - 1);
  if (last >= 0xD800 && last <= 0xDBFF) end--; // don't keep a lone high surrogate
  return s.substring(0, end);
}

/// Whole calendar days from [a] to [b] (dates only). Counts on UTC dates, so a 23- or 25-hour day at a
/// daylight-saving change can't make it one short (M9.5 fuzz F8 / UI U5).
int daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

/// Tags typed by the user -> stored form ' a b '. Words of letters, digits, '-' or '_' (a leading '#' is dropped),
/// lower-case, at most 8 tags of 24 characters, duplicates removed. Empty input -> ''.
String normalizeTags(String input) {
  final out = <String>[];
  for (final raw in input.toLowerCase().split(RegExp(r'[\s,;]+'))) {
    final t = safeTake(raw.replaceAll(RegExp(r'[^\p{L}\p{N}_-]', unicode: true), ''), 24);
    if (t.isNotEmpty && !out.contains(t)) out.add(t);
    if (out.length == 8) break;
  }
  return out.isEmpty ? '' : ' ${out.join(' ')} ';
}

List<String> tagList(String stored) => stored.split(' ').where((t) => t.isNotEmpty).toList();

String isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class NotEncrypted implements Exception {
  @override
  String toString() => 'SQLCipher not available: refusing to open an unencrypted database';
}

/// Database layout version of this app. Backups record it so an older app refuses a newer backup up front.
const vaultSchemaVersion = 11;

/// The vault was written by a newer version of the app than this one (schema [found] > [supported]).
class DatabaseTooNew implements Exception {
  final int found, supported;
  const DatabaseTooNew(this.found, this.supported);
  @override
  String toString() => 'DatabaseTooNew($found > $supported)';
}

/// True for [DatabaseTooNew], also when it comes back from the database isolate wrapped (DriftRemoteException).
bool isDatabaseTooNew(Object e) => e is DatabaseTooNew || e.toString().contains('DatabaseTooNew(');

@DriftDatabase(
  tables: [Settings, LedgerEntries, Attachments, TaxPayments, Trips, Forms1099, CategoryRules, Recurrings, Businesses],
)
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
  int get schemaVersion => vaultSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement('CREATE INDEX entries_date ON ledger_entries(date)');
      await customStatement('CREATE INDEX attachments_year ON attachments(year, folder)');
      await _createSearchIndex(withTags: true);
      await customStatement('CREATE INDEX attachments_entry ON attachments(entry_id)');
      await _v6Indexes();
      await _seedMainBusiness();
    },
    onUpgrade: (m, from, to) async {
      // A vault from a newer app version (e.g. its backup restored into this older app): never "downgrade" it. Doing
      // so would stamp the old version on a newer layout, and the next update would then fail to open it.
      if (from > to) throw DatabaseTooNew(from, to);
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
      if (from < 8) {
        if (from >= 2) await m.addColumn(ledgerEntries, ledgerEntries.recurringId);
        await m.createTable(recurrings);
      }
      if (from < 9) {
        if (from >= 2) await m.addColumn(ledgerEntries, ledgerEntries.tags);
        await _indexTags();
      }
      if (from < 10 && from >= 8) {
        // Tables created above (from < 8) already have the columns.
        await m.addColumn(recurrings, recurrings.tags);
        await m.addColumn(recurrings, recurrings.paid);
      }
      if (from < 11) {
        // ADD COLUMN with a default: no row is copied or rewritten, everything lands in business 1.
        // Idempotent: a beta 2 app that opened a v11 vault (restored backup) stamped it v10 but kept these columns.
        if (from >= 2) await _addColumnOnce(m, ledgerEntries, ledgerEntries.businessId);
        if (from >= 6) {
          await _addColumnOnce(m, trips, trips.businessId);
          await _addColumnOnce(m, forms1099, forms1099.businessId);
        }
        if (from >= 8) await _addColumnOnce(m, recurrings, recurrings.businessId);
        final has = await customSelect("SELECT 1 FROM sqlite_master WHERE type='table' AND name='businesses'").get();
        if (has.isEmpty) await m.createTable(businesses);
        await _seedMainBusiness();
      }
    },
  );

  /// FTS5 full-text index inside the encrypted DB (SPEC §4). rowid = entry id, or -attachment id.
  /// Kept in sync by triggers, so every write path is covered.
  /// Search text for an entry row ([p] = 'new.' in triggers, '' in a SELECT). Tags are searchable from v9.
  static String _entryBody(String p, {bool withTags = true}) =>
      "${p}party || ' ' || ${p}platform || ' ' || ${p}notes || ' ' || replace(${p}category, '_', ' ')"
      "${withTags ? " || ' ' || ${p}tags" : ''}";

  /// v9: entry triggers and index rows include tags.
  Future<void> _indexTags() async {
    final body = _entryBody('new.');
    for (final sql in [
      'DROP TRIGGER IF EXISTS le_ai',
      'DROP TRIGGER IF EXISTS le_au',
      'CREATE TRIGGER le_ai AFTER INSERT ON ledger_entries BEGIN '
          'INSERT INTO search_fts(rowid, body) VALUES (new.id, $body); END',
      'CREATE TRIGGER le_au AFTER UPDATE ON ledger_entries BEGIN DELETE FROM search_fts WHERE rowid = old.id; '
          'INSERT INTO search_fts(rowid, body) VALUES (new.id, $body); END',
      'DELETE FROM search_fts WHERE rowid > 0',
      'INSERT INTO search_fts(rowid, body) SELECT id, ${_entryBody('')} FROM ledger_entries',
    ]) {
      await customStatement(sql);
    }
  }

  Future<void> _createSearchIndex({bool withTags = false}) async {
    final entryBody = _entryBody('new.', withTags: withTags);
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
      'INSERT INTO search_fts(rowid, body) SELECT id, ${_entryBody('', withTags: withTags)} FROM ledger_entries',
      "INSERT INTO search_fts(rowid, body) SELECT -id, name || ' ' || replace(folder, '_', ' ') FROM attachments",
    ]) {
      await customStatement(sql);
    }
  }

  // ---------- attachments ----------

  /// Ids of records with at least one receipt or document attached (any year's folder).
  Stream<Set<int>> watchLinkedEntryIds() => customSelect(
    'SELECT DISTINCT entry_id FROM attachments WHERE entry_id IS NOT NULL',
    readsFrom: {attachments},
  ).watch().map((rows) => {for (final r in rows) r.read<int>('entry_id')});

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

  // ---------- businesses (v11) ----------
  static const mainBusinessId = 1;
  Future<void> _seedMainBusiness() => into(businesses).insert(
    const BusinessesCompanion(id: Value(1), name: Value('Main business')),
    mode: InsertMode.insertOrIgnore,
  );

  Future<void> _addColumnOnce(Migrator m, TableInfo table, GeneratedColumn column) async {
    final cols = await customSelect('PRAGMA table_info(${table.actualTableName})').get();
    if (cols.any((r) => r.read<String>('name') == column.name)) return;
    await m.addColumn(table, column);
  }

  Stream<List<Business>> watchBusinesses() => (select(businesses)..orderBy([(b) => OrderingTerm.asc(b.id)])).watch();
  Future<List<Business>> allBusinesses() => (select(businesses)..orderBy([(b) => OrderingTerm.asc(b.id)])).get();
  Future<int> addBusiness(String name) => into(businesses).insert(BusinessesCompanion.insert(name: name));
  Future<void> renameBusiness(int id, String name) =>
      (update(businesses)..where((b) => b.id.equals(id))).write(BusinessesCompanion(name: Value(name)));

  /// Removes business [id] after moving every record, trip, 1099 and repeat it owns to [moveTo]. Nothing is ever
  /// deleted with it, and the main business can't be removed. One transaction.
  Future<void> deleteBusiness(int id, {int moveTo = mainBusinessId}) => transaction(() async {
    if (id == mainBusinessId || id == moveTo) throw ArgumentError('cannot delete business $id');
    if (await (select(businesses)..where((b) => b.id.equals(moveTo))).getSingleOrNull() == null) {
      throw ArgumentError('no business $moveTo');
    }
    await (update(
      ledgerEntries,
    )..where((e) => e.businessId.equals(id))).write(LedgerEntriesCompanion(businessId: Value(moveTo)));
    await (update(trips)..where((e) => e.businessId.equals(id))).write(TripsCompanion(businessId: Value(moveTo)));
    await (update(
      forms1099,
    )..where((e) => e.businessId.equals(id))).write(Forms1099Companion(businessId: Value(moveTo)));
    await (update(
      recurrings,
    )..where((e) => e.businessId.equals(id))).write(RecurringsCompanion(businessId: Value(moveTo)));
    await (delete(businesses)..where((b) => b.id.equals(id))).go();
  });

  // ---------- ledger ----------

  /// All entries for a tax year, newest first.
  Stream<List<LedgerEntry>> watchYear(int year) =>
      (select(ledgerEntries)
            ..where((e) => e.date.like('$year-%'))
            ..orderBy([(e) => OrderingTerm.desc(e.date), (e) => OrderingTerm.desc(e.id)]))
          .watch();

  Future<int> addEntry(LedgerEntriesCompanion e) => into(ledgerEntries).insert(e);

  Future<void> saveEntry(LedgerEntry e) => update(ledgerEntries).replace(e);

  /// Deletes the entry. Returns the ids of attachments that were linked to it (the FK unlinks them), so Undo can
  /// relink them.
  Future<List<int>> deleteEntry(int id) => transaction(() async {
    final linked = await (select(attachments)..where((a) => a.entryId.equals(id))).map((a) => a.id).get();
    await (delete(ledgerEntries)..where((e) => e.id.equals(id))).go();
    return linked;
  });

  /// Undo for a delete: puts the row back with its original id and relinks its receipts (UI review U3: they used
  /// to stay "unmatched" in the Vault).
  Future<void> restoreEntry(LedgerEntry e, {List<int> attachmentIds = const []}) => transaction(() async {
    await into(ledgerEntries).insert(e, mode: InsertMode.insertOrReplace);
    for (final a in attachmentIds) {
      await linkAttachment(a, e.id);
    }
  });

  // ---------- bulk edits (Records selection) ----------
  /// Deletes several records in one transaction. Returns what undo needs: each row and its linked receipts.
  Future<List<(LedgerEntry, List<int>)>> deleteEntries(Iterable<int> ids) => transaction(() async {
    final out = <(LedgerEntry, List<int>)>[];
    for (final id in ids) {
      final e = await (select(ledgerEntries)..where((x) => x.id.equals(id))).getSingleOrNull();
      if (e == null) continue;
      out.add((e, await deleteEntry(id)));
    }
    return out;
  });

  Future<void> restoreEntries(List<(LedgerEntry, List<int>)> rows) => transaction(() async {
    for (final (e, a) in rows) {
      await restoreEntry(e, attachmentIds: a);
    }
  });

  /// Applies [change] to each record in one transaction. Returns the rows as they were, for undo
  /// ([replaceEntries]). Rows that no longer exist are skipped.
  Future<List<LedgerEntry>> editEntries(Iterable<int> ids, LedgerEntry Function(LedgerEntry) change) =>
      transaction(() async {
        final before = await (select(ledgerEntries)..where((x) => x.id.isIn(ids))).get();
        for (final e in before) {
          final n = change(e);
          if (n.id != e.id) throw ArgumentError('edit changed the id');
          await update(ledgerEntries).replace(n);
        }
        return before;
      });

  /// Puts rows back exactly as given (undo of [editEntries]).
  Future<void> replaceEntries(List<LedgerEntry> rows) => transaction(() async {
    for (final e in rows) {
      await update(ledgerEntries).replace(e);
    }
  });

  /// Smart default (SPEC §5): the category last used for this payee, else for this kind.
  /// [anyPayee]: fall back to the last category used for this kind when the payee is new (manual entry). Imports
  /// pass false so unknown payees land in "Other" instead of a misleading guess.
  Future<String?> suggestCategory({required bool isIncome, String party = '', bool anyPayee = true}) async {
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
        (anyPayee ? await last((e) => e.isIncome.equals(isIncome)) : null);
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

  /// Quick fill: records typed again and again (same payee, category and amount at least twice since [since]),
  /// most frequent first, newest copy of each. Repeating-record copies are left out (they add themselves).
  /// [business] 0 = every business.
  Future<List<LedgerEntry>> frequentEntries({
    required bool isIncome,
    required String since,
    int business = 0,
    int limit = 4,
  }) async {
    final rows = await customSelect(
      'SELECT e.* FROM ledger_entries e JOIN ('
      '  SELECT COUNT(*) AS n, MAX(id) AS mid FROM ledger_entries'
      '  WHERE is_income = ? AND recurring_id IS NULL AND date >= ? AND amount_cents > 0'
      '${business == 0 ? '' : ' AND business_id = ?'}'
      '  GROUP BY lower(trim(party)), category, amount_cents HAVING n >= 2'
      ') g ON e.id = g.mid ORDER BY g.n DESC, e.date DESC, e.id DESC LIMIT ?',
      variables: [
        Variable.withBool(isIncome),
        Variable.withString(since),
        if (business != 0) Variable.withInt(business),
        Variable.withInt(limit),
      ],
      readsFrom: {ledgerEntries},
    ).get();
    return [for (final r in rows) ledgerEntries.map(r.data)];
  }

  /// Trips driven again and again (same purpose, route and miles at least twice since [since]); newest copy of each.
  Future<List<Trip>> frequentTrips({required String since, int business = 0, int limit = 3}) async {
    final rows = await customSelect(
      'SELECT t.* FROM trips t JOIN ('
      '  SELECT COUNT(*) AS n, MAX(id) AS mid FROM trips WHERE date >= ? AND miles_tenths > 0'
      '${business == 0 ? '' : ' AND business_id = ?'}'
      '  GROUP BY lower(trim(purpose)), lower(trim(route)), miles_tenths HAVING n >= 2'
      ') g ON t.id = g.mid ORDER BY g.n DESC, t.date DESC, t.id DESC LIMIT ?',
      variables: [Variable.withString(since), if (business != 0) Variable.withInt(business), Variable.withInt(limit)],
      readsFrom: {trips},
    ).get();
    return [for (final r in rows) trips.map(r.data)];
  }

  // ---------- M7: import ----------
  /// Entries between two ISO dates (inclusive), for duplicate checks.
  Future<List<LedgerEntry>> entriesBetween(String from, String to) =>
      (select(ledgerEntries)..where((e) => e.date.isBetweenValues(from, to))).get();

  /// All-or-nothing insert of imported rows.
  Future<void> addEntries(List<LedgerEntriesCompanion> rows) => transaction(() async {
    for (final r in rows) {
      await into(ledgerEntries).insert(r);
    }
  });

  /// Moves everything filed under category [from] to [to] (deleting a custom category).
  Future<void> reassignCategory(String from, String to) => transaction(() async {
    await (update(
      ledgerEntries,
    )..where((e) => e.category.equals(from))).write(LedgerEntriesCompanion(category: Value(to)));
    await (update(recurrings)..where((e) => e.category.equals(from))).write(RecurringsCompanion(category: Value(to)));
    await (update(
      categoryRules,
    )..where((e) => e.category.equals(from))).write(CategoryRulesCompanion(category: Value(to)));
  });

  // ---------- recurring records ----------
  Stream<List<Recurring>> watchRecurring() =>
      (select(recurrings)..orderBy([(r) => OrderingTerm.asc(r.nextDate)])).watch();
  Future<Recurring?> recurring(int id) => (select(recurrings)..where((r) => r.id.equals(id))).getSingleOrNull();
  Future<int> addRecurring(RecurringsCompanion r) => into(recurrings).insert(r);

  /// Stops a repeat. Records it already made stay (they are real spending); they just lose the link.
  Future<void> stopRecurring(int id) => transaction(() async {
    await (update(
      ledgerEntries,
    )..where((e) => e.recurringId.equals(id))).write(const LedgerEntriesCompanion(recurringId: Value(null)));
    await (delete(recurrings)..where((r) => r.id.equals(id))).go();
  });

  /// Adds a record for every due date up to [today] and moves each rule's next date on. Returns how many were
  /// added. One transaction, so a crash can't add copies without moving the date (no duplicates on retry).
  Future<int> runRecurring(DateTime today) => transaction(() async {
    var added = 0;
    for (final r in await select(recurrings).get()) {
      final next = DateTime.tryParse(r.nextDate);
      if (next == null || !recurringEvery.contains(r.every)) continue;
      final due = dueDates(next, r.every, r.anchorDay, today);
      if (due.isEmpty) continue;
      for (final d in due) {
        await into(ledgerEntries).insert(
          LedgerEntriesCompanion.insert(
            isIncome: r.isIncome,
            date: isoDay(d),
            amountCents: r.amountCents,
            feeCents: Value(r.feeCents),
            businessPct: Value(r.businessPct),
            category: r.category,
            party: Value(r.party),
            platform: Value(r.platform),
            notes: Value(r.notes),
            tags: Value(r.tags),
            paid: Value(!r.isIncome || r.paid),
            recurringId: Value(r.id),
            businessId: Value(r.businessId),
          ),
        );
      }
      added += due.length;
      final after = stepDate(due.last, r.every, r.anchorDay);
      await (update(
        recurrings,
      )..where((x) => x.id.equals(r.id))).write(RecurringsCompanion(nextDate: Value(isoDay(after))));
    }
    return added;
  });

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
