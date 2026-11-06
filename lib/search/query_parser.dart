// Natural-language search parser (SPEC §4): a small local parser, no AI service.
// "fuel over 50 in 2026", "fiverr fees march", "no receipt > 75", "uncategorized last year".
import '../data/database.dart' show normalizeTags, safeTake;

class SearchQuery {
  final List<String> terms; // free-text words for FTS
  final int? minCents, maxCents;
  final int? year, month;
  final bool? isIncome;
  final Set<String> categories;

  /// Words that were read as category keywords. They also match as text ("ad" -> advertising
  /// OR Adobe), so typing a word that happens to be a keyword never hides results.
  final List<String> categoryWords;
  final bool? hasReceipt;

  /// Invoiced income not received yet.
  final bool unpaidOnly;
  final bool feesOnly;

  /// '#tag' words, normalised like stored tags (all must match).
  final List<String> tags;

  /// End of a month range ("q2", "march to may"): [month]..[monthTo]. Null = single month or none.
  final int? monthTo;

  /// Schedule C lines ("line 9", "line 27a"); resolved to categories by the search service.
  final List<String> lines;

  /// Expenses not fully for business ("mixed use", "personal use").
  final bool mixedUse;

  /// What the parser understood, one removable chip each, with the words it came from.
  final List<UnderstoodChip> chips;

  /// The normalised words the query was parsed from (lower case, punctuation split off).
  final List<String> words;

  /// Human-readable chips: what the parser understood.
  List<String> get understood => [for (final c in chips) c.label];

  /// The query text with chip [i]'s words taken out, for removing a filter by tapping its chip.
  String without(int i) {
    final drop = chips[i].words.toSet();
    return [
      for (var k = 0; k < words.length; k++)
        if (!drop.contains(k)) words[k],
    ].join(' ');
  }

  const SearchQuery({
    this.terms = const [],
    this.minCents,
    this.maxCents,
    this.year,
    this.month,
    this.isIncome,
    this.categories = const {},
    this.categoryWords = const [],
    this.hasReceipt,
    this.unpaidOnly = false,
    this.feesOnly = false,
    this.tags = const [],
    this.monthTo,
    this.lines = const [],
    this.mixedUse = false,
    this.chips = const [],
    this.words = const [],
  });

  bool get isEmpty =>
      terms.isEmpty &&
      minCents == null &&
      maxCents == null &&
      year == null &&
      month == null &&
      isIncome == null &&
      categories.isEmpty &&
      hasReceipt == null &&
      !unpaidOnly &&
      !feesOnly &&
      tags.isEmpty &&
      lines.isEmpty &&
      !mixedUse;

  /// Only text (and maybe a year): documents are worth searching too.
  bool get documentsApply =>
      minCents == null &&
      maxCents == null &&
      categories.isEmpty &&
      !feesOnly &&
      isIncome == null &&
      hasReceipt == null &&
      !unpaidOnly &&
      tags.isEmpty &&
      lines.isEmpty &&
      !mixedUse;

  /// FTS5 MATCH expression built only from letters/digits, each term quoted and prefix-matched,
  /// so user input can never inject FTS syntax (SECURITY.md T6). Null if there's nothing to match.
  String? get ftsMatch => _fts(terms, ' AND ');

  /// Same sanitising as [ftsMatch], for [categoryWords], OR-joined.
  String? get categoryTextMatch => _fts(categoryWords, ' OR ');

  static String? _fts(List<String> words, String op) {
    final safe = [
      for (final t in words)
        if (t.replaceAll(_notWord, '').isNotEmpty) '"${t.replaceAll(_notWord, '')}"*',
    ];
    return safe.isEmpty ? null : safe.join(op);
  }

  static final _notWord = RegExp(r'[^\p{L}\p{N}]', unicode: true);
}

