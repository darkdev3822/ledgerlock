// Fuzz: ledger money maths, SE tax, mileage, home office; check-in questions and reminder planning at edge
// dates; orderCategories; TaxRules/KeyFigure/Resource JSON loading with malformed input.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerlock/data/business_types.dart';
import 'package:ledgerlock/data/database.dart';
import 'package:ledgerlock/data/ledger.dart';
import 'package:ledgerlock/data/tax_rules.dart';
import 'package:ledgerlock/tax/checkin.dart';
import 'package:ledgerlock/tax/guidance.dart';

import 'fuzz_util.dart';

TaxRules rulesFor(int year) =>
    TaxRules.fromJson(jsonDecode(File('assets/tax_rules/$year.json').readAsStringSync()) as Map<String, dynamic>);

/// Verified home-office figures so homeOfficeCents is exercised (values are arbitrary test inputs, not tax data).
TaxRules withFigures(TaxRules r, {num rate = 3, num cap = 250}) => TaxRules(
  year: r.year,
  quarterlyDue: r.quarterlyDue,
  incomeCategories: r.incomeCategories,
  expenseCategories: r.expenseCategories,
  seNetEarningsFactor: r.seNetEarningsFactor,
  seRate: r.seRate,
  seSocialSecurityRate: r.seSocialSecurityRate,
  seMinimumNetEarningsCents: r.seMinimumNetEarningsCents,
  keyFigures: [
    ...r.keyFigures.where((k) => !k.id.startsWith('home_office')),
    KeyFigure(id: 'home_office_rate', name: 'r', unit: '', value: rate, verified: 'test'),
    KeyFigure(id: 'home_office_max_sqft', name: 'c', unit: '', value: cap, verified: 'test'),
  ],
);

