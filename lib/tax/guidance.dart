// "What changed for you" + free resources matched to the user (SPEC §2.12). Everything here runs on the
// device over bundled data; nothing is fetched. Unverified data (docs/ANNUAL_RULES_REVIEW.md) is never shown.
import 'dart:convert';

import 'package:flutter/services.dart';

import '../data/tax_rules.dart';

/// Hosts a resource link may point to. Anything else is rejected at load and before opening.
const allowedLinkHosts = {'irs.gov', 'score.org'};

bool isAllowedLink(String url) {
  final u = Uri.tryParse(url);
  if (u == null || u.scheme != 'https' || u.hasQuery || u.hasFragment || u.userInfo.isNotEmpty) return false;
  if (u.hasPort && u.port != 443) return false;
  // Plain ASCII hostnames only: percent-escapes, backslashes and full-width characters can make a host look like
  // ".irs.gov" to us but resolve elsewhere in a browser (M9.5 review, T21).
  if (!RegExp(r'^[a-z0-9.-]+$').hasMatch(u.host) || url.contains('%') || url.contains(r'\')) return false;
  return allowedLinkHosts.any((h) => u.host == h || u.host.endsWith('.$h'));
}

/// Ways of getting paid that don't come with a 1099-K (the platform field is free text).
const _notPlatforms = {
  'bank',
  'cash',
  'check',
  'cheque',
  'direct deposit',
  'deposit',
  'wire',
  'ach',
  'zelle',
  'other',
  'none',
};

/// True for marketplaces and payment apps (Etsy, PayPal, Fiverr…), false for bank, cash, check and similar.
bool isPaymentPlatform(String p) {
  final s = p.trim().toLowerCase();
  return s.isNotEmpty && !_notPlatforms.contains(s);
}

/// Conditions a resource can be matched on, with how specific (useful) a match is.
const conditionRank = {
  'irsLetter': 5,
  'irsProblem': 5,
  'incomeUnderLimit': 4,
  'age60': 4,
  'firstYear': 3,
  'platformIncome': 3,
  'taxDue': 2,
  'selfEmployed': 1,
  'always': 0,
};

class Resource {
  final String id, name, purpose, url;
  final List<String> when;
  final Map<int, int?> incomeLimitCents;
  final String? verified;

  /// Privacy note shown before leaving for a non-government site (cookies, ad partners, location).
  final String siteNote;
  const Resource({
    required this.id,
    required this.name,
    required this.purpose,
    required this.url,
    required this.when,
    this.incomeLimitCents = const {},
    this.verified,
    this.siteNote = '',
  });

  /// Government sites (*.gov) need no extra note; every other host must carry a [siteNote].
  bool get isGovernment => Uri.parse(url).host.endsWith('.gov');

  factory Resource.fromJson(Map<String, dynamic> j) => Resource(
    id: j['id'] as String,
    name: j['name'] as String,
    purpose: j['purpose'] as String,
    url: j['url'] as String,
    when: [for (final w in j['when'] as List) w as String],
    incomeLimitCents: {
      for (final e in (j['incomeLimitCents'] as Map<String, dynamic>? ?? const {}).entries)
        int.parse(e.key): e.value is int ? e.value as int : null, // "unpublished" -> null
    },
    verified: j['verified'] as String?,
    siteNote: j['siteNote'] as String? ?? '',
  );

  /// Shown only when the owner has verified it and the link passes the allowlist.
  bool get usable =>
      verified != null &&
      isAllowedLink(url) &&
      when.every(conditionRank.containsKey) &&
      (isGovernment || siteNote.isNotEmpty);

  static Future<List<Resource>> load({AssetBundle? bundle}) async {
    final s = await (bundle ?? rootBundle).loadString('assets/tax_rules/resources.json');
    final j = jsonDecode(s) as Map<String, dynamic>;
    return [for (final r in j['resources'] as List) Resource.fromJson(r as Map<String, dynamic>)];
  }
}

/// What the device knows about the user, computed from their own records. Never leaves the phone.
class UserFacts {
  final int year;
  final int netCents, seTaxCents;
  final bool hasIncome, hadIncomeLastYear, hasIrsLetter;
  final Set<String> platforms; // platforms the user has income through
  final int platformIncomeCents;
  final bool age60OptIn, irsProblemOptIn;
  const UserFacts({
    required this.year,
    this.netCents = 0,
    this.seTaxCents = 0,
    this.hasIncome = false,
    this.hadIncomeLastYear = false,
    this.hasIrsLetter = false,
    this.platforms = const {},
    this.platformIncomeCents = 0,
    this.age60OptIn = false,
    this.irsProblemOptIn = false,
  });
}

class Suggestion {
  final Resource resource;

  /// Why it's shown, in the user's terms. Null for "always" items.
  final String? why;
  final int rank;
  const Suggestion(this.resource, this.why, this.rank);
}

String _money(int cents) {
  final d = (cents.abs() / 100).round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => ',');
  return '${cents < 0 ? '-' : ''}\$$d';
}

/// Resources that fit [f], most relevant first. Wording is "may be worth checking", never "you qualify".
List<Suggestion> suggestResources(List<Resource> all, UserFacts f) {
  final out = <(Suggestion, int)>[];
  for (final (i, r) in all.indexed) {
    if (!r.usable) continue;
    String? why;
    var best = -1;
    for (final c in r.when) {
      final reason = switch (c) {
        'always' => '',
        'irsLetter' when f.hasIrsLetter => 'You have an IRS letter in your vault.',
        'irsProblem' when f.irsProblemOptIn => 'You said you have an IRS problem that isn’t solved.',
        'incomeUnderLimit' => switch (r.incomeLimitCents[f.year]) {
          final limit? when f.hasIncome && f.netCents < limit =>
            'Your business profit so far (${_money(f.netCents)}) is under the ${_money(limit)} income level it lists. '
                'It counts all your income, so check the details.',
          _ => null,
        },
        'age60' when f.age60OptIn => 'You said you’re 60 or older.',
        'firstYear' when f.hasIncome && !f.hadIncomeLastYear => 'This looks like your first year self-employed.',
        'platformIncome' when f.platforms.isNotEmpty =>
          'You have ${_money(f.platformIncomeCents)} of income through ${(f.platforms.toList()..sort()).join(', ')}.',
        'taxDue' when f.seTaxCents > 0 =>
          'Your estimated self-employment tax for ${f.year} is ${_money(f.seTaxCents)}.',
        'selfEmployed' when f.hasIncome => 'You have self-employment income.',
        _ => null,
      };
      if (reason == null) continue;
      final rank = conditionRank[c]!;
      if (rank > best) {
        best = rank;
        why = reason.isEmpty ? null : reason;
      }
    }
    if (best >= 0) out.add((Suggestion(r, why, best), i));
  }
  out.sort((a, b) => b.$1.rank != a.$1.rank ? b.$1.rank - a.$1.rank : a.$2 - b.$2);
  return [for (final (s, _) in out) s];
}

class RuleChange {
  final String title;
  final String detail;

  /// Plain-language effect on this user, or null if none can be computed.
  final String? forYou;
  const RuleChange(this.title, this.detail, {this.forYou});
}

String _pct(double v) {
  final s = (v * 100).toStringAsFixed(2);
  return '${s.replaceAll(RegExp(r'\.?0+$'), '')}%';
}

String _figure(KeyFigure k) {
  final base = _one(k, k.value!);
  if (k.changes.isEmpty) return base;
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final later = [for (final (d, v) in k.changes) '${_one(k, v)} from ${months[d.month - 1]} ${d.day}'];
  return '$base, then ${later.join(', then ')}';
}

String _one(KeyFigure k, num v) => switch (k.unit) {
  'cents_per_mile' => '$v¢ a mile',
  'dollars' => [_money((v * 100).round()), if (k.detail.isNotEmpty) k.detail].join(' '),
  'dollars_per_sqft' => '\$$v a sq ft',
  'sqft' => '$v sq ft',
  _ => '$v',
};

/// Differences between last year's and this year's rules, applied to the user's numbers.
/// [expenseByCategory]: this year's business-share spend per category id, in cents.
/// [largestPlatformIncomeCents]: income through the user's biggest single platform (1099-K counts per platform).
/// Empty unless BOTH files passed the owner-led review.
List<RuleChange> whatChanged(
  TaxRules prev,
  TaxRules cur, {
  int netCents = 0,
  Map<String, int> expenseByCategory = const {},
  int largestPlatformIncomeCents = 0,
}) {
  if (prev.verified == null || cur.verified == null) return const [];
  final out = <RuleChange>[];

  if (prev.seRate != cur.seRate || prev.seNetEarningsFactor != cur.seNetEarningsFactor) {
    int se(TaxRules r) => netCents <= 0 ? 0 : (netCents * r.seNetEarningsFactor * r.seRate).round();
    final delta = se(cur) - se(prev);
    out.add(
      RuleChange(
        'Self-employment tax rate',
        '${_pct(prev.seNetEarningsFactor)} × ${_pct(prev.seRate)} → '
            '${_pct(cur.seNetEarningsFactor)} × ${_pct(cur.seRate)}',
        forYou: netCents > 0 && delta != 0
            ? 'About ${_money(delta.abs())} ${delta > 0 ? 'more' : 'less'} on your profit so far.'
            : null,
      ),
    );
  }

  for (final c in cur.expenseCategories) {
    final old = prev.category(c.id);
    if (old == null) {
      out.add(RuleChange('New category: ${c.name}', 'Schedule C line ${c.line}.'));
      continue;
    }
    if (old.deductibleShare != c.deductibleShare) {
      final spend = expenseByCategory[c.id] ?? 0;
      final delta = (spend * (c.deductibleShare - old.deductibleShare)).round();
      out.add(
        RuleChange(
          '${c.name}: deductible share',
          '${_pct(old.deductibleShare)} → ${_pct(c.deductibleShare)}',
          forYou: spend > 0 ? 'About ${_money(delta.abs())} ${delta > 0 ? 'more' : 'less'} deduction for you.' : null,
        ),
      );
    }
  }

  final before = {for (final k in prev.keyFigures.where((k) => k.usable)) k.id: k};
  for (final k in cur.keyFigures.where((k) => k.usable)) {
    final old = before[k.id];
    if (old == null || (old.value == k.value && old.changes.isEmpty && k.changes.isEmpty)) continue;
    String? forYou;
    if (k.id == 'form_1099k_threshold' && largestPlatformIncomeCents > 0) {
      final top = _money(largestPlatformIncomeCents);
      forYou = largestPlatformIncomeCents > k.value! * 100
          ? 'Your biggest platform ($top) is over the amount: expect a 1099-K'
                '${k.detail.isEmpty ? '' : ' if you also meet the rest (${k.detail})'}. Report all income either way.'
          : 'Your biggest platform ($top) is under it so far. Card payments can still bring a 1099-K, '
                'and all income is reported either way.';
    }
    out.add(RuleChange(k.name, '${_figure(old)} → ${_figure(k)}', forYou: forYou));
  }
  return out;
}
