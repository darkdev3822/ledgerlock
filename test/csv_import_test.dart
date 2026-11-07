import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerlock/data/csv_import.dart';
import 'package:ledgerlock/data/database.dart';

List<int> b(String s) => utf8.encode(s);

void main() {
  test('parser: quotes, doubled quotes, CRLF, BOM, blank lines, semicolons', () {
    final rows = parseCsv([0xEF, 0xBB, 0xBF, ...b('a,b\r\n"x, y","say ""hi"""\r\n\r\n"multi\nline",2\n')]);
    expect(rows, [
      ['a', 'b'],
      ['x, y', 'say "hi"'],
      ['multi\nline', '2'],
    ]);
    expect(parseCsv(b('Date;Amount\n01/02/2026;5,00')).first, ['Date', 'Amount']);
  });

  test('hostile files are capped (SECURITY.md T15)', () {
    expect(() => parseCsv(List.filled(maxImportBytes + 1, 0x61)), throwsA(isA<ImportTooLarge>()));
    expect(() => parseCsv(b('a\n' * (maxImportRows + 5))), throwsA(isA<ImportTooLarge>()));
    final long = parseCsv(b('${'x' * 5000},1'));
    expect(long.first.first.length, maxCellChars);
    expect(parseCsv(b('"unterminated, quote\n1,2')).length, 1, reason: 'no crash on a broken quote');
  });

  test('dates: ISO, US numeric, month names; nonsense rejected', () {
    expect(parseImportDate('2026-03-04'), DateTime(2026, 3, 4));
    expect(parseImportDate('3/4/2026'), DateTime(2026, 3, 4));
    expect(parseImportDate('03/04/26'), DateTime(2026, 3, 4));
    expect(parseImportDate('2026-03-04T10:00:00Z'), DateTime(2026, 3, 4));
    expect(parseImportDate('Mar 4, 2026'), DateTime(2026, 3, 4));
    expect(parseImportDate('4 Mar 2026'), DateTime(2026, 3, 4));
    expect(parseImportDate('04-Mar-26'), DateTime(2026, 3, 4));
    expect(parseImportDate('2/30/2026'), isNull);
    expect(parseImportDate('13/01/2026'), isNull);
    expect(parseImportDate('pending'), isNull);
  });

  test('amounts: symbols, commas, parentheses, trailing minus', () {
    expect(parseImportAmount(r'$1,234.56'), 123456);
    expect(parseImportAmount('-12.5'), -1250);
    expect(parseImportAmount('(12.00)'), -1200);
    expect(parseImportAmount('12.00 USD'), 1200);
    expect(parseImportAmount('12.00-'), -1200);
    expect(parseImportAmount('+7'), 700);
    expect(parseImportAmount('=1+1'), isNull);
    expect(parseImportAmount('1.234'), isNull);
    expect(parseImportAmount(''), isNull);
  });

  test('column guess: bank (amount) and debit/credit layouts', () {
    final bank = guessColumns(['Posting Date', 'Description', 'Amount', 'Type', 'Balance']);
    expect([bank.date, bank.payee, bank.amount, bank.kind, bank.notes], [0, 1, 2, 3, -1]);
    expect(bank.usable, isTrue);
    final dc = guessColumns(['Date', 'Payee', 'Debit', 'Credit']);
    expect([dc.amount, dc.debit, dc.credit, dc.payee], [-1, 2, 3, 1]);
    final platform = guessColumns(['Date', 'Buyer', 'Gross', 'Fee', 'Net']);
    expect([platform.amount, platform.fee], [2, 3], reason: 'gross, not net, when fees are separate');
    expect(guessColumns(['foo', 'bar']).usable, isFalse);
    expect(headerSignature([' Date ', 'AMOUNT']), headerSignature(['date', 'amount']));
    final m = ColumnMap.fromJson(jsonDecode(jsonEncode(dc.copyWith(flipSign: true).toJson())))!;
    expect([m.debit, m.credit, m.flipSign], [2, 3, true]);
  });

  test('build: sign -> kind, fees on income only, skips bad lines, flags duplicates', () {
    const map = ColumnMap(date: 0, payee: 1, amount: 2, fee: 3);
    final existing = LedgerEntry(
      businessId: 1,
      id: 1,
      isIncome: false,
      date: '2026-01-05',
      amountCents: 1999,
      feeCents: 0,
      businessPct: 100,
      category: 'software',
      party: 'Adobe',
      platform: '',
      notes: '',
      paid: true,
      tags: '',
      createdAt: DateTime(2026),
    );
    final r = buildImport(
      [
        ['01/05/2026', 'ADOBE', '-19.99', ''],
        ['01/06/2026', 'Client A', '500.00', '15.00'],
        ['01/06/2026', 'Client A', '500.00', '15.00'],
        ['soon', 'X', '1', ''],
        ['01/07/2026', 'Zero', '0.00', ''],
        ['01/08/2026', 'Cafe', '-8.00', '3.00'],
      ],
      map,
      existing: [existing],
    );
    expect(r.skippedLines, [5, 6]);
    expect(r.rows.map((x) => x.duplicate), [true, false, true, false]);
    expect(r.rows[1].isIncome, isTrue);
    expect(r.rows[1].feeCents, 1500);
    expect(r.rows[3].feeCents, 0, reason: 'fees only apply to income');
    expect(r.rows[3].amountCents, 800);
    final flipped = buildImport([
      ['2026-01-01', 'Shop', '25.00', ''],
    ], map.copyWith(flipSign: true));
    expect(flipped.rows.single.isIncome, isFalse);
    final dc = buildImport([
      ['2026-01-01', 'Shop', '25.00', ''],
      ['2026-01-02', 'Client', '', '90'],
    ], const ColumnMap(date: 0, payee: 1, debit: 2, credit: 3));
    expect(dc.rows.map((x) => (x.isIncome, x.amountCents)), [(false, 2500), (true, 9000)]);
  });
}
