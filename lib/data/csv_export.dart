// CSV export (SPEC §2.9). Plain text by design: the user asked for a file outside the vault.
import 'dart:convert';

import 'database.dart';
import 'tax_rules.dart';

/// One CSV cell. Quotes when needed, and neutralises spreadsheet formulas (CSV injection, SECURITY.md T11):
/// text starting with = + - @ tab or CR gets a leading apostrophe so Excel/Sheets show it as text.
String csvCell(Object? v) {
  var s = v?.toString() ?? '';
  if (v is String && s.isNotEmpty && '=+-@\t\r'.contains(s[0]) && num.tryParse(s) == null) s = "'$s";
  if (s.contains(RegExp(r'[",\r\n]')) || s.startsWith("'")) s = '"${s.replaceAll('"', '""')}"';
  return s;
}

String _money(int cents) => (cents / 100).toStringAsFixed(2);

String _csv(List<List<Object?>> rows) => '${rows.map((r) => r.map(csvCell).join(',')).join('\r\n')}\r\n';

/// Records for one year: one row per entry, with the Schedule C line.
String entriesCsv(Iterable<LedgerEntry> entries, TaxRules rules) => _csv([
  [
    'Date',
    'Type',
    'Amount',
    'Fee',
    'Business %',
    'Category',
    'Schedule C line',
    'Payee/Payer',
    'Platform',
    'Received',
    'Notes',
  ],
  for (final e in entries)
    [
      e.date,
      e.isIncome ? 'Income' : 'Expense',
      _money(e.amountCents),
      _money(e.feeCents),
      e.isIncome ? '' : e.businessPct,
      rules.category(e.category)?.name ?? e.category,
      rules.category(e.category)?.line ?? '',
      e.party,
      e.platform,
      e.isIncome ? (e.paid ? 'Yes' : 'No (invoiced)') : '',
      e.notes,
    ],
]);

String tripsCsv(Iterable<Trip> trips) => _csv([
  ['Date', 'Miles', 'Business purpose', 'Route'],
  for (final t in trips) [t.date, (t.milesTenths / 10).toStringAsFixed(1), t.purpose, t.route],
]);

String paymentsCsv(Iterable<TaxPayment> payments) => _csv([
  ['Date', 'Tax year', 'Quarter', 'Amount', 'Method', 'Notes'],
  for (final p in payments) [p.date, p.taxYear, p.quarter, _money(p.amountCents), p.method, p.notes],
]);

/// UTF-8 with BOM so Excel opens non-ASCII payees correctly.
List<int> csvBytes(String csv) => [0xEF, 0xBB, 0xBF, ...utf8.encode(csv)];
