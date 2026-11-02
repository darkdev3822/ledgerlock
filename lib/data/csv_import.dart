// Bank and platform CSV import (SPEC §3). Pure Dart, no packages. The file is read into memory from the
// system picker and parsed here; nothing is copied to app storage. Column layouts are detected from header names
// (no hard-coded per-bank formats that silently break) and the user's mapping is saved per header signature.
import 'dart:convert';

import 'database.dart';

const maxImportBytes = 5 * 1024 * 1024;
const maxImportRows = 20000;
const maxCellChars = 500;

class ImportTooLarge implements Exception {
  final String why;
  const ImportTooLarge(this.why);
  @override
  String toString() => why;
}

/// RFC 4180 parser: quotes, doubled quotes, CR/LF/CRLF, UTF-8 BOM. Skips blank lines. Caps size and rows.
List<List<String>> parseCsv(List<int> bytes) {
  if (bytes.length > maxImportBytes) throw const ImportTooLarge('File is over 5 MB');
  var text = utf8.decode(bytes, allowMalformed: true);
  if (text.startsWith('﻿')) text = text.substring(1);
  final delim = _sniffDelimiter(text);
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  void endCell() {
    var v = cell.toString();
    v = safeTake(v, maxCellChars);
    row.add(v);
    cell.clear();
  }

  void endRow() {
    endCell();
    if (row.any((c) => c.trim().isNotEmpty)) {
      if (rows.length >= maxImportRows + 1) throw const ImportTooLarge('More than 20,000 rows');
      rows.add(row);
    }
    row = <String>[];
  }

  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (quoted) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        cell.write(ch);
      }
    } else if (ch == '"' && cell.isEmpty) {
      quoted = true;
    } else if (ch == delim) {
      endCell();
    } else if (ch == '\r' || ch == '\n') {
      if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      endRow();
    } else {
      cell.write(ch);
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) endRow();
  return rows;
}

String _sniffDelimiter(String text) {
  final first = text.split(RegExp(r'\r?\n')).firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
  final counts = {
    for (final d in [',', ';', '\t']) d: d.allMatches(first).length,
  };
  return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
}

/// Which column holds what. -1 = not present.
class ColumnMap {
  final int date, amount, debit, credit, payee, fee, notes;

  /// Optional column saying Income/Expense (or Credit/Debit). When it is recognised it decides the sign (F3:
  /// LedgerLock's own export has positive amounts plus a Type column).
  final int kind;

  /// Bank style: negative = money out (expense). If true, positive amounts are expenses instead.
  final bool flipSign;
  const ColumnMap({
    this.date = -1,
    this.amount = -1,
    this.debit = -1,
    this.credit = -1,
    this.payee = -1,
    this.fee = -1,
    this.notes = -1,
    this.kind = -1,
    this.flipSign = false,
  });

  bool get usable => date >= 0 && payee >= 0 && (amount >= 0 || debit >= 0 || credit >= 0);

  ColumnMap copyWith({
    int? date,
    int? amount,
    int? debit,
    int? credit,
    int? payee,
    int? fee,
    int? notes,
    int? kind,
    bool? flipSign,
  }) => ColumnMap(
    date: date ?? this.date,
    amount: amount ?? this.amount,
    debit: debit ?? this.debit,
    credit: credit ?? this.credit,
    payee: payee ?? this.payee,
    fee: fee ?? this.fee,
    notes: notes ?? this.notes,
    kind: kind ?? this.kind,
    flipSign: flipSign ?? this.flipSign,
  );

  Map<String, Object> toJson() => {
    'date': date,
    'amount': amount,
    'debit': debit,
    'credit': credit,
    'payee': payee,
    'fee': fee,
    'notes': notes,
    'kind': kind,
    'flip': flipSign,
  };

  static ColumnMap? fromJson(Object? j) {
    if (j is! Map) return null;
    int g(String k) => j[k] is int ? j[k] as int : -1;
    return ColumnMap(
      date: g('date'),
      amount: g('amount'),
      debit: g('debit'),
      credit: g('credit'),
      payee: g('payee'),
      fee: g('fee'),
      notes: g('notes'),
      kind: g('kind'),
      flipSign: j['flip'] == true,
    );
  }
}

