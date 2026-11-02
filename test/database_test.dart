import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerlock/data/database.dart';
import 'package:ledgerlock/security/crypto.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

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
