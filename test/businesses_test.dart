// Multiple businesses (SPEC §3, schema v11): upgrade keeps everything in the main business, removing a business
// never deletes data, per-business Schedule C with combined self-employment tax, and search follows the business.
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerlock/app/app_controller.dart';
import 'package:ledgerlock/data/database.dart';
import 'package:ledgerlock/data/ledger.dart';
import 'package:ledgerlock/data/tax_rules.dart';
import 'package:ledgerlock/search/query_parser.dart';
import 'package:ledgerlock/search/search_service.dart';
import 'package:ledgerlock/security/crypto.dart';
import 'package:ledgerlock/ui/taxes/tools.dart' show businessFileSlug;
import 'package:sqlite3/sqlite3.dart' as raw;

AppDatabase _mem() => AppDatabase(NativeDatabase.memory(setup: (d) => d.execute('PRAGMA foreign_keys = ON')));

LedgerEntriesCompanion _e(String date, int cents, {bool income = true, int business = 1, String party = ''}) =>
    LedgerEntriesCompanion.insert(
      isIncome: income,
      date: date,
      amountCents: cents,
      category: income ? 'services' : 'supplies',
      party: Value(party),
      businessId: Value(business),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('v10 -> v11 upgrade: every record, trip, 1099 and repeat lands in the main business', () async {
    final dir = Directory.systemTemp.createTempSync('ll_biz');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/v10.db');
    final key = LedgerCrypto.randomBytes(32);
    final hex = key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    var db = AppDatabase.open(file, key);
    await db.addEntry(_e('2026-03-01', 5000, party: 'Etsy'));
    await db.addTrip(TripsCompanion.insert(date: '2026-03-02', milesTenths: 100));
    await db.addForm1099(Forms1099Companion.insert(year: 2026, kind: '1099-K', payer: 'Etsy', amountCents: 5000));
    await db.addRecurring(
      RecurringsCompanion.insert(
        isIncome: false,
        amountCents: 1000,
        category: 'software',
        every: 'month',
        anchorDay: 1,
        nextDate: '2026-04-01',
      ),
    );
    await db.close();
    final old = raw.sqlite3.open(file.path)
      ..execute("PRAGMA key = \"x'$hex'\"")
      ..execute('DROP TABLE businesses')
      ..execute('ALTER TABLE ledger_entries DROP COLUMN business_id')
      ..execute('ALTER TABLE trips DROP COLUMN business_id')
      ..execute('ALTER TABLE forms1099 DROP COLUMN business_id')
      ..execute('ALTER TABLE recurrings DROP COLUMN business_id')
      ..execute('PRAGMA user_version = 10');
    old.close();

    db = AppDatabase.open(file, key);
    expect((await db.allBusinesses()).map((b) => (b.id, b.name)), [(1, 'Main business')]);
    expect((await db.watchYear(2026).first).single.businessId, 1);
    expect((await db.watchYear(2026).first).single.party, 'Etsy');
    expect((await db.watchTrips(2026).first).single.businessId, 1);
    expect((await db.watchForms1099(2026).first).single.businessId, 1);
    expect((await db.watchRecurring().first).single.businessId, 1);
    await db.close();
  });

  test('removing a business moves its rows to the main business; the main one cannot be removed', () async {
    final db = _mem();
    addTearDown(db.close);
    final b = await db.addBusiness('Tutoring');
    await db.addEntry(_e('2026-03-01', 100, business: b));
    await db.addTrip(TripsCompanion.insert(date: '2026-03-02', milesTenths: 10, businessId: Value(b)));
    await db.addForm1099(
      Forms1099Companion.insert(year: 2026, kind: '1099-NEC', payer: 'X', amountCents: 1, businessId: Value(b)),
    );
    await expectLater(db.deleteBusiness(AppDatabase.mainBusinessId), throwsArgumentError);
    await expectLater(db.deleteBusiness(b, moveTo: 99), throwsArgumentError);
    expect((await db.watchYear(2026).first).single.businessId, b, reason: 'failed delete changed nothing');
    await db.deleteBusiness(b);
    expect((await db.allBusinesses()).length, 1);
    expect((await db.watchYear(2026).first).single.businessId, 1);
    expect((await db.watchTrips(2026).first).single.businessId, 1);
    expect((await db.watchForms1099(2026).first).single.businessId, 1);
  });

  test('repeating records make copies in their own business', () async {
    final db = _mem();
    addTearDown(db.close);
    final b = await db.addBusiness('Etsy shop');
    await db.addRecurring(
      RecurringsCompanion.insert(
        isIncome: false,
        amountCents: 1000,
        category: 'software',
        every: 'month',
        anchorDay: 1,
        nextDate: '2026-02-01',
        businessId: Value(b),
      ),
    );
    expect(await db.runRecurring(DateTime(2026, 3, 15)), 2);
    expect((await db.watchYear(2026).first).map((e) => e.businessId).toSet(), {b});
  });

  test('search only finds the business on screen; 0 finds all', () async {
    final db = _mem();
    addTearDown(db.close);
    final b = await db.addBusiness('Tutoring');
    await db.addEntry(_e('2026-03-01', 100, party: 'Acme'));
    await db.addEntry(_e('2026-03-02', 200, party: 'Acme', business: b));
    Future<List<int>> find(int business) async => (await runSearch(
      db,
      parseQuery('acme', today: DateTime(2026, 11, 1)),
      business: business,
    )).entries.map((e) => e.amountCents).toList();
    expect(await find(0), [200, 100]);
    expect(await find(1), [100]);
    expect(await find(b), [200]);
  });

  test('per-business Schedule C, self-employment tax on all businesses together', () async {
    final rules = await TaxRules.load(2026);
    var id = 0;
    LedgerEntry row(int business, bool income, int cents) => LedgerEntry(
      id: ++id,
      isIncome: income,
      date: '2026-03-01',
      amountCents: cents,
      feeCents: 0,
      businessPct: 100,
      category: income ? 'services' : 'supplies',
      party: '',
      platform: '',
      notes: '',
      paid: true,
      tags: '',
      createdAt: DateTime(2026),
      businessId: business,
    );
    // A: $30,000 profit. B: $4,000 loss (offsets A on Schedule SE).
    final entries = [row(1, true, 3000000), row(2, true, 100000), row(2, false, 500000)];
    final combined = businessSummary(rules, entries, const [], homeOfficeCents: 50000);
    final a = businessSummary(rules, entries, const [], view: 1, homeOfficeCents: 50000);
    final b = businessSummary(rules, entries, const [], view: 2, homeOfficeCents: 50000);
    final onlyA = summarize(entries.where((e) => e.businessId == 1).map((e) => e.data), rules, homeOfficeCents: 50000);

    expect(a.netCents, 3000000 - 50000, reason: 'home office counts toward the main business');
    expect(b.netCents, -400000, reason: 'no home office on the second business');
    expect(combined.netCents, a.netCents + b.netCents);
    expect(a.seTaxCents, combined.seTaxCents, reason: 'one Schedule SE for every business');
    expect(b.seTaxCents, combined.seTaxCents);
    expect(b.setAsideCents, combined.setAsideCents);
    expect(combined.seTaxCents, lessThan(onlyA.seTaxCents), reason: 'the loss lowers self-employment tax');
    expect(b.lines.values.fold<int>(0, (x, y) => x + y), isNot(a.lines.values.fold<int>(0, (x, y) => x + y)));
  });

  test('export file names from business names are plain ASCII, never a path', () {
    expect(businessFileSlug('Etsy Shop!'), 'etsy-shop');
    expect(businessFileSlug('../../etc/passwd'), 'etc-passwd');
    expect(businessFileSlug('Café ☕'), 'caf');
    expect(businessFileSlug('☕☕'), 'business');
    expect(businessFileSlug('x' * 80).length, 30);
    expect(businessFileSlug('${'a' * 29} b'), 'a' * 29, reason: 'no trailing dash after the cut');
    for (final n in ['a/b', r'a\b', '..', 'a\u0000b', 'CON']) {
      expect(businessFileSlug(n), matches(RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$')), reason: n);
    }
  });
}
