import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerlock/data/database.dart';
import 'package:ledgerlock/data/ledger.dart';
import 'package:ledgerlock/data/tax_rules.dart';
import 'package:ledgerlock/security/crypto.dart';

void main() {
  final base = TaxRules.fromJson(jsonDecode(File('assets/tax_rules/2026.json').readAsStringSync()));
  const mine = [
    CustomCategory('custom_a', 'Client lunches', 'meals'),
    CustomCategory('custom_b', 'Etsy shop', 'product_sales'),
    CustomCategory('custom_c', 'Gone next year', 'no_such_category'),
  ];

  test('a custom category takes its base line and deductible share; unknown bases are left out', () {
    final r = base.withCustom(mine);
    final lunch = r.category('custom_a')!, meals = r.category('meals')!;
    expect((lunch.line, lunch.deductibleShare, lunch.isIncome), (meals.line, meals.deductibleShare, false));
    final etsy = r.category('custom_b');
    if (base.category('product_sales') != null) {
      expect(etsy!.isIncome, isTrue);
      expect(r.incomeCategories.contains(etsy), isTrue);
    }
    expect(r.category('custom_c'), isNull);
    expect(r.expenseCategories.length, base.expenseCategories.length + 1);
    expect(identical(base.withCustom(const []), base), isTrue);
  });

  test('records in a custom category add up on the base line exactly like the base category', () {
    final r = base.withCustom(mine);
    EntryData e(String cat) =>
        EntryData(isIncome: false, date: DateTime(2026, 3, 1), amountCents: 10000, category: cat);
    final viaCustom = summarize([e('custom_a')], r), viaBase = summarize([e('meals')], r);
    expect(viaCustom.lines, viaBase.lines);
    expect(viaCustom.expensesCents, viaBase.expensesCents);
  });

  test('decodeList ignores junk; round-trips', () {
    expect(CustomCategory.decodeList('nope'), isEmpty);
    expect(CustomCategory.decodeList('[{"id":1},{"id":"x","name":"N","base":"meals"}]').single.name, 'N');
    expect(CustomCategory.decodeList(CustomCategory.encodeList(mine)).map((c) => c.baseId), mine.map((c) => c.baseId));
  });

  test('reassignCategory moves records, repeats and rules', () async {
    final dir = Directory.systemTemp.createTempSync('ll_cc');
    addTearDown(() => dir.deleteSync(recursive: true));
    final db = AppDatabase.open(File('${dir.path}/c.db'), LedgerCrypto.randomBytes(32));
    await db.addEntry(
      LedgerEntriesCompanion.insert(isIncome: false, date: '2026-03-01', amountCents: 1, category: 'custom_a'),
    );
    await db.addEntry(
      LedgerEntriesCompanion.insert(isIncome: false, date: '2026-03-02', amountCents: 2, category: 'office'),
    );
    await db.addRecurring(
      RecurringsCompanion.insert(
        isIncome: false,
        amountCents: 1,
        category: 'custom_a',
        every: 'month',
        anchorDay: 1,
        nextDate: '2027-01-01',
      ),
    );
    await db.addRule(CategoryRulesCompanion.insert(isIncome: false, contains: 'cafe', category: 'custom_a'));
    await db.reassignCategory('custom_a', 'meals');
    expect((await db.watchYear(2026).first).map((e) => e.category).toSet(), {'meals', 'office'});
    expect((await db.watchRecurring().first).single.category, 'meals');
    expect((await db.allRules()).single.category, 'meals');
    expect((await db.allRules()).single.businessPct, isNull);
    await db.close();
  });
}