/// One filter the parser read, and the indexes (into [SearchQuery.words]) of the words behind it.
class UnderstoodChip {
  final String label;
  final List<int> words;
  const UnderstoodChip(this.label, this.words);
}

const _months = {
  'jan': 1,
  'january': 1,
  'feb': 2,
  'february': 2,
  'mar': 3,
  'march': 3,
  'apr': 4,
  'april': 4,
  'may': 5,
  'jun': 6,
  'june': 6,
  'jul': 7,
  'july': 7,
  'aug': 8,
  'august': 8,
  'sep': 9,
  'sept': 9,
  'september': 9,
  'oct': 10,
  'october': 10,
  'nov': 11,
  'november': 11,
  'dec': 12,
  'december': 12,
};
const _monthNames = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// Everyday words -> category ids (from assets/tax_rules).
const _synonyms = <String, String>{
  'meal': 'meals',
  'meals': 'meals',
  'food': 'meals',
  'lunch': 'meals',
  'dinner': 'meals',
  'breakfast': 'meals',
  'restaurant': 'meals',
  'coffee': 'meals',
  'cafe': 'meals',
  'flight': 'travel',
  'flights': 'travel',
  'hotel': 'travel',
  'airfare': 'travel',
  'trip': 'travel',
  'travel': 'travel',
  'software': 'software',
  'subscription': 'software',
  'subscriptions': 'software',
  'app': 'software',
  'apps': 'software',
  'computer': 'equipment',
  'laptop': 'equipment',
  'equipment': 'equipment',
  'hardware': 'equipment',
  'supplies': 'supplies',
  'supply': 'supplies',
  'ads': 'advertising',
  'ad': 'advertising',
  'advertising': 'advertising',
  'marketing': 'advertising',
  'phone': 'utilities',
  'internet': 'utilities',
  'wifi': 'utilities',
  'utilities': 'utilities',
  'course': 'education',
  'courses': 'education',
  'book': 'education',
  'books': 'education',
  'training': 'education',
  'insurance': 'insurance',
  'legal': 'legal_professional',
  'lawyer': 'legal_professional',
  'accountant': 'legal_professional',
  'office': 'office',
  'postage': 'office',
  'stamps': 'office',
  'rent': 'rent',
  'lease': 'rent',
  'studio': 'rent',
  'contractor': 'contract_labor',
  'contractors': 'contract_labor',
  'license': 'taxes_licenses',
  'licenses': 'taxes_licenses',
  'permit': 'taxes_licenses',
  'commission': 'platform_fees',
  'commissions': 'platform_fees',
  'refund': 'refunds_given',
  'refunds': 'refunds_given',
  'tips': 'tips',
  'tip': 'tips',
  'donation': 'tips',
  'donations': 'tips',
};

const _stop = {
  'in',
  'on',
  'for',
  'at',
  'the',
  'a',
  'an',
  'and',
  'of',
  'from',
  'to',
  'my',
  'all',
  'show',
  'find',
  'me',
  'during',
};

/// Caps keep pasted walls of text cheap and below SQLite's FTS expression limits (SECURITY.md T7).
const maxQueryChars = 200, maxQueryWords = 24;

