// Tax packet PDF (SPEC §3): a summary of the user's own records to hand to a preparer. It is NOT a tax
// return and never says so (the draft return is a separate, owner-gated feature). Pure Dart via `pdf`.
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'database.dart';
import 'ledger.dart';
import 'tax_rules.dart';

/// Paid income recorded from a 1099 payer (matched on platform or payee, case-insensitive).
int recordedFrom(String payer, Iterable<LedgerEntry> entries) {
  final p = payer.trim().toLowerCase();
  if (p.isEmpty) return 0;
  return entries
      .where((e) => e.isIncome && e.paid && (e.platform.trim().toLowerCase() == p || e.party.trim().toLowerCase() == p))
      .fold(0, (a, e) => a + e.amountCents);
}

const packetDisclaimer =
    'This is a summary of records you entered in LedgerLock. It is not a tax return and not tax, legal or '
    'financial advice. Figures are estimates from your own entries; check them, and keep your receipts.';

final _usd = NumberFormat.currency(locale: 'en_US', symbol: r'$');
String _money(int cents) => _usd.format(cents / 100);

/// Packet data, gathered by the caller so this stays testable.
class PacketInput {
  final int year;
  final TaxRules rules;
  final LedgerSummary summary;
  final List<LedgerEntry> entries;
  final List<Trip> trips;
  final List<TaxPayment> payments;
  final List<Form1099> forms;
  final int mileageCents, homeOfficeCents;
  final DateTime generated;
  const PacketInput({
    required this.year,
    required this.rules,
    required this.summary,
    required this.entries,
    this.trips = const [],
    this.payments = const [],
    this.forms = const [],
    this.mileageCents = 0,
    this.homeOfficeCents = 0,
    required this.generated,
  });
}

/// Category id -> (count, recorded cents, deductible cents) for the year, paid income only.
Map<String, (int, int, int)> categoryBreakdown(PacketInput p) {
  final out = <String, (int, int, int)>{};
  for (final e in p.entries) {
    if (e.day.year != p.year || (e.isIncome && !e.paid)) continue;
    final share = p.rules.category(e.category)?.deductibleShare ?? 1.0;
    final ded = e.isIncome ? e.amountCents : (e.amountCents * e.businessPct / 100 * share).round();
    final c = out[e.category] ?? (0, 0, 0);
    out[e.category] = (c.$1 + 1, c.$2 + e.amountCents, c.$3 + ded);
  }
  return out;
}

