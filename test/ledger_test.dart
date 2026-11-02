// M3 "done when": dashboard maths matches the desktop Tax Keeper on the same data.
// Expected numbers come from the desktop app itself: tool/desktop_reference.py.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerlock/data/ledger.dart';
import 'package:ledgerlock/data/tax_rules.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final records = (jsonDecode(File('test/fixtures/ledger_records.json').readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();
  final expected = jsonDecode(File('test/fixtures/ledger_expected.json').readAsStringSync()) as Map<String, dynamic>;
  final entries = [
    for (final r in records)
      EntryData(
        isIncome: r['kind'] == 'income',
        date: DateTime.parse(r['date'] as String),
        amountCents: r['amountCents'] as int,
        feeCents: r['feeCents'] as int? ?? 0,
        businessPct: r['businessPct'] as int? ?? 100,
        category: r['category'] as String,
      ),
  ];

  for (final year in expected.keys) {
    test('summary for $year matches the desktop Tax Keeper (within 1 cent on half-cent ties)', () async {
      final rules = await TaxRules.load(int.parse(year));
      final s = summarize(entries, rules);
      final e = expected[year] as Map<String, dynamic>;
      void close(String what, int actual, int want) =>
          expect((actual - want).abs(), lessThanOrEqualTo(1), reason: '$what: app $actual vs desktop $want');
      close('gross', s.grossCents, e['grossCents'] as int);
      close('expenses', s.expensesCents, e['expensesCents'] as int);
      close('net', s.netCents, e['netCents'] as int);
      close('SE tax', s.seTaxCents, e['seTaxCents'] as int);
      close('set-aside', s.setAsideCents, e['setAsideCents'] as int);
      final lines = (e['lines'] as Map<String, dynamic>).cast<String, int>();
      expect(s.lines.keys.toSet(), lines.keys.toSet());
      for (final l in lines.entries) {
        close('line ${l.key}', s.lines[l.key]!, l.value);
      }
    });
  }

  test('SE tax is zero below the \$400 net-earnings threshold, and losses set nothing aside', () async {
    final rules = await TaxRules.load(2026);
    EntryData inc(int c) => EntryData(isIncome: true, date: DateTime(2026, 3, 1), amountCents: c, category: 'services');
    expect(summarize([inc(43300)], rules).seTaxCents, 0); // 433.00 * 0.9235 = 399.88
    expect(summarize([inc(43400)], rules).seTaxCents, greaterThan(0)); // 400.80
    final loss = summarize([
      inc(1000),
      EntryData(isIncome: false, date: DateTime(2026, 3, 2), amountCents: 5000, category: 'software'),
    ], rules);
    expect(loss.netCents, -4000);
    expect(loss.seTaxCents, 0);
    expect(loss.setAsideCents, 0);
  });

  test('entries from other years are ignored; monthly totals feed the chart', () async {
    final rules = await TaxRules.load(2026);
    final s = summarize(entries, rules);
    expect(s.monthly.keys.every((m) => m >= 1 && m <= 12), isTrue);
    final monthlyIncome = s.monthly.values.fold(0, (a, m) => a + m.$1);
    expect(monthlyIncome, s.lines['1']! - s.lines['2']! + s.lines['6']!);
  });

  test('every category in the rules maps to a known Schedule C line', () async {
    for (final y in TaxRules.supportedYears) {
      final r = await TaxRules.load(y);
      for (final c in [...r.incomeCategories, ...r.expenseCategories]) {
        expect(r.lineNames.containsKey(c.line), isTrue, reason: '${c.id} -> ${c.line}');
      }
      expect(r.category('meals')!.deductibleShare, 0.5);
    }
  });
}
