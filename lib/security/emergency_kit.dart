// Printable "Emergency Kit" (SPEC §1 recovery key). Deliberately contains NO secret: the user hand-writes the
// recovery key into the boxes after printing (SECURITY.md T13). A PDF holding the key would be a vault-opening
// file that drifts into Downloads, cloud backups and print spoolers.
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Groups x characters of the recovery key (30 Crockford base32 chars, 6 groups of 5).
const kitGroups = 6, kitGroupChars = 5;

/// Text lines in the kit, kept separate so tests can check it never carries anything user-specific.
const kitSteps = [
  'Forgot your password? On the LedgerLock lock screen, tap "Forgot password?".',
  'Choose "Enter recovery key" and type the 30 characters you wrote above.',
  'Set a new password. Your records stay exactly as they were.',
];

const kitWarnings = [
  'Anyone holding this key can open your records. Keep it with your tax papers, not in your wallet.',
  'Do not photograph it, email it, or store it in a notes app or cloud drive.',
  'If you make a new recovery key in Settings, this one stops working: write the new one on a fresh kit.',
  'LedgerLock has no servers and no accounts. Nobody, including the makers, can reset this for you.',
];

Future<Uint8List> buildEmergencyKit() async {
  final doc = pw.Document(title: 'LedgerLock Emergency Kit', creator: 'LedgerLock', producer: 'LedgerLock');
  pw.Widget box() => pw.Container(
    width: 22,
    height: 28,
    margin: const pw.EdgeInsets.only(right: 3),
    decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.8)),
  );
  pw.Widget bullets(List<String> lines) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      for (final (i, l) in lines.indexed)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(width: 18, child: pw.Text('${i + 1}.')),
              pw.Expanded(child: pw.Text(l, style: const pw.TextStyle(fontSize: 11))),
            ],
          ),
        ),
    ],
  );

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.all(54),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('LedgerLock Emergency Kit', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text('Print this page, then write your recovery key in the boxes by hand.'),
          pw.SizedBox(height: 24),
          pw.Text('Recovery key', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          for (var row = 0; row < 2; row++) ...[
            pw.Row(
              children: [
                for (var g = 0; g < kitGroups ~/ 2; g++) ...[
                  for (var c = 0; c < kitGroupChars; c++) box(),
                  if (g < kitGroups ~/ 2 - 1)
                    pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6), child: pw.Text('-')),
                ],
              ],
            ),
            pw.SizedBox(height: 10),
          ],
          pw.Text('Date written: ____________________', style: const pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 28),
          pw.Text('How to use it', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          bullets(kitSteps),
          pw.SizedBox(height: 20),
          pw.Text('Keep it safe', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          bullets(kitWarnings),
          pw.Spacer(),
          pw.Text(
            'This sheet holds no key until you write one. A lost phone needs a backup file as well; the key alone '
            'cannot bring back data from a wiped phone.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    ),
  );
  return doc.save();
}
