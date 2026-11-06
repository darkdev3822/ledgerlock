import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerlock/data/database.dart';
import 'package:ledgerlock/data/recurring.dart';
import 'package:ledgerlock/search/query_parser.dart';
import 'package:ledgerlock/search/search_service.dart';
import 'package:ledgerlock/security/crypto.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

/// Turns a current file back into v8's ledger shape: no tags column, index triggers without tags.
const _toV8 = """
DROP TRIGGER le_ai;
DROP TRIGGER le_au;
ALTER TABLE ledger_entries DROP COLUMN tags;
CREATE TRIGGER le_ai AFTER INSERT ON ledger_entries BEGIN INSERT INTO search_fts(rowid, body) VALUES
  (new.id, new.party || ' ' || new.platform || ' ' || new.notes || ' ' || replace(new.category, '_', ' ')); END;
CREATE TRIGGER le_au AFTER UPDATE ON ledger_entries BEGIN DELETE FROM search_fts WHERE rowid = old.id;
  INSERT INTO search_fts(rowid, body) VALUES
  (new.id, new.party || ' ' || new.platform || ' ' || new.notes || ' ' || replace(new.category, '_', ' ')); END;
""";

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('ll_db'));
  tearDown(() => dir.deleteSync(recursive: true));

  LedgerEntriesCompanion e(
    String date, {
    bool income = false,
    String cat = 'software',
    String party = '',
    int c = 100,
  }) => LedgerEntriesCompanion.insert(isIncome: income, date: date, amountCents: c, category: cat, party: Value(party));

  test('v1 database (M1/M2: settings only) migrates to v2 and keeps settings', () async {
    final file = File('${dir.path}/old.db');
    final key = LedgerCrypto.randomBytes(32);
    final hex = key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final old = raw.sqlite3.open(file.path)
      ..execute("PRAGMA key = \"x'$hex'\"")
      ..execute('CREATE TABLE settings ("key" TEXT NOT NULL PRIMARY KEY, "value" TEXT NOT NULL)')
      ..execute("INSERT INTO settings VALUES ('themeMode', 'dark')")
      ..execute('PRAGMA user_version = 1');
    old.close();

    final db = AppDatabase.open(file, key);
    expect(await db.getSetting('themeMode'), 'dark');
    await db.addEntry(e('2026-03-01'));
    expect((await db.watchYear(2026).first).length, 1);
    await db.close();
  });

  test('v5 database migrates to v7: entries kept and paid, new tables usable', () async {
    final file = File('${dir.path}/v5.db');
    final key = LedgerCrypto.randomBytes(32);
    final hex = key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    var db = AppDatabase.open(file, key);
    await db.addEntry(e('2026-03-01', income: true, cat: 'services', c: 5000));
    await db.close();
    // Turn it back into a v5 file: no M6 tables, no paid column.
    final old = raw.sqlite3.open(file.path)
      ..execute("PRAGMA key = \"x'$hex'\"")
      ..execute('DROP TABLE tax_payments')
      ..execute('DROP TABLE trips')
      ..execute('DROP TABLE forms1099')
      ..execute('DROP TABLE category_rules')
      ..execute('DROP TABLE recurrings')
      ..execute('ALTER TABLE ledger_entries DROP COLUMN recurring_id')
      ..execute(_toV8)
      ..execute('ALTER TABLE ledger_entries DROP COLUMN paid')
      ..execute('PRAGMA user_version = 5');
    old.close();

    db = AppDatabase.open(file, key);
    final rows = await db.watchYear(2026).first;
    expect(rows.single.paid, isTrue, reason: 'existing income counts as received');
    await db.addPayment(TaxPaymentsCompanion.insert(taxYear: 2026, date: '2026-04-15', amountCents: 100));
    await db.addTrip(TripsCompanion.insert(date: '2026-04-02', milesTenths: 125));
    await db.addForm1099(Forms1099Companion.insert(year: 2026, kind: '1099-K', payer: 'Etsy', amountCents: 1));
    expect((await db.watchPayments(2026).first).single.amountCents, 100);
    expect((await db.watchTrips(2026).first).single.milesTenths, 125);
    expect((await db.watchForms1099(2026).first).single.payer, 'Etsy');
    await db.close();
  });

  group('recurring records', () {
    DateTime d(String s) => DateTime.parse(s);
    test('month steps keep the start day where the month allows (Jan 31 -> Feb 28 -> Mar 31)', () {
      expect(dueDates(d('2026-01-31'), 'month', 31, d('2026-05-01')).map(isoDay), [
        '2026-01-31',
        '2026-02-28',
        '2026-03-31',
        '2026-04-30',
      ]);
      expect(isoDay(stepDate(d('2026-12-15'), 'month', 15)), '2027-01-15');
      expect(isoDay(stepDate(d('2028-02-29'), 'year', 29)), '2029-02-28');
      expect(isoDay(stepDate(d('2029-02-28'), 'year', 29)), '2030-02-28');
      // Across the US DST change (Mar 8 2026): calendar days, not 168 hours.
      expect(isoDay(stepDate(d('2026-03-05'), 'week', 5)), '2026-03-12');
      expect(dueDates(d('2026-11-07'), 'month', 7, d('2026-11-06')), isEmpty, reason: 'nothing due before its date');
      expect(dueDates(d('2000-01-01'), 'week', 1, d('2026-11-06')).length, maxCatchUp);
    });

    test('runRecurring adds every due copy once, moves the date on, and stopping keeps the records', () async {
      final db = AppDatabase.open(File('${dir.path}/rec.db'), LedgerCrypto.randomBytes(32));
      final id = await db.addRecurring(
        RecurringsCompanion.insert(
          isIncome: false,
          amountCents: 1599,
          category: 'software',
          party: const Value('Adobe'),
          businessPct: const Value(80),
          every: 'month',
          anchorDay: 31,
          nextDate: '2026-08-31',
        ),
      );
      expect(await db.runRecurring(d('2026-11-06')), 3); // Aug 31, Sep 30, Oct 31
      expect(await db.runRecurring(d('2026-11-06')), 0, reason: 'running again (next unlock) adds nothing');
      final rows = await db.watchYear(2026).first;
      expect(rows.map((r) => r.date).toSet(), {'2026-08-31', '2026-09-30', '2026-10-31'});
      expect(rows.every((r) => r.recurringId == id && r.businessPct == 80 && r.party == 'Adobe'), isTrue);
      expect((await db.recurring(id))!.nextDate, '2026-11-30');
      await db.stopRecurring(id);
      expect(await db.recurring(id), isNull);
      final kept = await db.watchYear(2026).first;
      expect(kept.length, 3, reason: 'stopping never deletes spending already recorded');
      expect(kept.every((r) => r.recurringId == null), isTrue);
      expect(await db.runRecurring(d('2027-06-01')), 0);
      await db.close();
    });

    test('v7 database migrates to v8: entries kept, repeating records usable', () async {
      final file = File('${dir.path}/v7.db');
      final key = LedgerCrypto.randomBytes(32);
      final hex = key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      var db = AppDatabase.open(file, key);
      await db.addEntry(e('2026-03-01'));
      await db.close();
      final old = raw.sqlite3.open(file.path)
        ..execute("PRAGMA key = \"x'$hex'\"")
        ..execute('DROP TABLE recurrings')
        ..execute('ALTER TABLE ledger_entries DROP COLUMN recurring_id')
        ..execute(_toV8)
        ..execute('PRAGMA user_version = 7');
      old.close();
      db = AppDatabase.open(file, key);
      expect((await db.watchYear(2026).first).single.recurringId, isNull);
      await db.addRecurring(
        RecurringsCompanion.insert(
          isIncome: true,
          amountCents: 50000,
          category: 'services',
          every: 'week',
          anchorDay: 2,
          nextDate: '2026-03-02',
        ),
      );
      expect(await db.runRecurring(d('2026-03-16')), 3);
      await db.close();
    });
  });

  test('tags: normalised, searchable by word and by #tag, and indexed after a v8 -> v9 upgrade', () async {
    expect(normalizeTags('  #Client-A, etsy_shop;client-a  ÉTÉ !!'), ' client-a etsy_shop été ');
    expect(normalizeTags(''), '');
    expect(tagList(normalizeTags(List.generate(12, (i) => 't$i').join(' '))).length, 8);
    expect(normalizeTags('x' * 40).trim().length, 24);

    final file = File('${dir.path}/v8.db');
    final key = LedgerCrypto.randomBytes(32);
    final hex = key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    var db = AppDatabase.open(file, key);
    await db.addEntry(e('2026-03-01', party: 'Staples'));
    await db.close();
    // Back to v8: no tags column, and the old index triggers (without tags).
    final old = raw.sqlite3.open(file.path)
      ..execute("PRAGMA key = \"x'$hex'\"")
      ..execute(_toV8)
      ..execute('PRAGMA user_version = 8');
    old.close();
    db = AppDatabase.open(file, key);
    final row = (await db.watchYear(2026).first).single;
    await db.saveEntry(row.copyWith(tags: normalizeTags('client-a')));
    await db.addEntry(
      LedgerEntriesCompanion.insert(
        isIncome: false,
        date: '2026-03-02',
        amountCents: 5,
        category: 'office',
        tags: Value(normalizeTags('client-ab')),
      ),
    );
    Future<List<String>> find(String q) async =>
        (await runSearch(db, parseQuery(q, today: DateTime(2026, 11, 1)))).entries.map((x) => x.date).toList();
    expect(await find('#client-a'), ['2026-03-01'], reason: 'exact tag, not a prefix of client-ab');
    expect((await find('client')).length, 2, reason: 'tags are in the text index too');
    expect(await find('staples'), ['2026-03-01'], reason: 'old rows re-indexed');
    expect(await find('#nope'), isEmpty);
    await db.close();
  });

  test('watchYear filters by year and orders newest first; restore undoes delete', () async {
    final db = AppDatabase.open(File('${dir.path}/t.db'), LedgerCrypto.randomBytes(32));
    await db.addEntry(e('2026-01-05', c: 1));
    await db.addEntry(e('2026-07-01', c: 2));
    await db.addEntry(e('2025-12-31', c: 3));
    final y26 = await db.watchYear(2026).first;
    expect(y26.map((x) => x.amountCents), [2, 1]);
    expect((await db.watchYear(2025).first).single.amountCents, 3);

    final victim = y26.first;
    await db.deleteEntry(victim.id);
    expect((await db.watchYear(2026).first).length, 1);
    await db.restoreEntry(victim);
    expect((await db.watchYear(2026).first).first, victim);
    await db.close();
  });

  test('smart default: last category for this payee, else last for this kind', () async {
    final db = AppDatabase.open(File('${dir.path}/s.db'), LedgerCrypto.randomBytes(32));
    expect(await db.suggestCategory(isIncome: false), isNull);
    await db.addEntry(e('2026-01-01', cat: 'meals', party: 'Cafe Uno'));
    await db.addEntry(e('2026-01-02', cat: 'software', party: 'Adobe'));
    await db.addEntry(e('2026-01-03', income: true, cat: 'services', party: 'Acme'));
    expect(await db.suggestCategory(isIncome: false, party: 'cafe uno'), 'meals');
    expect(await db.suggestCategory(isIncome: false, party: 'Someone new'), 'software');
    expect(await db.suggestCategory(isIncome: true), 'services');
    expect(
      await db.suggestCategory(isIncome: false, party: 'Someone new', anyPayee: false),
      isNull,
      reason: 'imports: unknown payee is not given the last-used category (found in device check)',
    );
    expect(await db.recentValues(db.ledgerEntries.party), containsAll(['Cafe Uno', 'Adobe', 'Acme']));
    await db.close();
  });

  test('smart rules: longest match wins, manual beats learned on a tie, rules beat last-used', () async {
    final db = AppDatabase.open(File('${dir.path}/r.db'), LedgerCrypto.randomBytes(32));
    await db.addEntry(e('2026-01-01', cat: 'meals', party: 'Anthropic PBC'));
    await db.addRule(CategoryRulesCompanion.insert(isIncome: false, contains: 'anthropic', category: 'software'));
    expect(await db.suggestCategory(isIncome: false, party: 'ANTHROPIC PBC'), 'software');
    expect(await db.suggestCategory(isIncome: true, party: 'Anthropic PBC'), isNull, reason: 'kind must match');
    await db.addRule(CategoryRulesCompanion.insert(isIncome: false, contains: 'anthropic pbc', category: 'education'));
    expect(await db.suggestCategory(isIncome: false, party: 'Anthropic PBC'), 'education');
    final rules = await db.allRules();
    final learned = CategoryRule(id: 99, isIncome: false, contains: 'anthropic', category: 'x', learned: true);
    expect(matchRule([learned, ...rules], isIncome: false, party: 'my anthropic')!.category, 'software');
    expect(matchRule(rules, isIncome: false, party: '  '), isNull);
    await db.close();
  });

  test('smart rules learn from corrections only', () async {
    final db = AppDatabase.open(File('${dir.path}/l.db'), LedgerCrypto.randomBytes(32));
    await db.learnFromSave(isIncome: false, party: 'New Shop', category: 'supplies');
    expect(await db.allRules(), isEmpty, reason: 'first-time payee: nothing to correct');
    await db.addRule(CategoryRulesCompanion.insert(isIncome: false, contains: 'amazon', category: 'supplies'));
    await db.learnFromSave(isIncome: false, party: 'Amazon', category: 'supplies');
    expect((await db.allRules()).length, 1, reason: 'agreement teaches nothing');
    await db.learnFromSave(isIncome: false, party: 'Amazon Web Services', category: 'software');
    expect(await db.suggestCategory(isIncome: false, party: 'amazon web services'), 'software');
    expect(await db.suggestCategory(isIncome: false, party: 'Amazon Marketplace'), 'supplies');
    await db.learnFromSave(isIncome: false, party: 'amazon web services', category: 'office');
    final rules = await db.allRules();
    expect(rules.length, 2, reason: 'the exact-payee rule is updated, not duplicated');
    expect(rules.firstWhere((r) => r.learned).category, 'office');
    await db.close();
  });
}
