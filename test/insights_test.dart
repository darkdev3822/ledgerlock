import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerlock/data/insights.dart';
import 'package:ledgerlock/data/ledger.dart';

EntryData x(String d, int c, {String cat = 'software', bool inc = false, int pct = 100, bool paid = true}) =>
    EntryData(isIncome: inc, date: DateTime.parse(d), amountCents: c, category: cat, businessPct: pct, paid: paid);

void main() {
  final today = DateTime(2026, 6, 30);

  test('year to date compares Jan 1 - today with the same window last year', () {
    final now = [x('2026-03-01', 140000), x('2026-02-01', 500000, cat: 'services', inc: true)];
    final before = [
      x('2025-03-01', 100000),
      x('2025-11-01', 900000), // after Jun 30 last year: outside the window
      x('2025-02-01', 400000, cat: 'services', inc: true),
    ];
    final ins = yearInsights(2026, now, before, today);
    final sw = ins.firstWhere((i) => i.category == 'software');
    expect((sw.thisCents, sw.lastCents, sw.pct), (140000, 100000, 40));
    final inc = ins.firstWhere((i) => i.kind == 'income');
    expect(inc.pct, 25);
  });

  test('a past year compares whole years', () {
    final ins = yearInsights(2025, [x('2025-11-01', 50000)], [x('2024-02-01', 20000)], today);
    expect(ins.single.pct, 150);
  });

  test('small moves are ignored; new categories need \$100; biggest change first; at most 4', () {
    final now = [
      x('2026-01-05', 10400), // software +4%: ignored
      x('2026-01-05', 9000, cat: 'travel'), // new but under $100: ignored
      x('2026-01-05', 30000, cat: 'meals'), // new, $300
      x('2026-01-05', 20000, cat: 'office'), // office 80000 -> 20000: -75%
      x('2026-01-05', 1000, cat: 'utilities'), // 4000 -> 1000: -$30, under $50: ignored
    ];
    final before = [
      x('2025-01-05', 10000),
      x('2025-01-05', 80000, cat: 'office'),
      x('2025-01-05', 4000, cat: 'utilities'),
    ];
    final ins = yearInsights(2026, now, before, today);
    expect(ins.map((i) => (i.kind, i.category)), [('category', 'office'), ('new_category', 'meals')]);
  });

  test('business-use share counts; unpaid invoices do not', () {
    final ins = yearInsights(
      2026,
      [x('2026-01-05', 20000, pct: 50), x('2026-01-05', 900000, inc: true, cat: 'services', paid: false)],
      [x('2025-01-05', 30000)],
      today,
    );
    expect(ins.map((i) => i.kind), ['category']);
    expect(ins.single.thisCents, 10000);
  });

  test('no last year: the top category instead; nothing at all: no insights', () {
    final ins = yearInsights(2026, [x('2026-01-05', 30000), x('2026-01-06', 10000, cat: 'office')], [], today);
    expect((ins.single.kind, ins.single.category, ins.single.thisCents, ins.single.lastCents), (
      'top_category',
      'software',
      30000,
      40000,
    ));
    expect(yearInsights(2026, [], [], today), isEmpty);
  });

  test('Feb 29 today compares with Feb 28 last year', () {
    final ins = yearInsights(
      2028,
      [x('2028-02-29', 20000)],
      [x('2027-02-28', 10000), x('2027-03-01', 99999)],
      DateTime(2028, 2, 29),
    );
    expect(ins.single.lastCents, 10000);
  });
}
