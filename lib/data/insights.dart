// Year-over-year insights (SPEC §3): "Software spend up 40% vs this point in 2025". Pure maths over the user's own
// records, on the device. For the current year it compares like with like: Jan 1 to today against Jan 1 to the
// same day last year, so a half-finished year never looks like a collapse.
import 'ledger.dart';

class Insight {
  /// 'income' | 'net' | 'category' | 'new_category' | 'top_category'
  final String kind;
  final String? category; // category id for category kinds
  final int thisCents, lastCents;
  const Insight(this.kind, {this.category, required this.thisCents, required this.lastCents});

  int get deltaCents => thisCents - lastCents;

  /// Whole-percent change, null when last year was zero.
  int? get pct => lastCents == 0 ? null : ((thisCents - lastCents) * 100 / lastCents.abs()).round();
}

/// Business share of an expense, before any meals-style limit: what the user actually spent for the business.
int _spend(EntryData e) => (e.amountCents * e.businessPct / 100).round();

/// Up to [max] insights for [year], comparing with [lastYear] entries. [today] picks the year-to-date cutoff.
List<Insight> yearInsights(
  int year,
  Iterable<EntryData> thisYear,
  Iterable<EntryData> lastYear,
  DateTime today, {
  int max = 4,
}) {
  final ytd = today.year == year;
  // Same calendar day last year (Feb 29 -> Feb 28).
  bool inWindow(DateTime d, int y) {
    if (!ytd) return true;
    final day = DateTime(y, today.month, today.day.clamp(1, DateTime(y, today.month + 1, 0).day));
    return !d.isAfter(day);
  }

  Map<String, int> spendByCat(Iterable<EntryData> es, int y) {
    final m = <String, int>{};
    for (final e in es) {
      if (e.isIncome || e.date.year != y || !inWindow(e.date, y)) continue;
      m[e.category] = (m[e.category] ?? 0) + _spend(e);
    }
    return m;
  }

  int income(Iterable<EntryData> es, int y) => es
      .where((e) => e.isIncome && e.paid && e.date.year == y && inWindow(e.date, y))
      .fold(0, (a, e) => a + e.amountCents);

  final now = spendByCat(thisYear, year), before = spendByCat(lastYear, year - 1);
  final incNow = income(thisYear, year), incBefore = income(lastYear, year - 1);
  final out = <Insight>[];
  final hasLastYear = before.isNotEmpty || incBefore > 0;

  if (!hasLastYear) {
    // Nothing to compare with yet: say where the money goes instead.
    final total = now.values.fold(0, (a, v) => a + v);
    if (total > 0) {
      final top = now.entries.reduce((a, b) => b.value > a.value ? b : a);
      out.add(Insight('top_category', category: top.key, thisCents: top.value, lastCents: total));
    }
    return out;
  }

  // Income: worth a line when it moved by 10% and $100 or more.
  final dIncome = incNow - incBefore;
  if (dIncome.abs() >= 10000 && (incBefore == 0 || dIncome.abs() * 10 >= incBefore)) {
    out.add(Insight('income', thisCents: incNow, lastCents: incBefore));
  }

  // Categories: moved by 25% and $50 or more, or new this year with $100 or more. Biggest change first.
  final movers = <Insight>[];
  for (final c in {...now.keys, ...before.keys}) {
    final a = now[c] ?? 0, b = before[c] ?? 0, d = a - b;
    if (b == 0) {
      if (a >= 10000) movers.add(Insight('new_category', category: c, thisCents: a, lastCents: 0));
    } else if (d.abs() >= 5000 && d.abs() * 4 >= b) {
      movers.add(Insight('category', category: c, thisCents: a, lastCents: b));
    }
  }
  movers.sort((x, y) => y.deltaCents.abs().compareTo(x.deltaCents.abs()));
  out.addAll(movers);
  return out.take(max).toList();
}
