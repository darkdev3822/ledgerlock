// Ledger maths, ported from the desktop Tax Keeper's Store.summary() (SPEC §2, M3).
// Pure functions over plain data so they're easy to test against the desktop app.
import 'tax_rules.dart';

/// Plain view of a ledger entry for maths (decoupled from the drift row class).
class EntryData {
  final bool isIncome;
  final DateTime date;
  final int amountCents; // gross for income
  final int feeCents; // platform fee kept from income (deductible, line 10)
  final int businessPct; // expenses only, 0..100
  final String category;

  const EntryData({
    required this.isIncome,
    required this.date,
    required this.amountCents,
    this.feeCents = 0,
    this.businessPct = 100,
    required this.category,
  });
}

class LedgerSummary {
  /// Schedule C line -> cents (rounded).
  final Map<String, int> lines;
  final int grossCents, expensesCents, netCents, seTaxCents, setAsideCents;
  final double setAsidePct;

  /// Month (1..12) -> (income, deductible expenses) in cents, for the chart.
  final Map<int, (int, int)> monthly;

  const LedgerSummary({
    required this.lines,
    required this.grossCents,
    required this.expensesCents,
    required this.netCents,
    required this.seTaxCents,
    required this.setAsideCents,
    required this.setAsidePct,
    required this.monthly,
  });

  static const empty = LedgerSummary(
    lines: {},
    grossCents: 0,
    expensesCents: 0,
    netCents: 0,
    seTaxCents: 0,
    setAsideCents: 0,
    setAsidePct: 25,
    monthly: {},
  );

  int get incomeCents => grossCents;
}

/// Deductible part of one expense, in exact (fractional) cents.
double deductibleCents(EntryData e, TaxRules rules) {
  final share = rules.category(e.category)?.deductibleShare ?? 1.0;
  return e.amountCents * e.businessPct / 100 * share;
}

/// Half-up rounding (the IRS allows whole dollars; we keep cents).
int _r(double cents) => cents.isNegative ? -((-cents) + 0.5).floor() : (cents + 0.5).floor();

LedgerSummary summarize(Iterable<EntryData> entries, TaxRules rules, {double? setAsidePct}) {
  final lines = <String, double>{};
  final monthly = <int, (double, double)>{};
  void add(String line, double v) => lines[line] = (lines[line] ?? 0) + v;

  for (final e in entries) {
    if (e.date.year != rules.year) continue;
    final (mi, me) = monthly[e.date.month] ?? (0.0, 0.0);
    if (e.isIncome) {
      final line = rules.category(e.category)?.line ?? '6';
      add(line, e.amountCents.toDouble());
      add('10', e.feeCents.toDouble()); // platform fee kept out of the payout
      final signed = line == '2' ? -e.amountCents.toDouble() : e.amountCents.toDouble();
      monthly[e.date.month] = (mi + signed, me + e.feeCents);
    } else {
      final line = rules.category(e.category)?.line ?? '27a';
      final d = deductibleCents(e, rules);
      add(line, d);
      monthly[e.date.month] = (mi, me + d);
    }
  }
  // Lines 9 (mileage) and 30 (home office) arrive with M6.
  final gross = (lines['1'] ?? 0) - (lines['2'] ?? 0) + (lines['6'] ?? 0);
  final expenses = lines.entries
      .where((e) => !const {'1', '2', '6'}.contains(e.key))
      .fold(0.0, (a, e) => a + e.value);
  final net = gross - expenses;
  final netEarnings = net * rules.seNetEarningsFactor;
  final seTax = netEarnings >= rules.seMinimumNetEarningsCents ? netEarnings * rules.seRate : 0.0;
  final pct = setAsidePct ?? rules.defaultSetAsidePct;
  return LedgerSummary(
    lines: {
      for (final e in lines.entries)
        if (e.value != 0) e.key: _r(e.value),
    },
    grossCents: _r(gross),
    expensesCents: _r(expenses),
    netCents: _r(net),
    seTaxCents: _r(seTax < 0 ? 0 : seTax),
    setAsideCents: _r((net < 0 ? 0 : net) * pct / 100),
    setAsidePct: pct,
    monthly: {for (final m in monthly.entries) m.key: (_r(m.value.$1), _r(m.value.$2))},
  );
}
