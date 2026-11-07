// Learn: short offline lessons matched to how the user earns (assets/lessons/lessons.json). Everything is bundled;
// nothing is fetched. Accuracy rules (same as the tax rules, docs/ANNUAL_RULES_REVIEW.md):
//  * a lesson is shown in a release build only once the owner has verified it (verified: true);
//  * lessons never contain a typed tax number: {{placeholders}} are filled from the verified rules file, and an
//    unverified figure renders as "not confirmed yet";
//  * sources are ids from the already-verified resources list, never free-typed links.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../data/tax_rules.dart';

class LessonTrack {
  final String id, title, subtitle;

  /// Business types (lib/data/business_types.dart) this track is for; empty = everyone.
  final List<String> forTypes;
  const LessonTrack(this.id, this.title, this.subtitle, this.forTypes);
}

class Lesson {
  final String id, track, title, trigger, you, action;
  final int minutes;
  final List<String> body, sources, checkAgainst;
  final bool verified;
  const Lesson({
    required this.id,
    required this.track,
    required this.title,
    required this.trigger,
    required this.you,
    required this.action,
    required this.minutes,
    required this.body,
    required this.sources,
    required this.checkAgainst,
    required this.verified,
  });
}

/// What lessons may ask for. Anything else is rejected when the file is loaded (lessons_test).
const lessonTriggers = {
  'always',
  'first_income',
  'quarter_soon',
  'has_1099',
  'has_trips',
  'has_unpaid',
  'has_missing_receipts',
};
const lessonYouBlocks = {
  'none',
  'se_tax',
  'profit',
  'quarterly',
  'set_aside',
  'records',
  'cash_basis',
  'forms_1099',
  'home_office',
  'mileage',
};
const lessonActions = {
  'none',
  'open_taxes',
  'add_expense',
  'add_income',
  'open_payments',
  'search_no_receipt',
  'search_unpaid',
  'open_1099s',
  'open_home_office',
  'log_trip',
};
const lessonPlaceholders = {
  'year',
  'se_rate',
  'se_ss_rate',
  'se_medicare_rate',
  'se_factor',
  'se_min',
  'q_dates',
  'k_threshold',
  'mileage_rate',
  'home_office_rate',
  'home_office_max',
  'set_aside_default',
};

final _placeholder = RegExp(r'\{\{([a-z_]+)\}\}');

class LessonLibrary {
  final List<LessonTrack> tracks;
  final List<Lesson> lessons;
  const LessonLibrary(this.tracks, this.lessons);

  static Future<LessonLibrary> load({AssetBundle? bundle}) async =>
      parse(await (bundle ?? rootBundle).loadString('assets/lessons/lessons.json'));

  /// Strict: an unknown trigger, action, placeholder or track is a bug in the file, so it throws (caught by tests,
  /// never shipped).
  static LessonLibrary parse(String json) {
    final j = jsonDecode(json) as Map<String, dynamic>;
    final tracks = [
      for (final t in j['tracks'] as List)
        LessonTrack(t['id'] as String, t['title'] as String, t['subtitle'] as String, [
          for (final x in t['for'] as List) x as String,
        ]),
    ];
    final ids = {for (final t in tracks) t.id};
    final seen = <String>{};
    final lessons = <Lesson>[];
    for (final m in j['lessons'] as List) {
      final l = Lesson(
        id: m['id'] as String,
        track: m['track'] as String,
        title: m['title'] as String,
        trigger: m['trigger'] as String,
        you: m['you'] as String,
        action: m['action'] as String,
        minutes: m['minutes'] as int,
        body: [for (final p in m['body'] as List) p as String],
        sources: [for (final s in m['sources'] as List) s as String],
        checkAgainst: [for (final s in m['checkAgainst'] as List) s as String],
        verified: m['verified'] == true,
      );
      void check(bool ok, String what) {
        if (!ok) throw FormatException('lesson ${l.id}: $what');
      }

      check(seen.add(l.id), 'duplicate id');
      check(ids.contains(l.track), 'unknown track ${l.track}');
      check(lessonTriggers.contains(l.trigger), 'unknown trigger ${l.trigger}');
      check(lessonYouBlocks.contains(l.you), 'unknown you-block ${l.you}');
      check(lessonActions.contains(l.action), 'unknown action ${l.action}');
      check(l.body.isNotEmpty && l.checkAgainst.isNotEmpty, 'needs a body and what to check it against');
      for (final p in l.body) {
        for (final ph in _placeholder.allMatches(p)) {
          check(lessonPlaceholders.contains(ph.group(1)), 'unknown placeholder ${ph.group(0)}');
        }
        // A typed dollar amount or percentage would dodge the yearly review: numbers come from placeholders.
        check(!RegExp(r'\$\d|\d\s?%|\d+\s?(cents|¢)').hasMatch(p.replaceAll(_placeholder, '')), 'typed tax number');
      }
      lessons.add(l);
    }
    return LessonLibrary(tracks, lessons);
  }