/// Settings key for a saved mapping: depends only on the (normalised) header names, never on the data.
String headerSignature(List<String> header) =>
    'import_map:${header.map((h) => h.trim().toLowerCase()).join('|').hashCode.toRadixString(36)}';

/// Guess columns from header names. Earlier words in each list win.
ColumnMap guessColumns(List<String> header) {
  final h = [for (final x in header) x.trim().toLowerCase()];
  int find(List<String> words, {Set<int> skip = const {}}) {
    for (final w in words) {
      for (var i = 0; i < h.length; i++) {
        if (!skip.contains(i) && h[i].contains(w)) return i;
      }
    }
    return -1;
  }

  final date = find(['transaction date', 'posting date', 'posted date', 'date', 'created']);
  final fee = find(['fee', 'commission']);
  final debit = find(['debit', 'withdrawal', 'money out', 'paid out']);
  final credit = find(['credit', 'deposit', 'money in', 'paid in']);
  final amount = find(['gross', 'amount', 'total', 'earning', 'net'], skip: {fee, debit, credit});
  final payee = find(
    ['payee', 'merchant', 'name', 'description', 'buyer', 'customer', 'counterparty', 'memo', 'details'],
    skip: {date, amount, fee},
  );
  final kind = find(['type', 'kind', 'direction'], skip: {date, amount, fee, payee});
  final notes = find(['memo', 'note', 'item title', 'item', 'reference'], skip: {date, amount, fee, payee, kind});
  return ColumnMap(
    kind: kind,
    date: date,
    amount: amount,
    debit: amount >= 0 ? -1 : debit,
    credit: amount >= 0 ? -1 : credit,
    payee: payee,
    fee: fee,
    notes: notes,
  );
}

const _months = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6, //
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};

