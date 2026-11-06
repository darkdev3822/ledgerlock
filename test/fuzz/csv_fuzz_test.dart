// Fuzz: CSV import parser, column guessing, date/amount parsing, buildImport, ColumnMap.fromJson,
// and CSV export (formula guard for ANY string, round trip through parseCsv).
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerlock/data/csv_export.dart';
import 'package:ledgerlock/data/csv_import.dart';
import 'package:ledgerlock/data/database.dart';
import 'package:ledgerlock/data/tax_rules.dart';

import 'fuzz_util.dart';

void main() {
  test('parseCsv: random bytes never crash/hang; cells capped; no blank rows', () {
    final r = Random(1);
    const alphabet = [0x22, 0x2C, 0x3B, 0x09, 0x0D, 0x0A, 0x61, 0x20, 0xC3, 0xA9, 0xFF, 0xEF, 0xBB, 0xBF, 0x80];
    for (var it = 0; it < 4000; it++) {
      final len = r.nextInt(it % 100 == 0 ? 20000 : 300);
      final bytes = [
        for (var i = 0; i < len; i++) r.nextInt(3) == 0 ? r.nextInt(256) : alphabet[r.nextInt(alphabet.length)],
      ];
      final rows = timed(() => parseCsv(bytes), input: bytes);
      for (final row in rows) {
        expect(row.any((c) => c.trim().isNotEmpty), isTrue);
        for (final c in row) {
          expect(c.length, lessThanOrEqualTo(maxCellChars));
        }
      }
    }
  });

  test('parseCsv: worst-case shapes are linear (one giant quoted cell, all delimiters, all newlines)', () {
    for (final s in ['"${'x' * 4000000}', ',' * 4000000, '\n' * 4000000, '"",' * 1000000, 'a;' * 2000000]) {
      timed(() => parseCsv(utf8.encode(s)), limitMs: 2000, input: s);
    }
  });

  test('guessColumns: indices in range, distinct roles never share a column, fromJson tolerant', () {
    final r = Random(2);
    const words = [
      'date',
      'Posting Date',
      'amount',
      'gross',
      'fee',
      'debit',
      'credit',
      'payee',
      'name',
      'memo',
      'notes',
      'type',
      'total',
      'net',
      'description',
      'item',
      '',
    ];
    final collisions = <String>[];
    for (var it = 0; it < 5000; it++) {
      final h = [
        for (var i = 0; i < r.nextInt(8); i++)
          r.nextBool() ? words[r.nextInt(words.length)] : fuzzString(r, maxPieces: 3),
      ];
      final m = timed(() => guessColumns(h), input: h);
      for (final v in [m.date, m.amount, m.debit, m.credit, m.payee, m.fee, m.notes]) {
        expect(v >= -1 && v < h.length, isTrue, reason: '$h');
      }
      final used = [m.date, m.amount, m.debit, m.credit, m.payee, m.fee, m.notes].where((v) => v >= 0).toList();
      if (used.toSet().length != used.length) collisions.add('$h -> ${m.toJson()}');
      final back = ColumnMap.fromJson(jsonDecode(jsonEncode(m.toJson())));
      expect(back!.toJson(), m.toJson());
      // Garbage JSON never throws.
      ColumnMap.fromJson(r.nextBool() ? {'date': fuzzString(r), 'flip': 1, 'amount': 2.5} : fuzzString(r));
    }
    expect(collisions, isEmpty);
  });

  test('parseImportDate: never throws; anything returned is a real date in 1990..2100', () {
    final r = Random(3);
    for (var it = 0; it < 20000; it++) {
      final s = r.nextBool()
          ? '${r.nextInt(40)}${['/', '-', '.', ' '][r.nextInt(4)]}${r.nextInt(40)}${['/', '-', '.'][r.nextInt(3)]}${r.nextInt(3000)}'
          : fuzzString(r, maxPieces: 6);
      final d = timed(() => parseImportDate(s), input: s);
      if (d != null) {
        expect(d.year, inInclusiveRange(1990, 2100), reason: s);
        expect(d.hour, 0);
      }
    }
    // Leap days.
    expect(parseImportDate('02/29/2028'), DateTime(2028, 2, 29));
    expect(parseImportDate('02/29/2027'), isNull);
    expect(parseImportDate('2100-02-29'), isNull);
  });

  test('parseImportAmount: exact round trip of formatted cents; never throws; bounded', () {
    final r = Random(4);
    for (var it = 0; it < 20000; it++) {
      final cents = r.nextInt(1 << 32) * (r.nextBool() ? 1 : -1) % 100000000000;
      final abs = cents.abs();
      final dollars = '${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}';
      final withCommas = (abs ~/ 100).toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
      final forms = [
        cents < 0 ? '-$dollars' : dollars,
        cents < 0
            ? '(\$$withCommas.${(abs % 100).toString().padLeft(2, '0')})'
            : '\$$withCommas.${(abs % 100).toString().padLeft(2, '0')}',
        cents < 0 ? '$dollars-' : '+$dollars',
      ];
      for (final f in forms) {
        expect(parseImportAmount(f), cents, reason: f);
      }
      final junk = fuzzString(r, maxPieces: 6);
      final v = timed(() => parseImportAmount(junk), input: junk);
      if (v != null) expect(v.abs(), lessThan(100000000000));
    }
  });

  test('buildImport: random rows/maps never crash; outputs positive cents, fee <= amount, payee <= 80', () {
    final r = Random(5);
    for (var it = 0; it < 3000; it++) {
      final cols = 1 + r.nextInt(6);
      final data = [
        for (var i = 0; i < r.nextInt(10); i++)
          [
            for (var c = 0; c < r.nextInt(cols + 2); c++)
              r.nextInt(3) == 0
                  ? '${r.nextInt(20000) - 10000}.${r.nextInt(100)}'
                  : r.nextInt(3) == 0
                  ? '0${1 + r.nextInt(12)}/0${1 + r.nextInt(9)}/2026'
                  : fuzzString(r, maxPieces: 4),
          ],
      ];
      int pick() => r.nextInt(cols + 2) - 1;
      final map = ColumnMap(
        date: pick(),
        amount: pick(),
        debit: pick(),
        credit: pick(),
        payee: pick(),
        fee: pick(),
        notes: pick(),
        flipSign: r.nextBool(),
      );
      final res = timed(() => buildImport(data, map), input: data);
      expect(res.rows.length + res.skippedLines.length, data.length);
      for (final row in res.rows) {
        expect(row.amountCents, greaterThan(0));
        expect(row.feeCents, inInclusiveRange(0, row.amountCents));
        expect(row.payee.length, lessThanOrEqualTo(80));
        if (!row.isIncome) expect(row.feeCents, 0);
      }
    }
  });

  // ---------- export ----------

  bool dangerous(String cell) => cell.isNotEmpty && '=+-@\t\r'.contains(cell[0]) && num.tryParse(cell) == null;

  test('csvCell: no string ever yields a formula-leading cell; round trip through parseCsv keeps text', () {
    final r = Random(6);
    for (var it = 0; it < 20000; it++) {
      final s = fuzzString(r, maxPieces: 8).replaceAll('﻿', '');
      final cell = timed(() => csvCell(s), input: s);
      final parsed = parseCsv(utf8.encode('h,x\r\n$cell,1\r\n'));
      expect(parsed.length, 2, reason: 'cell ${jsonEncode(cell)}');
      final back = parsed[1][0];
      expect(dangerous(back), isFalse, reason: jsonEncode(s));
      final expected = dangerous(s) ? "'$s" : s;
      expect(back, expected, reason: 'round trip of ${jsonEncode(s)}');
    }
  });

  test('entriesCsv: every exported row re-parses to the same number of columns', () {
    final r = Random(7);
    const rules = TaxRules(year: 2026, quarterlyDue: []);
    final entries = [
      for (var i = 0; i < 300; i++)
        LedgerEntry(
          id: i,
          isIncome: r.nextBool(),
          date: '2026-01-01',
          amountCents: r.nextInt(1 << 31),
          feeCents: r.nextInt(1000),
          businessPct: r.nextInt(101),
          category: fuzzString(r, maxPieces: 2),
          party: fuzzString(r),
          platform: fuzzString(r, maxPieces: 2),
          notes: fuzzString(r),
          paid: r.nextBool(),
          tags: '', createdAt: DateTime(2026),
        ),
    ];
    final csv = timed(() => entriesCsv(entries, rules), limitMs: 500);
    final rows = parseCsv(csvBytes(csv));
    expect(rows.length, entries.length + 1);
    for (final row in rows) {
      expect(row.length, 12);
      for (final c in row) {
        expect(dangerous(c), isFalse, reason: c);
      }
    }
  });

  // ---------- findings (minimal repros, skipped so the suite stays green) ----------

  test('F1 decimal-comma amounts are read 100x too large', () {
    // A semicolon CSV (European export, which the parser explicitly supports) writes 5,00 for five units.
    final rows = parseCsv(utf8.encode('Date;Description;Amount\n01/02/2026;Coffee;-5,00\n'));
    final res = buildImport(rows.skip(1).toList(), guessColumns(rows.first));
    expect(res.rows.single.amountCents, anyOf(500, isNull), reason: 'got ${res.rows.single.amountCents}');
  });

  test('F2 letters inside an amount are silently deleted (1e3 -> 13.00, INV 42 -> 42.00)', () {
    expect(parseImportAmount('1e3'), isNull);
    expect(parseImportAmount('INV 42'), isNull);
    expect(parseImportAmount('12abc34'), isNull);
  });

  LedgerEntry entry(bool income, String party) => LedgerEntry(
    id: 1,
    isIncome: income,
    date: '2026-03-04',
    amountCents: 1234,
    feeCents: 0,
    businessPct: 100,
    category: 'supplies',
    party: party,
    platform: '',
    notes: '',
    paid: true,
    tags: '', createdAt: DateTime(2026),
  );

  test('F3 re-importing LedgerLock\'s own CSV export turns every expense into income', () {
    final csv = entriesCsv([entry(false, 'Staples')], const TaxRules(year: 2026, quarterlyDue: []));
    final rows = parseCsv(csvBytes(csv));
    final res = buildImport(rows.skip(1).toList(), guessColumns(rows.first));
    expect(res.rows.single.isIncome, isFalse);
  });

  test('F4 formula guard apostrophe survives an export -> import round trip (payee grows a leading \')', () {
    final csv = entriesCsv([entry(true, '=cmd')], const TaxRules(year: 2026, quarterlyDue: []));
    final rows = parseCsv(csvBytes(csv));
    final res = buildImport(rows.skip(1).toList(), guessColumns(rows.first));
    expect(res.rows.single.payee, '=cmd');
  });
}
