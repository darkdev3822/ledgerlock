import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerlock/data/tax_rules.dart';
import 'package:ledgerlock/tax/guidance.dart';

Map<String, dynamic> _json(String p) => jsonDecode(File(p).readAsStringSync()) as Map<String, dynamic>;

List<Resource> _bundled() => [
  for (final r in _json('assets/tax_rules/resources.json')['resources'] as List)
    Resource.fromJson(r as Map<String, dynamic>),
];

Resource _r(
  String id,
  List<String> when, {
  Map<int, int?> limits = const {},
  String? verified = '2026-12-01',
}) => Resource(
  id: id,
  name: id,
  purpose: 'p',
  url: 'https://www.irs.gov/$id',
  when: when,
  incomeLimitCents: limits,
  verified: verified,
);

void main() {
  group('links (SPEC §2.12: no user data, official hosts only)', () {
    test('allowlist', () {
      for (final ok in [
        'https://www.irs.gov/x',
        'https://irs.gov',
        'https://www.taxpayeradvocate.irs.gov/',
        'https://www.score.org/',
      ]) {
        expect(isAllowedLink(ok), isTrue, reason: ok);
      }
      for (final bad in [
        'http://www.irs.gov/',
        'https://irs.gov.evil.com/',
        'https://evilirs.gov/',
        'https://www.irs.gov/x?id=123',
        'https://www.irs.gov/x#me',
        'https://user@www.irs.gov/',
        'https://www.irs.gov:8443/',
        'javascript:alert(1)',
        'intent://irs.gov#Intent;end',
        '',
      ]) {
        expect(isAllowedLink(bad), isFalse, reason: bad);
      }
    });
  });

  test('bank, cash and check are not 1099-K platforms', () {
    for (final p in ['Bank', ' cash ', 'Check', 'Direct deposit', 'Zelle', '']) {
      expect(isPaymentPlatform(p), isFalse, reason: p);
    }
    for (final p in ['Etsy', 'PayPal', 'itch.io', 'Ko-fi']) {
      expect(isPaymentPlatform(p), isTrue, reason: p);
    }
  });

  group('bundled data', () {
    test('resources.json is well formed', () {
      final all = _bundled();
      expect(all.map((r) => r.id).toSet().length, all.length, reason: 'unique ids');
      for (final r in all) {
        expect(isAllowedLink(r.url), isTrue, reason: r.url);
        expect(r.when, isNotEmpty);
        expect(r.when.every(conditionRank.containsKey), isTrue, reason: '${r.id}: ${r.when}');
        expect(r.incomeLimitCents.keys.every(TaxRules.supportedYears.contains), isTrue, reason: r.id);
      }
      expect(all.any((r) => r.id == 'disaster_relief' && r.when.contains('always')), isTrue);
      for (final r in all.where((r) => !r.isGovernment)) {
        expect(r.siteNote, isNotEmpty, reason: '${r.id}: non-government sites need a privacy note');
      }
    });

    test('unverified resources are never suggested', () {
      final facts = UserFacts(
        year: 2026,
        netCents: 100,
        seTaxCents: 10,
        hasIncome: true,
        hasIrsLetter: true,
        platforms: {'Etsy'},
        platformIncomeCents: 100,
        age60OptIn: true,
        irsProblemOptIn: true,
      );
      final shown = suggestResources(_bundled(), facts);
      expect(shown.every((s) => s.resource.verified != null), isTrue);
      expect(
        suggestResources([
          _r('x', ['always'], verified: null),
        ], facts),
        isEmpty,
      );
    });

    test('year files carry a review stamp and key figures', () {
      for (final y in TaxRules.supportedYears) {
        final j = _json('assets/tax_rules/$y.json');
        expect(j.containsKey('review'), isTrue, reason: '$y');
        final r = TaxRules.fromJson(j);
        expect(r.keyFigures.map((k) => k.id), containsAll(['mileage_rate', 'form_1099k_threshold']));
      }
    });
  });

  group('matching', () {
    const f = UserFacts(
      year: 2026,
      netCents: 2000000,
      seTaxCents: 282600,
      hasIncome: true,
      platforms: {'Etsy'},
      platformIncomeCents: 500000,
    );

    test('ranked by how specific the match is, with reasons', () {
      final s = suggestResources([
        _r('always', ['always']),
        _r('se', ['selfEmployed']),
        _r('k', ['platformIncome']),
        _r('vita', ['incomeUnderLimit'], limits: {2026: 6000000}),
        _r('tce', ['age60']),
        _r('tas', ['irsLetter', 'irsProblem']),
      ], f);
      expect(s.map((x) => x.resource.id), ['vita', 'k', 'se', 'always']);
      expect(s.first.why, contains(r'$20,000'));
      expect(s.first.why, contains(r'$60,000'));
      expect(s[1].why, contains('Etsy'));
      expect(s.last.why, isNull);
    });

    test('income limits: null or other-year limit never matches; over the limit does not match', () {
      expect(
        suggestResources([
          _r('v', ['incomeUnderLimit']),
        ], f),
        isEmpty,
      );
      expect(
        suggestResources([
          _r('v', ['incomeUnderLimit'], limits: {2025: 9999999}),
        ], f),
        isEmpty,
      );
      expect(
        suggestResources([
          _r('v', ['incomeUnderLimit'], limits: {2026: 1000000}),
        ], f),
        isEmpty,
      );
    });

    test('a non-government site without a privacy note is never shown', () {
      final r = Resource(
        id: 's',
        name: 's',
        purpose: 'p',
        url: 'https://www.score.org/',
        when: const ['always'],
        verified: 'x',
      );
      expect(suggestResources([r], f), isEmpty);
    });

    test('an "unpublished" limit never matches', () {
      final r = Resource.fromJson({
        'id': 'ff',
        'name': 'ff',
        'purpose': 'p',
        'url': 'https://www.irs.gov/x',
        'when': ['incomeUnderLimit'],
        'incomeLimitCents': {'2026': 'unpublished'},
        'verified': 'x',
      });
      expect(suggestResources([r], f), isEmpty);
    });

    test('opt-ins and vault letters; first year', () {
      const g = UserFacts(year: 2026, hasIncome: true, hasIrsLetter: true, age60OptIn: true);
      final s = suggestResources([
        _r('tas', ['irsLetter', 'irsProblem']),
        _r('tce', ['age60']),
        _r('fy', ['firstYear']),
      ], g);
      expect(s.map((x) => x.resource.id), ['tas', 'tce', 'fy']);
      expect(s.first.why, contains('letter'));
    });

    test('wording never claims eligibility', () {
      final s = suggestResources([
        _r('vita', ['incomeUnderLimit'], limits: {2026: 6000000}),
      ], f);
      expect(s.first.why!.toLowerCase(), isNot(contains('qualify')));
      expect(s.first.why!.toLowerCase(), isNot(contains('eligible')));
      const old = UserFacts(year: 2026, age60OptIn: true);
      final w = suggestResources([
        _r('tce', ['age60']),
      ], old).single.why!.toLowerCase();
      expect(w, isNot(contains('told us')), reason: 'never imply the answer was shared');
    });
  });

  group('what changed', () {
    TaxRules rules(int y, {String? verified = 'x', double meals = .5, double seRate = .153, num? k1099}) =>
        TaxRules(
          year: y,
          quarterlyDue: const [],
          verified: verified,
          seNetEarningsFactor: .9235,
          seRate: seRate,
          expenseCategories: [
            Category(
              id: 'meals',
              name: 'Meals',
              line: '24b',
              hint: '',
              isIncome: false,
              deductibleShare: meals,
            ),
          ],
          keyFigures: [
            KeyFigure(
              id: 'form_1099k_threshold',
              name: '1099-K threshold',
              unit: 'dollars',
              value: k1099,
              verified: k1099 == null ? null : 'x',
            ),
          ],
        );

    test('nothing until both years are verified', () {
      expect(whatChanged(rules(2025, verified: null), rules(2026, meals: 1)), isEmpty);
      expect(whatChanged(rules(2025), rules(2026, verified: null, meals: 1)), isEmpty);
    });

    test('applies changes to the user\'s numbers', () {
      final c = whatChanged(
        rules(2025, k1099: 5000),
        rules(2026, meals: 1, seRate: .16, k1099: 2500),
        netCents: 1000000,
        expenseByCategory: {'meals': 40000},
        largestPlatformIncomeCents: 300000,
      );
      expect(c.map((x) => x.title), [
        'Self-employment tax rate',
        'Meals: deductible share',
        '1099-K threshold',
      ]);
      expect(c[0].forYou, contains('more'));
      expect(c[1].detail, '50% → 100%');
      expect(c[1].forYou, contains(r'$200'));
      expect(c[2].detail, r'$5,000 → $2,500');
      expect(c[2].forYou, contains('expect a 1099-K'));
    });

    test('1099-K: two-part threshold shown, judged on the biggest single platform', () {
      KeyFigure k(num v) => KeyFigure(
        id: 'form_1099k_threshold',
        name: '1099-K threshold',
        unit: 'dollars',
        value: v,
        detail: 'in more than 200 transactions, per platform',
        verified: 'x',
      );
      TaxRules r(int y, num v) =>
          TaxRules(year: y, quarterlyDue: const [], verified: 'x', keyFigures: [k(v)]);
      final over = whatChanged(r(2025, 5000), r(2026, 20000), largestPlatformIncomeCents: 2500000).single;
      expect(over.detail, contains('200 transactions'));
      expect(over.forYou, contains('if you also meet the rest'));
      final under = whatChanged(r(2025, 5000), r(2026, 20000), largestPlatformIncomeCents: 1500000).single;
      expect(under.forYou, contains('under it'));
    });

    test('mileage: mid-year change applies by date and is shown', () {
      final k = KeyFigure.fromJson({
        'id': 'mileage_rate',
        'name': 'Mileage',
        'unit': 'cents_per_mile',
        'value': 72.5,
        'verified': 'x',
        'changes': [
          {'from': '2026-07-01', 'value': 76},
        ],
      });
      expect(k.valueOn(DateTime(2026, 6, 30)), 72.5);
      expect(k.valueOn(DateTime(2026, 7, 1)), 76);
      const old = KeyFigure(
        id: 'mileage_rate',
        name: 'Mileage',
        unit: 'cents_per_mile',
        value: 70,
        verified: 'x',
      );
      TaxRules r(int y, KeyFigure f) =>
          TaxRules(year: y, quarterlyDue: const [], verified: 'x', keyFigures: [f]);
      final c = whatChanged(r(2025, old), r(2026, k)).single;
      expect(c.detail, '70¢ a mile → 72.5¢ a mile, then 76¢ a mile from Jul 1');
    });

    test('unverified key figures are ignored', () {
      expect(whatChanged(rules(2025, k1099: 5000), rules(2026)), isEmpty);
    });
  });
}
