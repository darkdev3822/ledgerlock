// Year-end checklist (Dec 1 - Jan 31): loose ends to tie up before filing, for the tax year that is ending. Pure:
// computed from what's already in the vault; items the app can't see are ticked by hand (stored as ids).
import 'attention.dart';
import 'database.dart';
import 'tax_rules.dart';

class YearEndItem {
  final String id, title, detail;

  /// 'auto' = the app checked it; 'manual' = the user ticks it.
  final bool auto;
  final bool done;

  /// Where to fix it: 'backup', 'receipts', 'invoices', 'payments', 'mileage', 'forms_1099', 'filed', 'none'.
  final String action;
  const YearEndItem(this.id, this.title, this.detail, {required this.auto, required this.done, required this.action});
}

/// The tax year whose checklist is due on [today], or null outside Dec 1 - Jan 31.
int? yearEndYear(DateTime today) => today.month == 12
    ? today.year
    : today.month == 1
    ? today.year - 1
    : null;

List<YearEndItem> yearEndItems({
  required int year,
  required TaxRules rules,
  required DateTime today,
  required List<AttentionItem> attention,
  required List<TaxPayment> payments,
  required List<Trip> trips,
  required List<Form1099> forms,
  required bool drives,
  required DateTime? lastBackup,
  required Set<String> ticked,
}) {
  int count(String kind) => attention.where((a) => a.kind == kind).fold(0, (n, a) => n + a.count);
  final q4 = rules.quarterlyDue.where((q) => q.quarter == 'Q4').firstOrNull;
  final q4Paid = payments.any((p) => p.taxYear == year && p.quarter == 'Q4');
  final backupFresh = lastBackup != null && today.difference(lastBackup).inDays < 30;
  final noReceipt = count('no_receipt'), oldInvoices = count('old_invoice'), higher = count('form_1099');
  final decTrips = trips.any((t) => t.date.startsWith('$year-12'));
  bool tick(String id) => ticked.contains(id);
  return [
    YearEndItem(
      'backup',
      'Make a fresh backup',
      backupFresh ? 'Done in the last 30 days.' : 'Keep it somewhere other than this phone.',
      auto: true,
      done: backupFresh,
      action: 'backup',
    ),
    YearEndItem(
      'receipts',
      'Attach receipts to bigger expenses',
      noReceipt == 0 ? 'Every expense over \$75 has one.' : '$noReceipt still without a receipt.',
      auto: true,
      done: noReceipt == 0,
      action: 'receipts',
    ),
    YearEndItem(
      'invoices',
      'Chase or close old invoices',
      oldInvoices == 0
          ? 'Nothing unpaid for over $oldInvoiceDays days.'
          : '$oldInvoices unpaid for over $oldInvoiceDays days. Mark them received, or delete ones you won\'t get.',
      auto: true,
      done: oldInvoices == 0,
      action: 'invoices',
    ),
    if (q4 != null)
      YearEndItem(
        'q4',
        'Q4 estimated payment',
        q4Paid ? 'Logged.' : 'Covers ${q4.covers}. Log it once paid.',
        auto: true,
        done: q4Paid,
        action: 'payments',
      ),
    if (drives || trips.isNotEmpty)
      YearEndItem(
        'mileage',
        'Log the last trips of the year',
        decTrips ? 'December trips are in.' : 'No December trips yet: add any you drove for business.',
        auto: false,
        done: tick('mileage') || decTrips,
        action: 'mileage',
      ),
    YearEndItem(
      'forms',
      'Enter your 1099s as they arrive',
      forms.isEmpty
          ? 'Tick this when you have them all (or know none are coming).'
          : higher == 0
          ? '${forms.length} entered, all matching your records.'
          : '${forms.length} entered; $higher higher than your records.',
      auto: false,
      done: tick('forms') && higher == 0,
      action: 'forms_1099',
    ),
    YearEndItem(
      'personal',
      'Check for personal spending',
      'Skim Records for anything that wasn\'t for the business, or needs a business %.',
      auto: false,
      done: tick('personal'),
      action: 'none',
    ),
  ];
}
