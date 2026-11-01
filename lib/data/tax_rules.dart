// Tax rules are data (SPEC §6): assets/tax_rules/<year>.json. Never hard-code dates or rates in UI.
import 'dart:convert';

import 'package:flutter/services.dart';

class QuarterDue {
  final String quarter;
  final String covers;
  final DateTime due;
  const QuarterDue(this.quarter, this.covers, this.due);
}

class Category {
  final String id;
  final String name;
  final String line; // Schedule C line
  final String hint;
  final bool isIncome;

  /// Share of a business expense that's deductible (meals 0.5). 1.0 for income.
  final double deductibleShare;

  const Category({
    required this.id,
    required this.name,
    required this.line,
    required this.hint,
    required this.isIncome,
    this.deductibleShare = 1.0,
  });

  factory Category.fromJson(Map<String, dynamic> j, {required bool income}) => Category(
    id: j['id'] as String,
    name: j['name'] as String,
    line: j['line'] as String,
    hint: j['hint'] as String? ?? '',
    isIncome: income,
    deductibleShare: (j['deductibleShare'] as num?)?.toDouble() ?? 1.0,
  );
}

/// A headline number for "What changed for you" (e.g. mileage rate). [value] is null until the owner-led
/// review (docs/ANNUAL_RULES_REVIEW.md) fills it from the official source; null values are never shown.
class KeyFigure {
  final String id, name, unit, source;
  final num? value;
  final String? verified;
  const KeyFigure({
    required this.id,
    required this.name,
    required this.unit,
    this.source = '',
    this.value,
    this.verified,
  });
  bool get usable => value != null && verified != null;

  factory KeyFigure.fromJson(Map<String, dynamic> j) => KeyFigure(
    id: j['id'] as String,
    name: j['name'] as String,
    unit: j['unit'] as String? ?? '',
    source: j['source'] as String? ?? '',
    value: j['value'] as num?,
    verified: j['verified'] as String?,
  );
}

class TaxRules {
  final int year;
  final List<QuarterDue> quarterlyDue;
  final List<Category> incomeCategories;
  final List<Category> expenseCategories;

  /// Schedule C line id -> name, in form order.
  final Map<String, String> lineNames;
  final double seNetEarningsFactor;
  final double seRate;
  final int seMinimumNetEarningsCents;
  final double defaultSetAsidePct;

  /// Date the owner verified this file's numbers against the IRS (null = not yet; never ship).
  final String? verified;
  final List<KeyFigure> keyFigures;

  const TaxRules({
    required this.year,
    required this.quarterlyDue,
    this.incomeCategories = const [],
    this.expenseCategories = const [],
    this.lineNames = const {},
    this.seNetEarningsFactor = 0,
    this.seRate = 0,
    this.seMinimumNetEarningsCents = 0,
    this.defaultSetAsidePct = 25,
    this.verified,
    this.keyFigures = const [],
  });

  factory TaxRules.fromJson(Map<String, dynamic> j) {
    final se = j['selfEmployment'] as Map<String, dynamic>? ?? const {};
    return TaxRules(
      year: j['year'] as int,
      quarterlyDue: [
        for (final q in j['quarterlyDue'] as List)
          QuarterDue(q['quarter'] as String, q['covers'] as String, DateTime.parse(q['due'] as String)),
      ],
      incomeCategories: [
        for (final c in j['incomeCategories'] as List? ?? const []) Category.fromJson(c, income: true),
      ],
      expenseCategories: [
        for (final c in j['expenseCategories'] as List? ?? const []) Category.fromJson(c, income: false),
      ],
      lineNames: {for (final l in j['scheduleCLines'] as List? ?? const []) l[0] as String: l[1] as String},
      seNetEarningsFactor: (se['netEarningsFactor'] as num?)?.toDouble() ?? 0,
      seRate: (se['rate'] as num?)?.toDouble() ?? 0,
      seMinimumNetEarningsCents: (((se['minimumNetEarnings'] as num?) ?? 0) * 100).round(),
      defaultSetAsidePct: (j['defaultSetAsidePct'] as num?)?.toDouble() ?? 25,
      verified: (j['review'] as Map<String, dynamic>?)?['verified'] as String?,
      keyFigures: [
        for (final k in j['keyFigures'] as List? ?? const []) KeyFigure.fromJson(k as Map<String, dynamic>),
      ],
    );
  }

  List<Category> categories(bool income) => income ? incomeCategories : expenseCategories;

  Category? category(String id) {
    for (final c in [...incomeCategories, ...expenseCategories]) {
      if (c.id == id) return c;
    }
    return null;
  }

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
