// Schedule SE maths (lines 4a-12) incl. the Social Security wage base and W-2 wages.
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerlock/data/ledger.dart';
import 'package:ledgerlock/data/tax_rules.dart';

TaxRules _rules({bool verifiedBase = true}) => TaxRules(
  year: 2026,
  quarterlyDue: const [],
  seNetEarningsFactor: .9235,
  seRate: .153,
  seSocialSecurityRate: .124,
  seMinimumNetEarningsCents: 40000,
  keyFigures: [
    KeyFigure(
      id: 'ss_wage_base',
      name: 'base',
      unit: 'dollars',
      value: 184500,
      verified: verifiedBase ? 'x' : null,
    ),
  ],
);

void main() {
  const net = 10000000.0; // $100,000 profit -> $92,350 net earnings
  test('no W-2 wages: full 15.3%', () {
    expect(seTaxFor(net, _rules()), closeTo(9235000 * .153, 1));
  });
  test('W-2 wages at the base: only the 2.9% Medicare part', () {
    expect(seTaxFor(net, _rules(), w2WagesCents: 18450000), closeTo(9235000 * .029, 1));
  });
  test('W-2 wages partly use the base (lines 8-10)', () {
    final room = 18450000 - 15000000; // $34,500 left
    expect(seTaxFor(net, _rules(), w2WagesCents: 15000000), closeTo(room * .124 + 9235000 * .029, 1));
  });
  test('earnings above the base with no wages are capped', () {
    const big = 30000000.0; // $300,000 profit -> $277,050 earnings
    expect(seTaxFor(big, _rules()), closeTo(18450000 * .124 + big * .9235 * .029, 1));
  });
  test('under \$400 of net earnings: no SE tax', () {
    expect(seTaxFor(43000, _rules()), 0); // $430 profit -> $397.11 earnings
  });
  test('unverified wage base: flat rate (can only overstate)', () {
    expect(seTaxFor(net, _rules(verifiedBase: false), w2WagesCents: 18450000), closeTo(9235000 * .153, 1));
  });
  test('summarize passes W-2 wages through', () {
    expect(summarize(const [], _rules(), w2WagesCents: 1).seTaxCents, 0);
  });
}
