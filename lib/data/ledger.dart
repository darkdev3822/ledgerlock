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

  /// Income only: false = invoiced, not received yet. Cash basis: not counted until paid.
  final bool paid;

  const EntryData({
    required this.isIncome,
    required this.date,
    required this.amountCents,
    this.feeCents = 0,
    this.businessPct = 100,
    required this.category,
    this.paid = true,
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

/// Schedule SE, lines 4a-12. [w2WagesCents]: Social Security wages already taxed (W-2 box 3 + 7), which use up
/// the wage base before self-employment earnings do. The 12.4% part stops at the wage base; 2.9% has no cap.
/// The 0.9% Additional Medicare Tax is separate (Form 8959) and not included.
double seTaxFor(double netCents, TaxRules rules, {int w2WagesCents = 0}) {
  final earnings = netCents * rules.seNetEarningsFactor; // line 4a
  if (earnings < rules.seMinimumNetEarningsCents) return 0; // line 4c
  final ss = rules.seSocialSecurityRate;
  final base = rules.ssWageBaseCents;
  // No verified split/base: flat rate (conservative: can only overstate).
  if (ss <= 0 || base == null) return earnings * rules.seRate;
  final room = (base - w2WagesCents).clamp(0, base).toDouble(); // line 9
  final ssTax = (earnings < room ? earnings : room) * ss; // line 10
  return ssTax + earnings * (rules.seRate - ss); // + line 11
}

LedgerSummary summarize(
  Iterable<EntryData> entries,
  TaxRules rules, {
  double? setAsidePct,
  int w2WagesCents = 0,
  int mileageCents = 0,
  int homeOfficeCents = 0,
}) {
  final lines = <String, double>{};
  final monthly = <int, (double, double)>{};
  void add(String line, double v) => lines[line] = (lines[line] ?? 0) + v;

  for (final e in entries) {
    if (e.date.year != rules.year) continue;
    if (e.isIncome && !e.paid) continue; // invoiced, not received: cash basis
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
  if (mileageCents > 0) add('9', mileageCents.toDouble());
  final gross = (lines['1'] ?? 0) - (lines['2'] ?? 0) + (lines['6'] ?? 0);
  final expenses = lines.entries
      .where((e) => !const {'1', '2', '6'}.contains(e.key))
      .fold(0.0, (a, e) => a + e.value);
  // Line 30 (home office, simplified method) can't create or increase a loss.
  final tentative = gross - expenses;
  final office = homeOfficeCents <= 0 || tentative <= 0
      ? 0.0
      : (homeOfficeCents < tentative ? homeOfficeCents.toDouble() : tentative);
  if (office > 0) lines['30'] = office;
  final net = tentative - office;
  final seTax = seTaxFor(net, rules, w2WagesCents: w2WagesCents);
  final pct = setAsidePct ?? rules.defaultSetAsidePct;
  return LedgerSummary(
    lines: {
      for (final e in lines.entries)
        if (e.value != 0) e.key: _r(e.value),
    },
    grossCents: _r(gross),
    expensesCents: _r(expenses + office),
    netCents: _r(net),
    seTaxCents: _r(seTax < 0 ? 0 : seTax),
    setAsideCents: _r((net < 0 ? 0 : net) * pct / 100),
    setAsidePct: pct,
    monthly: {for (final m in monthly.entries) m.key: (_r(m.value.$1), _r(m.value.$2))},
  );
}
