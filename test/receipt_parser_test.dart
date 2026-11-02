import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerlock/media/receipt_parser.dart';

final _today = DateTime(2026, 11, 1);

void main() {
  test('typical store receipt: merchant, date, total (not subtotal), tax', () {
    const text = '''
STAPLES
Store #0042
123 Main St, Springfield
Tel 555-201-3344
10/28/2026 14:02
PAPER REAM          8.99
INK CARTRIDGE      24.99
SUBTOTAL           33.98
SALES TAX 6.25%     2.12
TOTAL              36.10
VISA ****1234      36.10
THANK YOU''';
    final g = parseReceipt(text, today: _today);
    expect(g.merchant, 'Staples');
    expect(g.date, DateTime(2026, 10, 28));
    expect(g.totalCents, 3610);
    expect(g.taxCents, 212);
  });

  test('cash receipt: tendered and change are not the total', () {
    const text = '''
Corner Cafe
Oct 30, 2026
Latte 4.50
Muffin 3.25
Total 7.75
Cash 20.00
Change 12.25''';
    final g = parseReceipt(text, today: _today);
    expect(g.merchant, 'Corner Cafe');
    expect(g.date, DateTime(2026, 10, 30));
    expect(g.totalCents, 775);
    expect(g.taxCents, isNull);
  });

  test('"amount due" beats a plain total line; thousands separators', () {
    const text = '''
ACME PRINT CO.
Invoice 5531
2026-10-02
Total before discount 1,250.00
Discount 50.00
Amount Due \$1,200.00''';
    final g = parseReceipt(text, today: _today);
    expect(g.merchant, 'Acme Print Co.');
    expect(g.totalCents, 120000);
  });

  test('no labels: largest non-cash amount; future and ancient dates ignored', () {
    const text = '''
Hardware Hub
12/25/2030
01/01/2019
Hammer 15.00
Nails 4.20''';
    final g = parseReceipt(text, today: _today);
    expect(g.totalCents, 1500);
    expect(g.date, isNull);
  });

  test('garbage in, nothing out', () {
    expect(parseReceipt('', today: _today).isEmpty, isTrue);
    expect(parseReceipt('~~~ ## 12\n||', today: _today).totalCents, isNull);
  });

  test('noisy OCR: "38: 76" and "12; 49" read as amounts; a time like 15:44 is left alone', () {
    const text = '''
OFFICE DEPOT
10/27/2026 15:44
PRINTER PAPER 12; 49
TOTAL 38: 76''';
    final g = parseReceipt(text, today: _today);
    expect(g.totalCents, 3876);
    expect(g.date, DateTime(2026, 10, 27));
  });
}