  /// Lessons a user may see: verified ones (drafts too in debug builds, badged, for the owner's review).
  List<Lesson> visible({bool drafts = kDebugMode}) => [
    for (final l in lessons)
      if (l.verified || drafts) l,
  ];

  /// Tracks for this user's business types (all tracks when none were chosen), with at least one visible lesson.
  List<LessonTrack> tracksFor(Set<String> types, {bool drafts = kDebugMode}) {
    final have = {for (final l in visible(drafts: drafts)) l.track};
    return [
      for (final t in tracks)
        if (have.contains(t.id) && (t.forTypes.isEmpty || types.isEmpty || t.forTypes.any(types.contains))) t,
    ];
  }

  List<Lesson> inTrack(String track, {bool drafts = kDebugMode}) => [
    for (final l in visible(drafts: drafts))
      if (l.track == track) l,
  ];
}

String _pct(double v) {
  final p = v * 100;
  return '${p == p.roundToDouble() ? p.toStringAsFixed(0) : p.toStringAsFixed(p * 10 == (p * 10).roundToDouble() ? 1 : 2)}%';
}

final _dollars = NumberFormat.simpleCurrency(locale: 'en_US', decimalDigits: 0);
const notConfirmed = 'an amount the IRS hasn\'t confirmed yet';

/// Fills {{placeholders}} from the rules file. Figures the review hasn't verified never appear as numbers.
String fillLesson(String text, TaxRules r) {
  bool pending(String word) => r.pending.any((p) => p.what.toLowerCase().contains(word));
  String figure(String id, String Function(num v) fmt) {
    final f = r.figure(id);
    if (f == null) return notConfirmed;
    final changes = [for (final (from, v) in f.changes) '${fmt(v)} from ${DateFormat.MMMd().format(from)}'];
    return changes.isEmpty ? fmt(f.value!) : '${fmt(f.value!)} (${changes.join(', ')})';
  }

  return text.replaceAllMapped(_placeholder, (m) {
    switch (m.group(1)) {
      case 'year':
        return '${r.year}';
      case 'se_rate':
        return _pct(r.seRate);
      case 'se_ss_rate':
        return _pct(r.seSocialSecurityRate);
      case 'se_medicare_rate':
        return _pct(r.seRate - r.seSocialSecurityRate);
      case 'se_factor':
        final v = _pct(r.seNetEarningsFactor);
        return pending('earnings factor') ? '$v (last year\'s figure until this year\'s form is out)' : v;
      case 'se_min':
        return _dollars.format(r.seMinimumNetEarningsCents / 100);
      case 'q_dates':
        return [for (final q in r.quarterlyDue) '${q.quarter} ${DateFormat.yMMMd().format(q.due)}'].join(', ');
      case 'k_threshold':
        final f = r.figure('form_1099k_threshold');
        final v = figure('form_1099k_threshold', (v) => _dollars.format(v));
        return f != null && f.detail.isNotEmpty ? '$v ${f.detail}' : v;
      case 'mileage_rate':
        return figure('mileage_rate', (v) => '$v¢');
      case 'home_office_rate':
        return figure('home_office_rate', (v) => _dollars.format(v));
      case 'home_office_max':
        return figure('home_office_max_sqft', (v) => '$v');
      case 'set_aside_default':
        return '${r.defaultSetAsidePct.round()}%';
    }
    return notConfirmed;
  });
}

/// Which triggers hold right now, from the user's own data (computed on the phone).
Set<String> activeTriggers({
  required bool hasIncome,
  required bool has1099,
  required bool hasTrips,
  required bool hasUnpaid,
  required bool hasMissingReceipts,
  required int? daysToNextDue,
}) => {
  'always',
  if (hasIncome) 'first_income',
  if (has1099) 'has_1099',
  if (hasTrips) 'has_trips',
  if (hasUnpaid) 'has_unpaid',
  if (hasMissingReceipts) 'has_missing_receipts',
  if (daysToNextDue != null && daysToNextDue >= 0 && daysToNextDue <= 30) 'quarter_soon',
};

/// The one lesson worth suggesting on Home: unread, for this user's tracks, whose moment has come. Specific triggers
/// beat 'always', then file order. Null when there's nothing new.
Lesson? suggestLesson(
  LessonLibrary lib, {
  required Set<String> types,
  required Set<String> done,
  required Set<String> dismissed,
  required Set<String> triggers,
  bool drafts = kDebugMode,
}) {
  final tracks = {for (final t in lib.tracksFor(types, drafts: drafts)) t.id};
  final open = [
    for (final l in lib.visible(drafts: drafts))
      if (tracks.contains(l.track) && !done.contains(l.id) && !dismissed.contains(l.id) && triggers.contains(l.trigger))
        l,
  ];
  if (open.isEmpty) return null;
  return open.firstWhere((l) => l.trigger != 'always', orElse: () => open.first);
}
