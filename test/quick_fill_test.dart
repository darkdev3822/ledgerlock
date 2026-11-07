// Quick fill (entry screen "Again?" chips): what counts as a frequent record.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerlock/data/database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> add(String date, String party, int cents, {bool income = false, int business = 1, int? rule}) =>
      db.addEntry(
        LedgerEntriesCompanion.insert(
          isIncome: income,
          date: date,
          amountCents: cents,
          category: income ? 'services' : 'meals',
          party: Value(party),
          businessId: Value(business),
          recurringId: Value(rule),
        ),
      );

  Future<List<(String, int)>> freq({bool income = false, int business = 0}) async => [
    for (final e in await db.frequentEntries(isIncome: income, since: '2025-11-01', business: business))
      (e.party, e.amountCents),
  ];

  test('twice or more, same payee (any case/spacing), category and amount; most frequent first', () async {
    await add('2026-01-01', 'Starbucks', 540);
    await add('2026-02-01', ' starbucks ', 540);
    await add('2026-03-01', 'Starbucks', 540);
    await add('2026-01-05', 'Uber', 1200);
    await add('2026-04-05', 'Uber', 1200);
    await add('2026-01-07', 'Once', 999);
    await add('2026-01-08', 'Uber', 1300); // different amount: its own group, only once
    expect(await freq(), [('Starbucks', 540), ('Uber', 1200)]);
  });

  test('leaves out repeat copies, old records, the other kind and other businesses', () async {
    await add('2026-01-01', 'Netflix', 1599, rule: 7);
    await add('2026-02-01', 'Netflix', 1599, rule: 7);
    await add('2024-01-01', 'Old', 100);
    await add('2024-02-01', 'Old', 100);
    await add('2026-01-01', 'Client', 50000, income: true);
    await add('2026-02-01', 'Client', 50000, income: true);
    await add('2026-01-01', 'Etsy fee', 25, business: 2);
    await add('2026-02-01', 'Etsy fee', 25, business: 2);
    expect(await freq(), [('Etsy fee', 25)]);
    expect(await freq(business: 1), isEmpty);
    expect(await freq(business: 2), [('Etsy fee', 25)]);
    expect(await freq(income: true), [('Client', 50000)]);
  });

  test('at most four', () async {
    for (var i = 0; i < 6; i++) {
      await add('2026-01-01', 'P$i', 100 + i);
      await add('2026-01-02', 'P$i', 100 + i);
    }
    expect((await freq()).length, 4);
  });
}
