import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerlock/data/csv_export.dart';
import 'package:ledgerlock/data/database.dart';
import 'package:ledgerlock/data/tax_rules.dart';

void main() {
  test('CSV injection is neutralised (SECURITY.md T11)', () {
    for (final evil in ['=HYPERLINK("http://x","y")', '+1+1', '@SUM(A1)', '-2+3', '\t=1']) {
      expect(csvCell(evil).replaceAll('"', '').startsWith("'"), isTrue, reason: evil);
    }
    expect(csvCell('-12.50'), '-12.50', reason: 'plain numbers stay numbers');
    expect(csvCell('Cafe, Uno'), '"Cafe, Uno"');
    expect(csvCell('say "hi"'), '"say ""hi"""');
    expect(csvCell('line1\nline2'), '"line1\nline2"');
  });

  test('entries CSV: header, money, line, received', () {
    const rules = TaxRules(
      year: 2026,
      quarterlyDue: [],
      incomeCategories: [Category(id: 'services', name: 'Services', line: '1', hint: '', isIncome: true)],
    );
    final csv = entriesCsv([
      LedgerEntry(
        id: 1,
        isIncome: true,
        date: '2026-02-01',
        amountCents: 12345,
        feeCents: 100,
        businessPct: 100,
        category: 'services',
        party: '=cmd',
        platform: 'Etsy',
        notes: '',
        paid: false,
        tags: ' client-a etsy ', createdAt: DateTime(2026),
      ),
    ], rules);
    final lines = csv.split('\r\n');
    expect(lines[0], startsWith('Date,Type,Amount'));
    expect(lines[1], '2026-02-01,Income,123.45,1.00,,Services,1,"\'=cmd",Etsy,No (invoiced),,client-a etsy');
    expect(csvBytes('a').take(3), [0xEF, 0xBB, 0xBF]);
  });
}