SearchQuery parseQuery(String input, {required DateTime today}) {
  input = safeTake(input, maxQueryChars);
  final words = input
      .toLowerCase()
      .replaceAllMapped(RegExp(r'(\d),(\d{3})\b'), (m) => '${m[1]}${m[2]}') // 1,000 -> 1000
      .replaceAllMapped(RegExp(r'(>=|<=|>|<)'), (m) => ' ${m[1]} ')
      .replaceAll(RegExp(r'[,;!?"()]'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .take(maxQueryWords)
      .toList();
  final terms = <String>[];
  final chips = <UnderstoodChip>[];
  void understood(String label, int from, int count) =>
      chips.add(UnderstoodChip(label, [for (var k = from; k < from + count; k++) k]));
  final cats = <String>{};
  final catWords = <String>[];
  int? minC, maxC, year, month;
  bool? income, receipt;
  var unpaid = false;
  var fees = false;
  final tags = <String>[];
  final lines = <String>[];
  int? monthTo;
  var mixed = false;

  int? money(String w) {
    final m = RegExp(r'^\$?(\d{1,9})(?:\.(\d{1,2}))?$').firstMatch(w);
    if (m == null) return null;
    return int.parse(m[1]!) * 100 + int.parse((m[2] ?? '0').padRight(2, '0'));
  }

  String fmt(int c) => '\$${c % 100 == 0 ? c ~/ 100 : (c / 100).toStringAsFixed(2)}';

  for (var i = 0; i < words.length; i++) {
    final w = words[i];
    String? next([int k = 1]) => i + k < words.length ? words[i + k] : null;

    // Amount comparisons: "over 50", "> 50", "more than 50", "between 10 and 20".
    if ({'over', 'above', '>', '>='}.contains(w) || ((w == 'more' || w == 'greater') && next() == 'than')) {
      final skip = (w == 'more' || w == 'greater') ? 2 : 1;
      final v = next(skip) == null ? null : money(next(skip)!);
      if (v != null) {
        minC = v;
        understood('Over ${fmt(v)}', i, skip + 1);
        i += skip;
        continue;
      }
    }
    if ({'under', 'below', '<', '<='}.contains(w) || (w == 'less' && next() == 'than')) {
      final skip = w == 'less' ? 2 : 1;
      final v = next(skip) == null ? null : money(next(skip)!);
      if (v != null) {
        maxC = v;
        understood('Under ${fmt(v)}', i, skip + 1);
        i += skip;
        continue;
      }
    }
    if (w == 'between' && next(2) == 'and') {
      final a = money(next()!), b = next(3) == null ? null : money(next(3)!);
      if (a != null && b != null) {
        minC = a < b ? a : b;
        maxC = a < b ? b : a;
        understood('${fmt(minC)} to ${fmt(maxC)}', i, 4);
        i += 3;
        continue;
      }
    }
    if ({'unpaid', 'invoiced', 'outstanding'}.contains(w)) {
      unpaid = true;
      understood('Invoiced, unpaid', i, 1);
      continue;
    }
    // Receipts.
    if ({'no', 'without', 'missing'}.contains(w) && (next() == 'receipt' || next() == 'receipts')) {
      receipt = false;
      understood('No receipt', i, 2);
      i++;
      continue;
    }
    if ({'with', 'has', 'have'}.contains(w) && (next() == 'receipt' || next() == 'receipts')) {
      receipt = true;
      understood('Has receipt', i, 2);
      i++;
      continue;
    }
    // Dates.
    if ((w == 'this' || w == 'last') && (next() == 'year' || next() == 'month')) {
      if (next() == 'year') {
        year = today.year - (w == 'last' ? 1 : 0);
        understood('$year', i, 2);
      } else {
        final d = w == 'last' ? DateTime(today.year, today.month - 1) : today;
        year = d.year;
        month = d.month;
        understood('${_monthNames[d.month]} ${d.year}', i, 2);
      }
      i++;
      continue;
    }
    final yr = RegExp(r'^(19|20)\d\d$').hasMatch(w) ? int.parse(w) : null;
    if (yr != null && !w.startsWith(r'$')) {
      year = yr;
      understood('$yr', i, 1);
      continue;
    }
    // Quarters: "q2" = Apr-Jun (calendar quarters, not the IRS payment periods).
    final qm = RegExp(r'^q([1-4])$').firstMatch(w);
    if (qm != null) {
      final q = int.parse(qm[1]!);
      month = q * 3 - 2;
      monthTo = q * 3;
      understood('Q$q (${_monthNames[month]}-${_monthNames[monthTo]})', i, 1);
      continue;
    }
    // Month ranges: "march to may", "mar - may", "jan-mar".
    final dash = RegExp(r'^([a-z]+)-([a-z]+)$').firstMatch(w);
    if (dash != null && _months.containsKey(dash[1]) && _months.containsKey(dash[2])) {
      final a = _months[dash[1]]!, b = _months[dash[2]]!;
      (month, monthTo) = a <= b ? (a, b) : (b, a);
      understood('${_monthNames[month]}-${_monthNames[monthTo]}', i, 1);
      continue;
    }
    if (_months.containsKey(w) &&
        {'to', 'through', 'thru', 'until', '-'}.contains(next()) &&
        next(2) != null &&
        _months.containsKey(next(2))) {
      final a = _months[w]!, b = _months[next(2)]!;
      (month, monthTo) = a <= b ? (a, b) : (b, a);
      understood('${_monthNames[month]}-${_monthNames[monthTo]}', i, 3);
      i += 2;
      continue;
    }
    if (_months.containsKey(w) && !(w == 'may' && month != null)) {
      month = _months[w];
      monthTo = null;
      understood(_monthNames[month!], i, 1);
      continue;
    }
    // Schedule C line: "line 9", "line 27a".
    if (w == 'line' && next() != null && RegExp(r'^\d{1,2}[a-z]?$').hasMatch(next()!)) {
      if (!lines.contains(next()!)) lines.add(next()!);
      understood('Line ${next()}', i, 2);
      i++;
      continue;
    }
    // Expenses that are partly personal.
    if ((w == 'mixed' && next() == 'use') ||
        (w == 'personal' && next() == 'use') ||
        ({'part', 'partly'}.contains(w) && next() == 'personal')) {
      mixed = true;
      understood('Mixed use', i, 2);
      i++;
      continue;
    }
    if (w == 'mixed') {
      mixed = true;
      understood('Mixed use', i, 1);
      continue;
    }
    // Type, fees, categories.
    if ({'income', 'earned', 'sales', 'revenue', 'earnings'}.contains(w)) {
      income = true;
      understood('Income', i, 1);
      continue;
    }
    if ({'expense', 'expenses', 'spent', 'spending', 'bought', 'purchases', 'costs'}.contains(w)) {
      income = false;
      understood('Expenses', i, 1);
      continue;
    }
    if (w == 'fee' || w == 'fees') {
      fees = true;
      understood('Fees', i, 1);
      continue;
    }
    if ({'uncategorized', 'uncategorised', 'uncategorized?', 'misc', 'miscellaneous'}.contains(w)) {
      cats.addAll(const {'other_expense', 'other_income'});
      understood('Uncategorized', i, 1);
      continue;
    }
    final syn = _synonyms[w];
    if (syn != null) {
      if (cats.add(syn)) {
        understood(syn.replaceAll('_', ' '), i, 1);
      } else {
        // Same category twice: removing its chip takes out both words.
        for (final c in chips) {
          if (c.label == syn.replaceAll('_', ' ')) c.words.add(i);
        }
      }
      catWords.add(w);
      continue;
    }
    final amt = money(w);
    if (amt != null) {
      minC = amt;
      maxC = amt;
      understood(fmt(amt), i, 1);
      continue;
    }
    if (w.startsWith('#')) {
      final t = normalizeTags(w).trim();
      if (t.isNotEmpty) {
        if (!tags.contains(t)) tags.add(t);
        understood('#$t', i, 1);
      }
      continue;
    }
    if (_stop.contains(w)) continue;
    terms.add(w);
  }
  return SearchQuery(
    terms: terms,
    minCents: minC,
    maxCents: maxC,
    year: year,
    month: month,
    isIncome: income,
    categories: cats,
    categoryWords: catWords,
    hasReceipt: receipt,
    unpaidOnly: unpaid,
    feesOnly: fees,
    tags: tags,
    monthTo: monthTo,
    lines: lines,
    mixedUse: mixed,
    chips: chips,
    words: words,
  );
}
