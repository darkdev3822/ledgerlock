// Turns OCR text from a receipt into suggested fields (SPEC §3: merchant, date, total, tax). Pure and
// conservative: anything unsure is left null for the user to fill. Suggestions are always shown for review.
import '../data/csv_import.dart' show parseImportDate;

class ReceiptGuess {
  final String? merchant;
  final DateTime? date;
  final int? totalCents, taxCents;
  const ReceiptGuess({this.merchant, this.date, this.totalCents, this.taxCents});
  bool get isEmpty => merchant == null && date == null && totalCents == null;
}

final _money = RegExp(r'(?<![\d.,])\$?\s?(\d{1,3}(?:,\d{3})+|\d{1,6})[.,](\d{2})(?![\d])');
final _dateish = RegExp(
  r'(\d{4}-\d{1,2}-\d{1,2})|(\d{1,2}[/.-]\d{1,2}[/.-]\d{2,4})|([A-Za-z]{3,9}\.? \d{1,2},? \d{4})|(\d{1,2} [A-Za-z]{3,9} \d{4})',
);
final _grand = RegExp(
  r'\b(grand total|total due|amount due|balance due|total amount|amount paid)\b',
  caseSensitive: false,
);
final _total = RegExp(r'\btotal\b', caseSensitive: false);
final _notTotal = RegExp(r'sub\s?-?total|total (savings|saved|items|qty|discount)|items? total', caseSensitive: false);
final _tax = RegExp(r'\b(sales )?tax\b', caseSensitive: false);
final _notTax = RegExp(r'tax ?id|pre-?tax|taxable|tax ?exempt|incl', caseSensitive: false);
final _tender = RegExp(r'\b(cash|tender(ed)?|change|chg)\b', caseSensitive: false);
final _junkTop = RegExp(
  r'receipt|welcome|thank|store ?#|tel|phone|www\.|\.com|invoice|order|cashier|register|^\W*$',
  caseSensitive: false,
);

/// Cents of the last money value on [line], or null.
int? _lastMoney(String line) {
  final ms = _money.allMatches(line).toList();
  if (ms.isEmpty) return null;
  final m = ms.last;
  return int.parse(m[1]!.replaceAll(',', '')) * 100 + int.parse(m[2]!);
}

String _titleCase(String s) {
  final letters = s.replaceAll(RegExp(r'[^A-Za-z]'), '');
  if (letters.isEmpty || letters != letters.toUpperCase()) return s;
  return s.toLowerCase().split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');
}

ReceiptGuess parseReceipt(String text, {required DateTime today}) {
  final lines = [
    for (final l in text.split(RegExp(r'\r?\n')))
      if (l.trim().isNotEmpty)
        l
            .trim()
            .replaceAll(RegExp(r'\s{2,}'), ' ')
            // Noisy paper: OCR often reads the decimal point as ':' or ';' ("38: 76" -> "38.76"). Times like
            // "15:44" have no space after the colon and are left alone.
            .replaceAllMapped(
              RegExp(r'(\d)\s?[;:]\s(\d{2})\b|(\d)[;](\d{2})\b'),
              (m) => '${m[1] ?? m[3]}.${m[2] ?? m[4]}',
            ),
  ];
  if (lines.isEmpty) return const ReceiptGuess();

  // Merchant: first line near the top with real words that isn't boilerplate, an address/phone, or a date.
  String? merchant;
  for (final l in lines.take(6)) {
    final letters = l.replaceAll(RegExp(r'[^A-Za-z]'), '').length;
    final digits = l.replaceAll(RegExp(r'\D'), '').length;
    if (letters < 3 || digits > letters || _junkTop.hasMatch(l) || _dateish.hasMatch(l) || _money.hasMatch(l)) {
      continue;
    }
    merchant = _titleCase(l.replaceAll(RegExp(r'[^A-Za-z0-9&\x27.\- ]'), '').trim());
    if (merchant.length > 40) merchant = merchant.substring(0, 40).trim();
    break;
  }

  // Date: first plausible date (not in the future, not older than two years).
  DateTime? date;
  final d0 = DateTime(today.year, today.month, today.day);
  for (final l in lines) {
    for (final m in _dateish.allMatches(l)) {
      final d = parseImportDate(m[0]!);
      if (d != null && !d.isAfter(d0.add(const Duration(days: 1))) && d0.difference(d).inDays <= 730) {
        date = d;
        break;
      }
    }
    if (date != null) break;
  }

  // Total: strongest label wins ("amount due" > "total"); never subtotal/savings. Fallback: the largest amount
  // not on a cash/tender/change line (cash handed over can exceed the total).
  int? total;
  for (final strong in [true, false]) {
    for (final l in lines.reversed) {
      final hit = strong ? _grand.hasMatch(l) : _total.hasMatch(l) && !_notTotal.hasMatch(l);
      if (!hit || _tender.hasMatch(l)) continue;
      final v = _lastMoney(l);
      if (v != null && v > 0) {
        total = v;
        break;
      }
    }
    if (total != null) break;
  }
  total ??= [
    for (final l in lines)
      if (!_tender.hasMatch(l)) ?_lastMoney(l),
  ].fold<int?>(null, (a, v) => a == null || v > a ? v : a);

  int? tax;
  for (final l in lines) {
    if (_tax.hasMatch(l) && !_notTax.hasMatch(l)) {
      final v = _lastMoney(l);
      if (v != null && (total == null || v < total)) {
        tax = v;
        break;
      }
    }
  }

  return ReceiptGuess(merchant: merchant, date: date, totalCents: total, taxCents: tax);
}
