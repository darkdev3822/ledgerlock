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

  /// Extra condition shown with the value, e.g. "in more than 200 transactions".
  final String detail;

  /// Mid-year changes: from each date on, a new value applies ([value] holds from Jan 1).
  final List<(DateTime, num)> changes;

  /// The value in force on [day] (e.g. a trip's date for the mileage rate).
  num? valueOn(DateTime day) {
    var v = value;
    for (final (from, x) in changes) {
      if (!day.isBefore(from)) v = x;
    }
    return v;
  }

  final String? verified;
  const KeyFigure({
    required this.id,
    required this.name,
    required this.unit,
    this.source = '',
    this.detail = '',
    this.changes = const [],
    this.value,
    this.verified,
  });
  bool get usable => value != null && verified != null;

  factory KeyFigure.fromJson(Map<String, dynamic> j) => KeyFigure(
    id: j['id'] as String,
    name: j['name'] as String,
    unit: j['unit'] as String? ?? '',
    source: j['source'] as String? ?? '',
    detail: j['detail'] as String? ?? '',
    changes: [
      for (final c in j['changes'] as List? ?? const [])
        (DateTime.parse((c as Map<String, dynamic>)['from'] as String), c['value'] as num),
    ]..sort((a, b) => a.$1.compareTo(b.$1)),
    value: j['value'] as num?,
    verified: j['verified'] as String?,
  );
}

/// A user's own category (SPEC §3 custom categories). It always counts as a built-in [baseId] category, whose
/// Schedule C line and deductible share it takes from the year's rules file: the user never types tax details.
class CustomCategory {
  final String id; // 'custom_...'
  final String name;
  final String baseId;
  const CustomCategory(this.id, this.name, this.baseId);

  Map<String, String> toJson() => {'id': id, 'name': name, 'base': baseId};

  static List<CustomCategory> decodeList(String? json) {
    try {
      return [
        for (final m in jsonDecode(json ?? '[]') as List)
          if (m is Map && m['id'] is String && m['name'] is String && m['base'] is String)
            CustomCategory(m['id'] as String, m['name'] as String, m['base'] as String),
      ];
    } catch (_) {
      return [];
    }
  }

  static String encodeList(List<CustomCategory> l) => jsonEncode([for (final c in l) c.toJson()]);
}

final _byId = Expando<Map<String, Category>>('categoriesById');

class TaxRules {
  final int year;
  final List<QuarterDue> quarterlyDue;
  final List<Category> incomeCategories;
  final List<Category> expenseCategories;

  /// Schedule C line id -> name, in form order.
  final Map<String, String> lineNames;
  final double seNetEarningsFactor;
  final double seRate;

  /// Social Security part of [seRate] (Schedule SE line 10); the rest is Medicare (line 11).
  final double seSocialSecurityRate;
  final int seMinimumNetEarningsCents;
  final double defaultSetAsidePct;

  /// Date the owner verified this file's numbers against the IRS (null = not yet; never ship as a final release).
  final String? verified;
  final List<KeyFigure> keyFigures;

  /// Figures the IRS hasn't published yet (review.pending). Shown on the Taxes tab; a beta may ship with them listed.
  final List<PendingFigure> pending;

  const TaxRules({
    required this.year,
    required this.quarterlyDue,
    this.incomeCategories = const [],
    this.expenseCategories = const [],
    this.lineNames = const {},
    this.seNetEarningsFactor = 0,
    this.seRate = 0,
    this.seSocialSecurityRate = 0,
    this.seMinimumNetEarningsCents = 0,
    this.defaultSetAsidePct = 25,
    this.verified,
    this.keyFigures = const [],
    this.pending = const [],
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
      seSocialSecurityRate: (se['socialSecurityRate'] as num?)?.toDouble() ?? 0,
      seMinimumNetEarningsCents: (((se['minimumNetEarnings'] as num?) ?? 0) * 100).round(),
      defaultSetAsidePct: (j['defaultSetAsidePct'] as num?)?.toDouble() ?? 25,
      verified: (j['review'] as Map<String, dynamic>?)?['verified'] as String?,
      keyFigures: [for (final k in j['keyFigures'] as List? ?? const []) KeyFigure.fromJson(k as Map<String, dynamic>)],
      pending: [
        for (final p in (j['review'] as Map<String, dynamic>?)?['pending'] as List? ?? const [])
          PendingFigure.fromJson(p as Map<String, dynamic>),
      ],
    );
  }

  /// A verified key figure, or null (unverified figures are never used in maths).
  KeyFigure? figure(String id) {
    for (final k in keyFigures) {
      if (k.id == id && k.usable) return k;
    }
    return null;
  }

  /// Social Security wage base in cents, only once verified (null = no cap applied; overstates for high earners).
  int? get ssWageBaseCents {
    for (final k in keyFigures) {
      if (k.id == 'ss_wage_base' && k.usable) return (k.value! * 100).round();
    }
    return null;
  }

  /// This year's rules plus the user's own categories, each copying its base category's line and share. A custom
  /// category whose base this year doesn't have is left out (its records then show as uncategorised).
  TaxRules withCustom(List<CustomCategory> custom) {
    if (custom.isEmpty) return this;
    Category? base(String id) => [...incomeCategories, ...expenseCategories].where((c) => c.id == id).firstOrNull;
    List<Category> extra(bool income) => [
      for (final c in custom)
        if (base(c.baseId) case final b? when b.isIncome == income)
          Category(
            id: c.id,
            name: c.name,
            line: b.line,
            hint: 'Your category, counted as ${b.name}',
            isIncome: income,
            deductibleShare: b.deductibleShare,
          ),
    ];
    return TaxRules(
      year: year,
      quarterlyDue: quarterlyDue,
      incomeCategories: [...incomeCategories, ...extra(true)],
      expenseCategories: [...expenseCategories, ...extra(false)],
      lineNames: lineNames,
      seNetEarningsFactor: seNetEarningsFactor,
      seRate: seRate,
      seSocialSecurityRate: seSocialSecurityRate,
      seMinimumNetEarningsCents: seMinimumNetEarningsCents,
      defaultSetAsidePct: defaultSetAsidePct,
      verified: verified,
      keyFigures: keyFigures,
      pending: pending,
    );
  }

  List<Category> categories(bool income) => income ? incomeCategories : expenseCategories;

  /// By id. Called for every record on every summary, so it's a map lookup (scale test: 10,000 records), built
  /// once per rules object (the class is const, so the map lives in an Expando).
  Category? category(String id) =>
      (_byId[this] ??= {for (final c in expenseCategories) c.id: c, for (final c in incomeCategories) c.id: c})[id];

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

/// A figure still waiting for its IRS source, and what the app does meanwhile.
class PendingFigure {
  final String what;
  final String source;
  final String expected;
  final String meanwhile;

  /// keyFigures id, when the pending item is one (lets the release gate match them up).
  final String? figure;
  const PendingFigure({required this.what, this.source = '', this.expected = '', this.meanwhile = '', this.figure});

  factory PendingFigure.fromJson(Map<String, dynamic> j) => PendingFigure(
    what: j['what'] as String? ?? '',
    source: j['source'] as String? ?? '',
    expected: j['expected'] as String? ?? '',
    meanwhile: j['meanwhile'] as String? ?? '',
    figure: j['figure'] as String?,
  );
}
