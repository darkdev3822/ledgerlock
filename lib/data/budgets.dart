// Budgets and an income goal (SPEC §3). Pure maths over the user's records, on the device.
import 'ledger.dart';

class BudgetStatus {
  final String category;
  final int capCents, spentCents;

  /// Share of the month gone (0..1), to compare spending pace with.
  final double monthElapsed;
  const BudgetStatus(this.category, this.capCents, this.spentCents, this.monthElapsed);

  double get used => capCents <= 0 ? 0 : spentCents / capCents;
  bool get over => spentCents > capCents;

  /// Spending ahead of the calendar by more than 10 points (and not over yet).
  bool get ahead => !over && used > monthElapsed + 0.10;
}

/// Spending per budgeted category in [today]'s month. What left the account (amount), not the deductible share.
List<BudgetStatus> budgetStatus(Map<String, int> budgets, Iterable<EntryData> entries, DateTime today) {
  final days = DateTime(today.year, today.month + 1, 0).day;
  final elapsed = today.day / days;
  final spent = <String, int>{};
  for (final e in entries) {
    if (e.isIncome || e.date.year != today.year || e.date.month != today.month) continue;
    spent[e.category] = (spent[e.category] ?? 0) + e.amountCents;
  }
  return [
    for (final b in budgets.entries)
      if (b.value > 0) BudgetStatus(b.key, b.value, spent[b.key] ?? 0, elapsed),
  ]..sort((a, b) => b.used.compareTo(a.used));
}

class GoalStatus {
  final int goalCents, receivedCents;

  /// Received so far scaled to the whole year at the current pace; null for a past or future year.
  final int? projectedCents;
  const GoalStatus(this.goalCents, this.receivedCents, this.projectedCents);

  double get progress => goalCents <= 0 ? 0 : receivedCents / goalCents;
}

/// Income received in [year] (gross, paid only) against [goalCents].
GoalStatus goalStatus(int goalCents, int year, Iterable<EntryData> entries, DateTime today) {
  final received = entries
      .where((e) => e.isIncome && e.paid && e.date.year == year)
      .fold(0, (a, e) => a + e.amountCents);
  int? projected;
  if (today.year == year) {
    final start = DateTime.utc(year), end = DateTime.utc(year + 1);
    final dayOfYear = DateTime.utc(year, today.month, today.day).difference(start).inDays + 1;
    final daysInYear = end.difference(start).inDays;
    // Too early to project anything honest in the first two weeks.
    if (dayOfYear >= 14) projected = (received * daysInYear / dayOfYear).round();
  }
  return GoalStatus(goalCents, received, projected);
}
