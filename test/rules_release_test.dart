// RELEASE GATE (SPEC §2.12, docs/ANNUAL_RULES_REVIEW.md): nothing unverified ships.
// Run before every release:  LL_RELEASE=1 flutter test test/rules_release_test.dart
// Skipped in day-to-day runs so unfinished reviews don't hide other failures. It is NOT optional for releases.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerlock/data/tax_rules.dart';
import 'package:ledgerlock/tax/guidance.dart';

final _skip = Platform.environment['LL_RELEASE'] == '1'
    ? false
    : 'Release gate: run with LL_RELEASE=1 before any release (owner-led rules review).';

void main() {
  test('every shipping rules file passed the owner-led review', () {
    final missing = <String>[];
    for (final y in TaxRules.supportedYears) {
      final r = TaxRules.fromJson(jsonDecode(File('assets/tax_rules/$y.json').readAsStringSync()));
      if (r.verified == null) missing.add('$y.json: review.verified');
      for (final k in r.keyFigures) {
        if (!k.usable) missing.add('$y.json: ${k.id}');
      }
    }
    final res = jsonDecode(File('assets/tax_rules/resources.json').readAsStringSync())['resources'] as List;
    for (final j in res) {
      final r = Resource.fromJson(j as Map<String, dynamic>);
      if (r.verified == null) missing.add('resources.json: ${r.id}');
      if (r.when.contains('incomeUnderLimit')) {
        for (final y in TaxRules.supportedYears) {
          if (r.incomeLimitCents[y] == null) missing.add('resources.json: ${r.id} limit $y');
        }
      }
    }
    expect(missing, isEmpty, reason: 'Unverified items. Walk the owner through docs/ANNUAL_RULES_REVIEW.md.');
  }, skip: _skip);
}