void main() {
  final rules = rulesFor(2026);
  final cats = [...rules.incomeCategories, ...rules.expenseCategories];

  EntryData randomEntry(Random r, {int maxCents = 1000000}) {
    final c = cats[r.nextInt(cats.length)];
    return EntryData(
      isIncome: c.isIncome,
      date: DateTime(r.nextInt(10) == 0 ? 2025 : 2026, 1 + r.nextInt(12), 1 + r.nextInt(28)),
      amountCents: maxCents > 1 << 32 ? r.nextInt(1 << 32) * (maxCents >> 32) : r.nextInt(maxCents),
      feeCents: c.isIncome ? r.nextInt(500) : 0,
      businessPct: r.nextInt(101),
      category: r.nextInt(20) == 0 ? 'unknown_cat' : c.id,
      paid: r.nextInt(5) != 0,
    );
  }

  test('summarize: integer cents, SE tax and set-aside never negative, SE tax monotone in net', () {
    final r = Random(20);
    for (var it = 0; it < 3000; it++) {
      final es = [
        for (var i = 0; i < r.nextInt(40); i++) randomEntry(r, maxCents: r.nextBool() ? 100000 : 100000000000),
      ];
      final s = timed(
        () => summarize(
          es,
          rules,
          w2WagesCents: r.nextInt(30000000),
          mileageCents: r.nextInt(100000),
          homeOfficeCents: r.nextInt(200000),
        ),
        input: es.length,
      );
      expect(s.seTaxCents, greaterThanOrEqualTo(0));
      expect(s.setAsideCents, greaterThanOrEqualTo(0));
      expect(s.lines.containsKey('30') ? s.lines['30']! : 0, greaterThanOrEqualTo(0));
      if (s.lines.containsKey('30')) {
        expect(s.netCents, greaterThanOrEqualTo(0), reason: 'home office cannot create a loss');
      }
      // Totals within 1 cent per line of the sum of the rounded parts.
      final expenseLines = s.lines.entries.where((e) => !const {'1', '2', '6'}.contains(e.key));
      final sum = expenseLines.fold(0, (a, e) => a + e.value);
      expect((sum - s.expensesCents).abs(), lessThanOrEqualTo(expenseLines.length));
      expect((s.grossCents - s.expensesCents - s.netCents).abs(), lessThanOrEqualTo(1));
    }
    var prev = -1.0;
    for (var net = -100000.0; net < 40000000; net += 9973) {
      final t = seTaxFor(net, rules);
      expect(t, greaterThanOrEqualTo(prev));
      expect(seTaxFor(net, rules, w2WagesCents: 10000000), lessThanOrEqualTo(t + 1e-6));
      prev = t;
    }
    expect(seTaxFor(-1e12, rules), 0);
    expect(seTaxFor(1e13, rules, w2WagesCents: -5).isFinite, isTrue);
  });

  test('F5 rounded totals disagree with their parts (gross - expenses != net)', () {
    // One meals expense: 1 cent at 100% -> 0.5 deductible cents (meals share 0.5).
    final meal = cats.firstWhere((c) => !c.isIncome && c.deductibleShare < 1);
    final s = summarize([
      EntryData(
        isIncome: true,
        date: DateTime(2026, 1, 2),
        amountCents: 100,
        category: rules.incomeCategories.first.id,
      ),
      EntryData(isIncome: false, date: DateTime(2026, 1, 2), amountCents: 1, category: meal.id),
    ], rules);
    expect(
      s.grossCents - s.expensesCents,
      s.netCents,
      reason: 'gross ${s.grossCents} expenses ${s.expensesCents} net ${s.netCents}',
    );
  });

  test('mileage and home office: bounded, integer, cap respected', () {
    final r = Random(21);
    final hr = withFigures(rules);
    for (var it = 0; it < 5000; it++) {
      final trips = [
        for (var i = 0; i < r.nextInt(30); i++)
          (
            '2026-${(1 + r.nextInt(12)).toString().padLeft(2, '0')}-${(1 + r.nextInt(28)).toString().padLeft(2, '0')}',
            r.nextInt(100000),
          ),
      ];
      final m = timed(() => mileageDeductionCents(trips, rules), input: trips);
      expect(m, greaterThanOrEqualTo(0));
      final sq = r.nextInt(1 << 31) - 1000;
      final h = homeOfficeCents(sq, hr)!;
      expect(h, inInclusiveRange(0, 250 * 3 * 100));
    }
    final unverified = withFigures(rules);
    final stripped = TaxRules(
      year: unverified.year,
      quarterlyDue: unverified.quarterlyDue,
      incomeCategories: unverified.incomeCategories,
      expenseCategories: unverified.expenseCategories,
      seNetEarningsFactor: unverified.seNetEarningsFactor,
      seRate: unverified.seRate,
      seSocialSecurityRate: unverified.seSocialSecurityRate,
      seMinimumNetEarningsCents: unverified.seMinimumNetEarningsCents,
      keyFigures: [
        for (final k in unverified.keyFigures)
          k.id.startsWith('home_office') ? KeyFigure(id: k.id, name: k.name, unit: k.unit, value: k.value) : k,
      ],
    );
    expect(homeOfficeCents(100, stripped), isNull, reason: 'unverified figures are never used');
  });

  test('F6 negative trip miles produce a negative mileage deduction', () {
    expect(mileageDeductionCents([('2026-03-01', -100)], rules), greaterThanOrEqualTo(0));
  });

  // ---------- check-in ----------

  LedgerEntry le(Random r, DateTime d) => LedgerEntry(
    id: r.nextInt(1 << 30),
    isIncome: r.nextBool(),
    date: isoDay(d),
    amountCents: r.nextInt(100000),
    feeCents: 0,
    businessPct: 100,
    category: r.nextInt(4) == 0 ? 'other_expense' : 'supplies',
    party: ['Adobe', ' adobe ', 'Etsy', '', fuzzString(r, maxPieces: 2)][r.nextInt(5)],
    platform: ['Etsy', 'PayPal', '', 'Stripe'][r.nextInt(4)],
    notes: '',
    paid: r.nextBool(),
    tags: '', createdAt: DateTime(2026),
  );

  final edgeDays = [
    DateTime(2024, 2, 29),
    DateTime(2028, 2, 29),
    DateTime(2025, 12, 31),
    DateTime(2026, 1, 1),
    DateTime(2026, 3, 8),
    DateTime(2026, 11, 1),
    DateTime(2026, 4, 15),
    DateTime(2027, 1, 15),
    DateTime(2026, 1, 31),
    DateTime(2026, 3, 31),
  ];

  test('checkInQuestions: edge dates and random books never throw; <= max; unique keys', () {
    final r = Random(22);
    final r25 = rulesFor(2025);
    for (var it = 0; it < 2000; it++) {
      final today = r.nextBool()
          ? edgeDays[r.nextInt(edgeDays.length)]
          : DateTime(2025 + r.nextInt(3), 1 + r.nextInt(12), 1 + r.nextInt(31), r.nextInt(24));
      final entries = [
        for (var i = 0; i < r.nextInt(it % 200 == 0 ? 3000 : 30); i++)
          le(r, today.subtract(Duration(days: r.nextInt(500)))),
      ];
      final max = r.nextInt(8);
      final qs = timed(
        () => checkInQuestions(
          today: today,
          entries: entries,
          entriesWithReceipt: {
            for (final e in entries)
              if (r.nextBool()) e.id,
          },
          payments: const [],
          formsLastYear: const [],
          rules: [rules, r25, null][r.nextInt(3)],
          max: max,
        ),
        input: today,
      );
      expect(qs.length, lessThanOrEqualTo(max));
      expect(qs.map((q) => q.key).toSet().length, qs.length);
    }
  });

  test('planReminders: future only, sorted, unique ids, 8 check-ins at 18:00, generic text', () {
    final r = Random(23);
    final all = [rulesFor(2025), rules];
    for (var it = 0; it < 1500; it++) {
      final now = r.nextBool()
          ? edgeDays[r.nextInt(edgeDays.length)].add(Duration(minutes: r.nextInt(2000)))
          : DateTime(2024 + r.nextInt(4), 1 + r.nextInt(12), 1 + r.nextInt(31), r.nextInt(24), r.nextInt(60));
      final days = [0, 1, 7, 14, 30, -3][r.nextInt(6)];
      final last = [
        null,
        now,
        now.subtract(Duration(days: r.nextInt(4000))),
        DateTime(1970),
      ][r.nextInt(it % 50 == 0 ? 4 : 3)];
      final out = timed(
        () => planReminders(now: now, rules: all, quarterly: r.nextBool(), checkInDays: days, lastCheckIn: last),
        input: '$now $days $last',
        limitMs: last?.year == 1970 ? 1000 : 200, // walks day by day from 1970: O(days since last check-in)
      );
      expect(out.every((x) => x.at.isAfter(now)), isTrue);
      expect(out.map((x) => x.id).toSet().length, out.length);
      for (var i = 1; i < out.length; i++) {
        expect(!out[i].at.isBefore(out[i - 1].at), isTrue);
      }
      final checks = out.where((x) => x.id <= 8).toList();
      expect(checks.length, days > 0 ? 8 : 0);
      for (final c in checks) {
        expect(c.at.hour, 18);
      }
      if (checks.isNotEmpty) {
        expect(checks.first.at.difference(now).inHours, lessThanOrEqualTo(days * 24 + 24), reason: '$now $days $last');
      }
      for (final x in out) {
        expect('${x.title}${x.body}', isNot(matches(RegExp(r'[\$\d]'))));
      }
    }
  });

  test('F7 a lastCheckIn in the future (clock was ahead) silences check-ins until that date', () {
    final now = DateTime(2026, 11, 2, 12);
    final out = planReminders(
      now: now,
      rules: const [],
      quarterly: false,
      checkInDays: 7,
      lastCheckIn: DateTime(2030, 1, 1),
    );
    expect(out.first.at.difference(now).inDays, lessThanOrEqualTo(7), reason: 'first check-in ${out.first.at}');
  });

  test(
    'F8 "nothing recorded for 3 weeks" is a day late across the spring DST change (run with TZ=America/New_York)',
    () {
      final r = Random(1);
      final e = le(r, DateTime(2026, 3, 8));
      final qs = checkInQuestions(
        today: DateTime(2026, 3, 29, 10),
        entries: [e],
        entriesWithReceipt: {e.id},
        payments: const [],
        formsLastYear: const [],
        rules: null,
      );
      expect(qs.any((q) => q.key.startsWith('quiet:')), isTrue, reason: '21 calendar days since the last entry');
    },
  );

  // ---------- business types ----------

  test('orderCategories: a permutation for any type set; preferred ones first', () {
    final r = Random(24);
    final keys = [...businessTypes.keys, 'bogus', ''];
    for (var it = 0; it < 5000; it++) {
      final list = [...cats]..shuffle(r);
      final types = {
        for (final k in keys)
          if (r.nextBool()) k,
      };
      final out = timed(() => orderCategories(list, types), input: types);
      expect(out.length, list.length);
      expect(out.toSet(), list.toSet());
    }
  });

  // ---------- rules / resources JSON ----------

  Object? mutate(Random r, Object? v) {
    if (r.nextInt(150) == 0) {
      return [null, 1, 'x', 2.5, true, <Object?>[], <String, Object?>{}, '2026-13-45', -1][r.nextInt(9)];
    }
    if (v is Map) {
      return <String, dynamic>{
        for (final e in v.entries)
          if (r.nextInt(150) != 0) e.key as String: mutate(r, e.value),
      };
    }
    if (v is List) {
      return <dynamic>[
        for (final x in v)
          if (r.nextInt(150) != 0) mutate(r, x),
      ];
    }
    return v;
  }

  test('TaxRules.fromJson / Resource.fromJson with mutated JSON: only clean throws, no hangs', () {
    final r = Random(25);
    final base = jsonDecode(File('assets/tax_rules/2026.json').readAsStringSync());
    final res = jsonDecode(File('assets/tax_rules/resources.json').readAsStringSync()) as Map<String, dynamic>;
    var ok = 0;
    for (var it = 0; it < 3000; it++) {
      final m = mutate(r, base);
      try {
        final t = timed(() => TaxRules.fromJson(m as Map<String, dynamic>), input: it);
        t.nextDue(DateTime(2026, 5, 1));
        ok++;
      } on TypeError {
        // Expected: assets are trusted, release tests catch bad files.
      } on FormatException {
        // bad dates
      } on NoSuchMethodError {
        // q['due'] on a non-map
      } on RangeError {
        // scheduleCLines row too short
      }
      final mr = mutate(r, res['resources']);
      for (final rr in mr is List ? mr : const []) {
        try {
          final x = Resource.fromJson(rr as Map<String, dynamic>);
          x.usable;
        } on TypeError {
          //
        } on FormatException {
          //
        } on NoSuchMethodError {
          //
        }
      }
    }
    expect(ok, greaterThan(0));
  });
}
