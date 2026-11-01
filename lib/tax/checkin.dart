// "Keep me in check" (SPEC §2.13) and the reminder schedule. Pure functions over the user's own records:
// nothing leaves the device, and notification text is always generic (no amounts, no payees).
import 'package:intl/intl.dart';

import '../data/database.dart';
import '../data/tax_rules.dart';
import 'guidance.dart';

enum CheckInAction { addEntry, receipts, categorize, unpaid, paymentLog, forms1099 }

class CheckInQuestion {
  /// Stable per period, so "Nothing missed" hides it until the situation changes.
  final String key;
  final String text;
  final CheckInAction action;

  /// Search text for actions that open search ("no receipt", "unpaid"…).
  final String query;
  const CheckInQuestion(this.key, this.text, this.action, {this.query = ''});
}

const checkInFrequencies = {'off': 0, 'weekly': 7, 'biweekly': 14, 'monthly': 30};

String _m(DateTime d) => DateFormat.MMMM().format(d);

/// Up to [max] questions, most important first. [dismissed]: keys the user answered "Nothing missed" to.
List<CheckInQuestion> checkInQuestions({
  required DateTime today,
  required List<LedgerEntry> entries, // this year and last year
  required Set<int> entriesWithReceipt,
  required List<TaxPayment> payments, // for today's tax year
  required List<Form1099> formsLastYear,
  required TaxRules? rules,
  Set<String> dismissed = const {},
  int max = 5,
}) {
  final out = <CheckInQuestion>[];
  void ask(CheckInQuestion q) {
    if (!dismissed.contains(q.key)) out.add(q);
  }

  final d0 = DateTime(today.year, today.month, today.day);
  final thisYear = entries.where((e) => e.day.year == today.year).toList();

  // 1. Quarterly payment due within 14 days and nothing logged for that quarter.
  final next = rules?.nextDue(d0);
  if (next != null) {
    final days = next.due.difference(d0).inDays;
    final paid = payments.any((p) => p.quarter == next.quarter);
    if (days <= 14 && !paid) {
      ask(
        CheckInQuestion(
          'due:${rules!.year}:${next.quarter}',
          '${next.quarter} estimated tax is due ${DateFormat.MMMd().format(next.due)}. Have you paid? Log it so your '
              'numbers stay right.',
          CheckInAction.paymentLog,
        ),
      );
    }
  }

  // 2. Nothing recorded for 3+ weeks (only once the user has started recording).
  if (entries.isNotEmpty) {
    final last = entries.map((e) => e.day).reduce((a, b) => a.isAfter(b) ? a : b);
    if (d0.difference(last).inDays >= 21) {
      ask(
        CheckInQuestion(
          'quiet:${isoDay(last)}',
          'Nothing recorded since ${DateFormat.MMMd().format(last)}. Any income or expenses to add?',
          CheckInAction.addEntry,
        ),
      );
    }
  }

  // 3. A payee recorded in 3 of the previous 4 months but not yet this month (after their usual day).
  int monthKey(DateTime d) => d.year * 12 + d.month;
  final now = monthKey(d0);
  final byParty = <String, ({Set<int> months, List<int> days, String name})>{};
  for (final e in entries) {
    final p = e.party.trim();
    if (p.isEmpty) continue;
    final k = p.toLowerCase();
    final cur = byParty[k] ?? (months: <int>{}, days: <int>[], name: p);
    cur.months.add(monthKey(e.day));
    cur.days.add(e.day.day);
    byParty[k] = cur;
  }
  for (final v in byParty.values) {
    final prev = [for (var i = 1; i <= 4; i++) now - i].where(v.months.contains).length;
    if (prev < 3 || v.months.contains(now)) continue;
    final usual = (v.days..sort())[v.days.length ~/ 2];
    if (d0.day <= usual + 3) continue;
    ask(
      CheckInQuestion(
        'recurring:${v.name.toLowerCase()}:$now',
        'You usually record ${v.name} every month. Nothing for ${_m(d0)} yet: missed one?',
        CheckInAction.addEntry,
      ),
    );
  }

  // 4. Invoices still unpaid after 30 days.
  final stale = thisYear.where((e) => e.isIncome && !e.paid && d0.difference(e.day).inDays >= 30).length;
  if (stale > 0) {
    ask(
      CheckInQuestion(
        'unpaid:$stale:${isoDay(d0).substring(0, 7)}',
        '$stale invoice${stale == 1 ? ' is' : 's are'} still marked unpaid after a month. Were they paid?',
        CheckInAction.unpaid,
        query: 'unpaid',
      ),
    );
  }

  // 5. Expenses without a receipt.
  final noReceipt = thisYear.where((e) => !e.isIncome && !entriesWithReceipt.contains(e.id)).length;
  if (noReceipt > 0) {
    ask(
      CheckInQuestion(
        'receipts:$noReceipt',
        '$noReceipt expense${noReceipt == 1 ? ' has' : 's have'} no receipt attached. Add the ones you have?',
        CheckInAction.receipts,
        query: 'no receipt',
      ),
    );
  }

  // 6. Records still in "Other".
  final other = thisYear.where((e) => e.category == 'other_expense' || e.category == 'other_income').length;
  if (other > 0) {
    ask(
      CheckInQuestion(
        'other:$other',
        '$other record${other == 1 ? ' is' : 's are'} in "Other". A specific category makes your Schedule C clearer.',
        CheckInAction.categorize,
        query: 'uncategorized',
      ),
    );
  }

  // 7. Jan-Mar: platforms with last year's income but no 1099 entered.
  if (today.month <= 3) {
    final ly = today.year - 1;
    final have = formsLastYear.map((f) => f.payer.trim().toLowerCase()).toSet();
    final platforms = {
      for (final e in entries)
        if (e.day.year == ly && e.isIncome && isPaymentPlatform(e.platform)) e.platform.trim(),
    }.where((p) => !have.contains(p.toLowerCase())).toList()..sort();
    if (platforms.isNotEmpty) {
      ask(
        CheckInQuestion(
          '1099:$ly:${platforms.join(',').toLowerCase()}',
          'Have any $ly 1099s arrived from ${platforms.join(', ')}? Add them to compare with your records.',
          CheckInAction.forms1099,
        ),
      );
    }
  }

  return out.take(max).toList();
}

