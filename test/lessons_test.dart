import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerlock/data/tax_rules.dart';
import 'package:ledgerlock/learn/lessons.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LessonLibrary lib;
  late TaxRules rules;
  setUpAll(() async {
    lib = await LessonLibrary.load();
    rules = await TaxRules.load(2026);
  });

  test('the bundled file is valid: known tracks/triggers/actions/placeholders, no typed tax numbers', () {
    expect(lib.lessons.length, greaterThanOrEqualTo(10));
    final resources = (jsonDecode(File('assets/tax_rules/resources.json').readAsStringSync())['resources'] as List)
        .map((r) => r['id'] as String)
        .toSet();
    for (final l in lib.lessons) {
      for (final s in l.sources) {
        expect(resources, contains(s), reason: '${l.id}: sources must be verified resource ids');
      }
    }
  });

  test('the loader rejects typed numbers, unknown placeholders and unknown actions', () {
    String file(Map<String, Object> lesson) => jsonEncode({
      'tracks': [
        {'id': 'basics', 'title': 'B', 'subtitle': 's', 'for': []},
      ],
      'lessons': [
        {
          'id': 'x',
          'track': 'basics',
          'title': 't',
          'minutes': 1,
          'trigger': 'always',
          'you': 'none',
          'action': 'none',
          'body': ['ok'],
          'sources': [],
          'checkAgainst': ['Pub'],
          'verified': false,
          ...lesson,
        },
      ],
    });
    expect(() => LessonLibrary.parse(file({})), returnsNormally);
    for (final bad in [
      'The rate is 15.3% of profit',
      r'Up to $5 per square foot',
      'It is 70 cents a mile',
      '{{nope}}',
    ]) {
      expect(
        () => LessonLibrary.parse(
          file({
            'body': [bad],
          }),
        ),
        throwsFormatException,
        reason: bad,
      );
    }
    expect(() => LessonLibrary.parse(file({'action': 'open_url'})), throwsFormatException);
    expect(() => LessonLibrary.parse(file({'track': 'stocks'})), throwsFormatException);
    expect(() => LessonLibrary.parse(file({'checkAgainst': <String>[]})), throwsFormatException);
  });

  test('placeholders fill from the rules file; unverified figures never show a number', () {
    final text = lib.lessons.expand((l) => l.body).map((p) => fillLesson(p, rules)).join('\n');
    expect(text.contains('{{'), isFalse);
    expect(fillLesson('{{se_rate}} / {{se_ss_rate}} / {{se_medicare_rate}}', rules), '15.3% / 12.4% / 2.9%');
    expect(fillLesson('{{se_factor}}', rules), contains('92.35%'));
    expect(fillLesson('{{se_factor}}', rules), contains('last year'), reason: '2026 factor is pending');
    expect(fillLesson('{{q_dates}}', rules), contains('Q4 Jan 15, 2027'));
    // A figure the review hasn't verified (2025 file has fewer) says so instead of guessing.
    final noFigures = TaxRules(
      year: rules.year,
      quarterlyDue: rules.quarterlyDue,
      incomeCategories: rules.incomeCategories,
      expenseCategories: rules.expenseCategories,
      lineNames: rules.lineNames,
      seNetEarningsFactor: rules.seNetEarningsFactor,
      seRate: rules.seRate,
      seSocialSecurityRate: rules.seSocialSecurityRate,
      seMinimumNetEarningsCents: rules.seMinimumNetEarningsCents,
      defaultSetAsidePct: rules.defaultSetAsidePct,
      verified: null,
      keyFigures: const [],
      pending: const [],
    );
    expect(
      fillLesson('{{mileage_rate}} {{home_office_rate}} {{k_threshold}}', noFigures),
      isNot(contains(RegExp(r'\d'))),
    );
  });

  test('release builds show only verified lessons; drafts appear only when asked (debug review)', () {
    expect(lib.visible(drafts: false).every((l) => l.verified), isTrue);
    expect(lib.visible(drafts: true).length, lib.lessons.length);
    // Today every lesson is a draft: nothing ships until the owner's review.
    expect(lib.tracksFor(const {}, drafts: false), isEmpty);
  });

  test('tracks follow how you earn; suggestions prefer the lesson whose moment has come', () {
    final driver = lib.tracksFor({'driving'}, drafts: true).map((t) => t.id).toSet();
    expect(driver, containsAll(['basics', 'driving', 'money']));
    expect(driver.contains('products'), isFalse);
    expect(lib.tracksFor(const {}, drafts: true).length, lib.tracks.length, reason: 'no types chosen: everything');

    final triggers = activeTriggers(
      hasIncome: true,
      has1099: false,
      hasTrips: true,
      hasUnpaid: false,
      hasMissingReceipts: false,
      daysToNextDue: 12,
    );
    final first = suggestLesson(
      lib,
      types: {'driving'},
      done: const {},
      dismissed: const {},
      triggers: triggers,
      drafts: true,
    )!;
    expect(first.trigger, isNot('always'));
    final next = suggestLesson(
      lib,
      types: {'driving'},
      done: {first.id},
      dismissed: const {},
      triggers: triggers,
      drafts: true,
    )!;
    expect(next.id, isNot(first.id));
    expect(
      suggestLesson(lib, types: {'driving'}, done: const {}, dismissed: const {}, triggers: triggers, drafts: false),
      isNull,
    );
  });
}
