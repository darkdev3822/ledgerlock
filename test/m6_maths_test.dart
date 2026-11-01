// M6 maths: mileage by trip date, home office (simplified), invoiced-not-paid income.
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerlock/data/ledger.dart';
import 'package:ledgerlock/data/tax_rules.dart';
import 'package:ledgerlock/ui/taxes/tools.dart';

KeyFigure _k(String id, num v, {List<(DateTime, num)> changes = const [], bool ok = true}) =>
    KeyFigure(id: id, name: id, unit: '', value: v, changes: changes, verified: ok ? 'x' : null);

TaxRules _rules({bool verified = true}) => TaxRules(
  year: 2026,
  quarterlyDue: const [],
  expenseCategories: const [
    Category(id: 'supplies', name: 'Supplies', line: '22', hint: '', isIncome: false),
  ],
  incomeCategories: const [Category(id: 'services', name: 'Services', line: '1', hint: '', isIncome: true)],
  keyFigures: [
    _k('mileage_rate', 72.5, changes: [(DateTime(2026, 7, 1), 76)], ok: verified),
    _k('home_office_rate', 5, ok: verified), // test values only, not tax data
    _k('home_office_max_sqft', 300, ok: verified),
  ],
);

void main() {
  test('mileage: each trip at the rate in force on its date', () {
    final c = mileageDeductionCents([('2026-06-30', 100), ('2026-07-01', 100)], _rules());
    expect(c, (10 * 72.5 + 10 * 76).round());
  });
  test('mileage: unverified rate gives nothing', () {
    expect(mileageDeductionCents([('2026-03-01', 1000)], _rules(verified: false)), 0);
  });
  test('home office: area capped; unverified = null', () {
    expect(homeOfficeCents(200, _rules()), 200 * 5 * 100);
    expect(homeOfficeCents(500, _rules()), 300 * 5 * 100);
    expect(homeOfficeCents(200, _rules(verified: false)), isNull);
  });
  test('summarize: line 9 mileage, line 30 capped at tentative profit', () {
    final entries = [
      EntryData(isIncome: true, date: DateTime(2026, 2, 1), amountCents: 100000, category: 'services'),
      EntryData(isIncome: false, date: DateTime(2026, 2, 2), amountCents: 20000, category: 'supplies'),
    ];
    final s = summarize(entries, _rules(), mileageCents: 30000, homeOfficeCents: 90000);
    expect(s.lines['9'], 30000);
    expect(s.lines['30'], 50000, reason: '100000 - 20000 - 30000 = 50000 left; office cannot create a loss');
    expect(s.netCents, 0);
    expect(s.expensesCents, 100000);
  });
  test('invoiced, not paid income is not counted (cash basis)', () {
    final s = summarize([
      EntryData(isIncome: true, date: DateTime(2026, 2, 1), amountCents: 50000, category: 'services'),
      EntryData(
        isIncome: true,
        date: DateTime(2026, 2, 3),
        amountCents: 70000,
        category: 'services',
        paid: false,
      ),
    ], _rules());
    expect(s.grossCents, 50000);
  });
  test('money and miles parsing', () {
    expect(parseCents('1,200.5'), 120050);
    expect(parseCents('\$45'), 4500);
    expect(parseCents('abc'), isNull);
    expect(parseCents('1.234'), isNull);
    expect(parseMilesTenths('12.4'), 124);
    expect(parseMilesTenths('12.45'), isNull);
  });
}
