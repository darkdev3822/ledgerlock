import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerlock/data/business_types.dart';
import 'package:ledgerlock/data/tax_rules.dart';

Category _c(String id) => Category(id: id, name: id, line: '', hint: '', isIncome: false);

void main() {
  final cats = ['advertising', 'equipment', 'software', 'supplies', 'travel', 'other_expense'].map(_c).toList();

  test('no types: order unchanged', () {
    expect(orderCategories(cats, {}), cats);
  });

  test('likely categories first, nothing hidden, no duplicates', () {
    final o = orderCategories(cats, {'products'}).map((c) => c.id).toList();
    expect(o.take(3), ['supplies', 'advertising', 'equipment']);
    expect(o.toSet(), cats.map((c) => c.id).toSet());
    expect(o.length, cats.length);
    final both = orderCategories(cats, {'services', 'products'}).map((c) => c.id).toList();
    expect(both.first, 'supplies', reason: 'type order follows the businessTypes map, not the set');
    expect(both.length, cats.length);
  });

  test('every listed category id exists in the bundled rules', () {
    const known = {
      'product_sales', 'services', 'tips', 'refunds_given', 'other_income', 'advertising', 'platform_fees', //
      'contract_labor', 'equipment', 'insurance', 'legal_professional', 'office', 'rent', 'supplies',
      'taxes_licenses', 'travel', 'meals', 'utilities', 'software', 'education', 'other_expense',
    };
    for (final t in businessTypes.values) {
      expect(known.containsAll(t.$3), isTrue, reason: t.$1);
    }
  });
}