/// Dates as US banks and platforms write them. Numeric dates are month-first (US). Returns null if unsure.
DateTime? parseImportDate(String raw) {
  final s = raw.trim();
  DateTime? ok(int y, int m, int d) {
    if (y < 100) y += 2000;
    if (m < 1 || m > 12 || d < 1 || d > 31 || y < 1990 || y > 2100) return null;
    final dt = DateTime(y, m, d);
    return dt.month == m ? dt : null; // rejects Feb 30
  }

  var m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(s);
  if (m != null) return ok(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  m = RegExp(r'^(\d{1,2})[/.-](\d{1,2})[/.-](\d{2,4})\b').firstMatch(s);
  if (m != null) return ok(int.parse(m[3]!), int.parse(m[1]!), int.parse(m[2]!));
  m = RegExp(r'^([A-Za-z]{3})[a-z]*\.? (\d{1,2}),? (\d{4})').firstMatch(s); // Jan 5, 2026
  if (m != null && _months[m[1]!.toLowerCase()] != null) {
    return ok(int.parse(m[3]!), _months[m[1]!.toLowerCase()]!, int.parse(m[2]!));
  }
  m = RegExp(r'^(\d{1,2})[ -]([A-Za-z]{3})[a-z]*[ -](\d{2,4})').firstMatch(s); // 5 Jan 2026, 05-Jan-26
  if (m != null && _months[m[2]!.toLowerCase()] != null) {
    return ok(int.parse(m[3]!), _months[m[2]!.toLowerCase()]!, int.parse(m[1]!));
  }
  return null;
}

/// "$1,234.56", "-12.00", "(12.00)", "12.00 USD", "1 234.50" -> signed cents; null if not money.
int? parseImportAmount(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;
  var neg = false;
  if (s.startsWith('(') && s.endsWith(')')) {
    neg = true;
    s = s.substring(1, s.length - 1);
  }
  // Currency symbols/codes only at the ends; letters in the middle make it not-a-number ("1e3", "INV 42": F2).
  s = s.replaceAll(RegExp(r'^\s*(?:USD|EUR|GBP|CAD|AUD|[$€£])\s*|\s*(?:USD|EUR|GBP|CAD|AUD|[$€£])\s*$'), '');
  s = s.replaceAll(RegExp(r'^[$€£]|[$€£]$'), '').replaceAll(RegExp(r'\s'), '');
  if (RegExp(r'[A-Za-z]').hasMatch(s)) return null;
  // Separators (F1): "5,00" / "1.234,56" are decimal-comma; "1,234.56" / "1,234" are thousands-comma.
  final decimalComma = RegExp(r',\d{1,2}-?$').hasMatch(s) && (!s.contains('.') || s.lastIndexOf('.') < s.indexOf(','));
  if (decimalComma) {
    s = s.replaceAll('.', '').replaceAll(',', '.');
  } else {
    final intPart = s.split('.').first.replaceAll(RegExp(r'^[-+]|-$'), '');
    if (intPart.contains(',') && !RegExp(r'^\d{1,3}(,\d{3})+$').hasMatch(intPart)) return null;
    s = s.replaceAll(',', '');
  }
  if (s.startsWith('-')) {
    neg = !neg;
    s = s.substring(1);
  } else if (s.startsWith('+')) {
    s = s.substring(1);
  } else if (s.endsWith('-')) {
    neg = !neg;
    s = s.substring(0, s.length - 1);
  }
  if (!RegExp(r'^\d{1,9}(\.\d{1,2})?$').hasMatch(s)) return null;
  final parts = s.split('.');
  final cents = int.parse(parts[0]) * 100 + (parts.length > 1 ? int.parse(parts[1].padRight(2, '0')) : 0);
  return neg ? -cents : cents;
}

class ImportRow {
  final int line; // 1-based line in the file, for error messages
  final DateTime date;
  final bool isIncome;
  final int amountCents; // positive
  final int feeCents; // positive, income only
  final String payee, notes;

  /// Looks like something already recorded (or repeated earlier in this file). Unticked by default.
  final bool duplicate;
  const ImportRow({
    required this.line,
    required this.date,
    required this.isIncome,
    required this.amountCents,
    this.feeCents = 0,
    required this.payee,
    this.notes = '',
    this.duplicate = false,
  });
}

class ImportResult {
  final List<ImportRow> rows;
  final List<int> skippedLines; // unreadable date/amount, or zero
  const ImportResult(this.rows, this.skippedLines);
}

/// Undo our own CSV export's formula guard (a leading apostrophe before = + - @ tab CR), F4.
String _unguard(String v) => v.length > 1 && v[0] == "'" && '=+-@\t\r'.contains(v[1]) ? v.substring(1) : v;

String _dupKey(String isoDate, bool income, int cents, String payee) =>
    '$isoDate|${income ? 1 : 0}|$cents|${payee.trim().toLowerCase()}';

/// Turn data rows (header excluded) into import rows. [existing]: entries already in the books, for duplicates.
ImportResult buildImport(List<List<String>> data, ColumnMap map, {Iterable<LedgerEntry> existing = const []}) {
  String at(List<String> r, int i) => i >= 0 && i < r.length ? r[i].trim() : '';
  final seen = {for (final e in existing) _dupKey(e.date, e.isIncome, e.amountCents, e.party)};
  final out = <ImportRow>[];
  final skipped = <int>[];
  for (final (i, r) in data.indexed) {
    final line = i + 2;
    final date = parseImportDate(at(r, map.date));
    int? signed;
    if (map.amount >= 0) {
      signed = parseImportAmount(at(r, map.amount));
    } else {
      final d = parseImportAmount(at(r, map.debit)), c = parseImportAmount(at(r, map.credit));
      if (d != null && d != 0) {
        signed = -d.abs();
      } else if (c != null) {
        signed = c.abs();
      }
    }
    if (date == null || signed == null || signed == 0) {
      skipped.add(line);
      continue;
    }
    final k = at(r, map.kind).toLowerCase();
    final dir = RegExp(r'^(income|credit|deposit|money in)').hasMatch(k)
        ? 1
        : RegExp(r'^(expense|debit|withdrawal|purchase|money out)').hasMatch(k)
        ? -1
        : 0;
    if (dir != 0) {
      signed = dir * signed.abs();
    } else if (map.flipSign) {
      signed = -signed;
    }
    final income = signed > 0;
    final cents = signed.abs();
    final payee = at(r, map.payee);
    final fee = income ? (parseImportAmount(at(r, map.fee))?.abs() ?? 0).clamp(0, cents) : 0;
    final key = _dupKey(isoDay(date), income, cents, payee);
    out.add(
      ImportRow(
        line: line,
        date: date,
        isIncome: income,
        amountCents: cents,
        feeCents: fee,
        payee: _unguard(safeTake(payee, 80)),
        notes: _unguard(at(r, map.notes)),
        duplicate: !seen.add(key),
      ),
    );
  }
  return ImportResult(out, skipped);
}