Future<Uint8List> buildTaxPacket(PacketInput p, {bool compress = true}) async {
  final doc = pw.Document(
    compress: compress,
    title: 'LedgerLock tax packet ${p.year}',
    creator: 'LedgerLock',
    producer: 'LedgerLock',
  );
  final s = p.summary;
  final h1 = pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold);
  final h2 = pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold);
  const small = pw.TextStyle(fontSize: 9, color: PdfColors.grey700);

  pw.Widget section(String title) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 18, bottom: 6),
    child: pw.Text(title, style: h2),
  );
  pw.Widget table(List<String> head, List<List<String>> rows, {Set<int> right = const {}}) => rows.isEmpty
      ? pw.Text('None recorded.', style: small)
      : pw.TableHelper.fromTextArray(
          headers: head,
          data: rows,
          border: null,
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          rowDecoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
          ),
          cellAlignments: {for (final i in right) i: pw.Alignment.centerRight},
          headerAlignments: {
            for (var i = 0; i < head.length; i++)
              i: right.contains(i) ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
          },
        );

  final unpaid = p.entries.where((e) => e.day.year == p.year && e.isIncome && !e.paid).toList();
  final breakdown = categoryBreakdown(p).entries.toList()
    ..sort((a, b) {
      final ca = p.rules.category(a.key), cb = p.rules.category(b.key);
      final ia = ca?.isIncome ?? false, ib = cb?.isIncome ?? false;
      if (ia != ib) return ia ? -1 : 1;
      return b.value.$3.compareTo(a.value.$3);
    });
  final tripsYear = p.trips.where((t) => t.date.startsWith('${p.year}-')).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  final miles = tripsYear.fold(0, (a, t) => a + t.milesTenths) / 10;
  final paidTotal = p.payments.fold(0, (a, x) => a + x.amountCents);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.all(48),
      footer: (c) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('LedgerLock tax packet ${p.year} · not a tax return', style: small),
          pw.Text('Page ${c.pageNumber} of ${c.pagesCount}', style: small),
        ],
      ),
      build: (_) => [
        pw.Text('Tax packet ${p.year}', style: h1),
        pw.SizedBox(height: 4),
        pw.Text(
          'Self-employment records (Schedule C) · generated ${DateFormat.yMMMd().format(p.generated)}',
          style: small,
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey500, width: 0.5)),
          child: pw.Text(packetDisclaimer, style: const pw.TextStyle(fontSize: 9)),
        ),
        section('Summary'),
        table(
          ['', 'Amount'],
          [
            ['Gross income (paid, cash basis)', _money(s.grossCents)],
            ['Deductible expenses (incl. mileage and home office)', _money(s.expensesCents)],
            ['Net profit (estimate)', _money(s.netCents)],
            ['Self-employment tax (estimate)', _money(s.seTaxCents)],
            ['Estimated tax payments logged', _money(paidTotal)],
            if (p.mileageCents > 0) ['  of which mileage (${miles.toStringAsFixed(1)} mi)', _money(p.mileageCents)],
            if (p.homeOfficeCents > 0) ['  of which home office (simplified)', _money(p.homeOfficeCents)],
          ],
          right: {1},
        ),
        if (unpaid.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Text(
              '${unpaid.length} invoice(s) totalling ${_money(unpaid.fold(0, (a, e) => a + e.amountCents))} are '
              'marked not received and are excluded above.',
              style: small,
            ),
          ),
        section('By Schedule C line'),
        table(
          ['Line', 'Description', 'Amount'],
          [
            for (final l in p.rules.lineNames.entries)
              if ((s.lines[l.key] ?? 0) != 0) [l.key, l.value, _money(s.lines[l.key]!)],
          ],
          right: {2},
        ),
        section('By category'),
        table(
          ['Category', 'Line', 'Records', 'Recorded', 'Counted'],
          [
            for (final b in breakdown)
              [
                p.rules.category(b.key)?.name ?? b.key,
                p.rules.category(b.key)?.line ?? '',
                '${b.value.$1}',
                _money(b.value.$2),
                _money(b.value.$3),
              ],
          ],
          right: {2, 3, 4},
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.Text(
            '"Counted" applies business-use % and limits such as the meals share. Income is gross; platform fees '
            'are listed as an expense line.',
            style: small,
          ),
        ),
        section('1099 check'),
        table(
          ['From', 'Form', 'On the form', 'Your records', 'Difference'],
          [
            for (final f in p.forms)
              () {
                final rec = recordedFrom(f.payer, p.entries.where((e) => e.day.year == p.year));
                return [f.payer, f.kind, _money(f.amountCents), _money(rec), _money(f.amountCents - rec)];
              }(),
          ],
          right: {2, 3, 4},
        ),
        section('Estimated tax payments'),
        table(
          ['Date', 'Quarter', 'Method', 'Amount'],
          [
            for (final x in p.payments) [x.date, x.quarter, x.method, _money(x.amountCents)],
          ],
          right: {3},
        ),
        section('Mileage log'),
        table(
          ['Date', 'Miles', 'Purpose', 'Route'],
          [
            for (final t in tripsYear) [t.date, (t.milesTenths / 10).toStringAsFixed(1), t.purpose, t.route],
          ],
          right: {1},
        ),
      ],
    ),
  );
  return doc.save();
}
