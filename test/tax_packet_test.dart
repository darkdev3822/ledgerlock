import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerlock/data/database.dart';
import 'package:ledgerlock/data/ledger.dart';
import 'package:ledgerlock/data/tax_packet.dart';
import 'package:ledgerlock/data/tax_rules.dart';

const _rules = TaxRules(
  year: 2026,
  quarterlyDue: [],
  lineNames: {'1': 'Gross receipts', '24b': 'Meals', '22': 'Supplies'},
  incomeCategories: [Category(id: 'services', name: 'Services', line: '1', hint: '', isIncome: true)],
  expenseCategories: [
    Category(id: 'supplies', name: 'Supplies', line: '22', hint: '', isIncome: false),
    Category(id: 'meals', name: 'Meals', line: '24b', hint: '', isIncome: false, deductibleShare: 0.5),
  ],
);

LedgerEntry _e(int id, bool income, int cents, String cat, {int pct = 100, bool paid = true, String platform = ''}) =>
    LedgerEntry(
      id: id,
      isIncome: income,
      date: '2026-03-0$id',
      amountCents: cents,
      feeCents: 0,
      businessPct: pct,
      category: cat,
      party: '',
      platform: platform,
      notes: '',
      paid: paid,
      tags: '', createdAt: DateTime(2026),
    );

final _entries = [
  _e(1, true, 100000, 'services', platform: 'Etsy'),
  _e(2, true, 40000, 'services', paid: false, platform: 'Etsy'),
  _e(3, false, 10000, 'meals'),
  _e(4, false, 20000, 'supplies', pct: 50),
];

void main() {
  test('category breakdown: paid income only, business % and meals share applied', () {
    final p = PacketInput(
      year: 2026,
      rules: _rules,
      summary: LedgerSummary.empty,
      entries: _entries,
      generated: DateTime(2026),
    );
    final b = categoryBreakdown(p);
    expect(b['services'], (1, 100000, 100000));
    expect(b['meals'], (1, 10000, 5000));
    expect(b['supplies'], (1, 20000, 10000));
    expect(recordedFrom('etsy', _entries), 100000, reason: 'unpaid invoice excluded');
  });

  test('packet renders, says it is not a return, never over-promises', () async {
    final summary = summarize(_entries.map((e) => e.data), _rules);
    final bytes = await buildTaxPacket(
      PacketInput(
        year: 2026,
        rules: _rules,
        summary: summary,
        entries: _entries,
        forms: const [Form1099(id: 1, year: 2026, kind: '1099-K', payer: 'Etsy', amountCents: 100000)],
        trips: const [Trip(id: 1, date: '2026-02-01', milesTenths: 125, purpose: 'Client', route: 'A-B')],
        payments: const [
          TaxPayment(
            id: 1,
            taxYear: 2026,
            quarter: 'Q1',
            date: '2026-04-15',
            amountCents: 5000,
            method: 'Direct Pay',
            notes: '',
          ),
        ],
        generated: DateTime(2026, 11, 1),
      ),
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    final dump = Platform.environment['LL_DUMP']; // LL_DUMP=/path/out.pdf to look at it
    if (dump != null) File(dump).writeAsBytesSync(bytes);
    expect(packetDisclaimer, contains('not a tax return'));
    final src = File('lib/data/tax_packet.dart').readAsStringSync().toLowerCase();
    for (final bad in ['we file', 'guaranteed', 'max refund', 'free filing', 'ready to file', 'file this']) {
      expect(src.contains(bad), isFalse, reason: bad);
    }
  });
}
