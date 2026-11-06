// Recurring records (SPEC §3): subscriptions, rent share, retainers. Pure date maths, kept apart from the DB so
// it can be tested exhaustively. A rule remembers the day of the month it started on (anchorDay), so a record
// that starts on Jan 31 lands on Feb 28, then Mar 31 (not Mar 28).

const recurringEvery = ['week', 'month', 'year'];

/// How many copies one rule may add in a single catch-up (a rule backdated years, or a phone left for months).
const maxCatchUp = 120;

String everyLabel(String every) => switch (every) {
  'week' => 'Every week',
  'month' => 'Every month',
  'year' => 'Every year',
  _ => 'Never',
};

int _daysIn(int year, int month) => DateTime(year, month + 1, 0).day;

/// The date after [d] for a rule repeating [every], keeping [anchorDay] where the month allows it.
DateTime stepDate(DateTime d, String every, int anchorDay) {
  switch (every) {
    case 'week':
      return DateTime(d.year, d.month, d.day + 7);
    case 'year':
      final day = anchorDay.clamp(1, _daysIn(d.year + 1, d.month));
      return DateTime(d.year + 1, d.month, day);
    default: // month
      final m = DateTime(d.year, d.month + 1); // normalises December -> January
      return DateTime(m.year, m.month, anchorDay.clamp(1, _daysIn(m.year, m.month)));
  }
}

/// Every date from [next] up to and including [today] (dates only), at most [maxCatchUp].
List<DateTime> dueDates(DateTime next, String every, int anchorDay, DateTime today) {
  final end = DateTime(today.year, today.month, today.day);
  final out = <DateTime>[];
  var d = DateTime(next.year, next.month, next.day);
  while (!d.isAfter(end) && out.length < maxCatchUp) {
    out.add(d);
    d = stepDate(d, every, anchorDay);
  }
  return out;
}