/// One scheduled notification. Text must stay generic: it's shown on the lock screen and stored outside the vault.
class ReminderItem {
  final int id;
  final DateTime at;
  final String title, body;
  const ReminderItem(this.id, this.at, this.title, this.body);
  Map<String, Object> toMap() => {'id': id, 'at': at.millisecondsSinceEpoch, 'title': title, 'body': body};
}

/// Quarterly reminders (7 days and 1 day before, 9:00) and check-ins every [checkInDays] (18:00), future only.
List<ReminderItem> planReminders({
  required DateTime now,
  required Iterable<TaxRules> rules,
  required bool quarterly,
  required int checkInDays,
  DateTime? lastCheckIn,
}) {
  final out = <ReminderItem>[];
  if (quarterly) {
    for (final r in rules) {
      for (final (i, q) in r.quarterlyDue.indexed) {
        for (final (k, before, title) in [
          (0, 7, 'Estimated tax payment due in a week'),
          (1, 1, 'Estimated tax payment due tomorrow'),
        ]) {
          final at = DateTime(q.due.year, q.due.month, q.due.day - before, 9);
          if (at.isAfter(now)) {
            out.add(
              ReminderItem(r.year * 100 + i * 10 + k, at, title, 'Open LedgerLock to check your set-aside.'),
            );
          }
        }
      }
    }
  }
  if (checkInDays > 0) {
    var at = DateTime((lastCheckIn ?? now).year, (lastCheckIn ?? now).month, (lastCheckIn ?? now).day, 18);
    for (var n = 0; n < 8; n++) {
      at = DateTime(at.year, at.month, at.day + checkInDays, 18);
      if (!at.isAfter(now)) {
        n--;
        continue;
      }
      out.add(
        ReminderItem(
          1 + n, // check-ins 1..8; quarterly ids are year*100+…
          at,
          'Time for a quick check-in',
          'A few questions to catch anything you missed.',
        ),
      );
    }
  }
  out.sort((a, b) => a.at.compareTo(b.at));
  return out;
}
