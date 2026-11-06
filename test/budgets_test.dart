import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerlock/data/budgets.dart';
import 'package:ledgerlock/data/ledger.dart';

EntryData x(String d, int c, {String cat = 'meals', bool inc = false, bool paid = true, int pct = 100}) =>
    EntryData(isIncome: inc, date: DateTime.parse(d), amountCents: c, category: cat, paid: paid, businessPct: pct);

void main() {
  test('budget counts this month only, full amount, sorted by how much is used', () {
    final s = budgetStatus(
      {'meals': 20000, 'software': 10000, 'office': 0},
      [
        x('2026-11-02', 15000, pct: 50), // full amount counts
        x('2026-10-30', 99999), // last month
        x('2025-11-02', 99999), // last year
        x('2026-11-03', 12000, cat: 'software'),
        x('2026-11-03', 5000, cat: 'services', inc: true),
      ],
      DateTime(2026, 11, 15),
    );
    expect(s.map((b) => (b.category, b.spentCents)), [('software', 12000), ('meals', 15000)]);
    expect(s.first.over, isTrue);
    expect(s.last.monthElapsed, closeTo(0.5, 0.001));
    expect(s.last.ahead, isTrue, reason: '75% used at 50% of the month');
  });

  test('income goal: paid income only, projection from day 14 of the current year', () {
    final es = [x('2026-02-01', 1000000, cat: 'services', inc: true), x('2026-03-01', 500000, inc: true, paid: false)];
    final g = goalStatus(4000000, 2026, es, DateTime(2026, 4, 1)); // day 91 of 365
    expect(g.receivedCents, 1000000);
    expect(g.progress, 0.25);
    expect(g.projectedCents, (1000000 * 365 / 91).round());
    expect(goalStatus(1, 2026, es, DateTime(2026, 1, 10)).projectedCents, isNull);
    expect(goalStatus(1, 2025, es, DateTime(2026, 4, 1)).projectedCents, isNull);
    expect(goalStatus(0, 2026, es, DateTime(2026, 4, 1)).progress, 0);
  });
}
