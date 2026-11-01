// Tax rules are data (SPEC §6): assets/tax_rules/<year>.json. Never hard-code dates or rates in UI.
import 'dart:convert';

import 'package:flutter/services.dart';

class QuarterDue {
  final String quarter;
  final String covers;
  final DateTime due;
  const QuarterDue(this.quarter, this.covers, this.due);
}

class TaxRules {
  final int year;
  final List<QuarterDue> quarterlyDue;
  const TaxRules(this.year, this.quarterlyDue);

  factory TaxRules.fromJson(Map<String, dynamic> j) => TaxRules(j['year'] as int, [
    for (final q in j['quarterlyDue'] as List)
      QuarterDue(q['quarter'] as String, q['covers'] as String, DateTime.parse(q['due'] as String)),
  ]);

  /// The first quarter due on or after [today], or null if the year is done.
  QuarterDue? nextDue(DateTime today) {
    final d = DateTime(today.year, today.month, today.day);
    for (final q in quarterlyDue) {
      if (!q.due.isBefore(d)) return q;
    }
    return null;
  }

  /// Years that ship with a rules file (newest first).
  static const supportedYears = [2026, 2025];

  static Future<TaxRules> load(int year, {AssetBundle? bundle}) async {
    final s = await (bundle ?? rootBundle).loadString('assets/tax_rules/$year.json');
    return TaxRules.fromJson(jsonDecode(s) as Map<String, dynamic>);
  }
}
