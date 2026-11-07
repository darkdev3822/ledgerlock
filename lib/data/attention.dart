// Home "Needs attention" (SPEC §3 checklist spirit): small loose ends that pile up until April. Pure: computed from
// what is already on screen, nothing stored except which rows the user hid.
import 'database.dart';
import 'tax_packet.dart' show recordedFrom;

class AttentionItem {
  /// 'no_receipt' | 'old_invoice' | 'form_1099'
  final String kind;
  final int count;

  /// Total involved: expenses without receipts, unpaid invoices, or how much higher the 1099s are.
  final int cents;
  const AttentionItem(this.kind, this.count, this.cents);
}

/// Housekeeping threshold for "no receipt" (the app's own nudge, not an IRS rule).
const receiptNudgeCents = 7500;
const oldInvoiceDays = 30;

List<AttentionItem> attentionItems({
  required Iterable<LedgerEntry> entries,
  required Set<int> withReceipt,
  required Iterable<Form1099> forms,
  required DateTime today,
}) {
  final out = <AttentionItem>[];
  final noReceipt = entries.where(
    (e) => !e.isIncome && e.amountCents > receiptNudgeCents && !withReceipt.contains(e.id),
  );
  if (noReceipt.isNotEmpty) {
    out.add(AttentionItem('no_receipt', noReceipt.length, noReceipt.fold(0, (a, e) => a + e.amountCents)));
  }
  final cutoff = DateTime(today.year, today.month, today.day).subtract(const Duration(days: oldInvoiceDays));
  final old = entries.where((e) => e.isIncome && !e.paid && e.day.isBefore(cutoff));
  if (old.isNotEmpty) out.add(AttentionItem('old_invoice', old.length, old.fold(0, (a, e) => a + e.amountCents)));
  // Same rule as the 1099 screen: only the form being higher (by more than $1) may mean missing income.
  final higher = [
    for (final f in forms)
      if (f.amountCents - recordedFrom(f.payer, entries) > 100) f.amountCents - recordedFrom(f.payer, entries),
  ];
  if (higher.isNotEmpty) out.add(AttentionItem('form_1099', higher.length, higher.fold(0, (a, d) => a + d)));
  return out;
}
