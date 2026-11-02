// Natural-language search parser (SPEC §4): a small local parser, no AI service.
// "fuel over 50 in 2026", "fiverr fees march", "no receipt > 75", "uncategorized last year".
import '../data/database.dart' show safeTake;

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

  /// Human-readable chips: what the parser understood.
  final List<String> understood;

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
    this.understood = const [],
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
      !feesOnly;

  /// Only text (and maybe a year): documents are worth searching too.
  bool get documentsApply =>
      minCents == null &&
      maxCents == null &&
      categories.isEmpty &&
      !feesOnly &&
      isIncome == null &&
      hasReceipt == null &&
      !unpaidOnly;

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
  final understood = <String>[];
  final cats = <String>{};
  final catWords = <String>[];
  int? minC, maxC, year, month;
  bool? income, receipt;
  var unpaid = false;
  var fees = false;

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
        understood.add('Over ${fmt(v)}');
        i += skip;
        continue;
      }
    }
    if ({'under', 'below', '<', '<='}.contains(w) || (w == 'less' && next() == 'than')) {
      final skip = w == 'less' ? 2 : 1;
      final v = next(skip) == null ? null : money(next(skip)!);
      if (v != null) {
        maxC = v;
        understood.add('Under ${fmt(v)}');
        i += skip;
        continue;
      }
    }
    if (w == 'between' && next(2) == 'and') {
      final a = money(next()!), b = next(3) == null ? null : money(next(3)!);
      if (a != null && b != null) {
        minC = a < b ? a : b;
        maxC = a < b ? b : a;
        understood.add('${fmt(minC)} to ${fmt(maxC)}');
        i += 3;
        continue;
      }
    }
    if ({'unpaid', 'invoiced', 'outstanding'}.contains(w)) {
      unpaid = true;
      understood.add('Invoiced, unpaid');
      continue;
    }
    // Receipts.
    if ({'no', 'without', 'missing'}.contains(w) && (next() == 'receipt' || next() == 'receipts')) {
      receipt = false;
      understood.add('No receipt');
      i++;
      continue;
    }
    if ({'with', 'has', 'have'}.contains(w) && (next() == 'receipt' || next() == 'receipts')) {
      receipt = true;
      understood.add('Has receipt');
      i++;
      continue;
    }
    // Dates.
    if ((w == 'this' || w == 'last') && (next() == 'year' || next() == 'month')) {
      if (next() == 'year') {
        year = today.year - (w == 'last' ? 1 : 0);
        understood.add('$year');
      } else {
        final d = w == 'last' ? DateTime(today.year, today.month - 1) : today;
        year = d.year;
        month = d.month;
        understood.add('${_monthNames[d.month]} ${d.year}');
      }
      i++;
      continue;
    }
    final yr = RegExp(r'^(19|20)\d\d$').hasMatch(w) ? int.parse(w) : null;
    if (yr != null && !w.startsWith(r'$')) {
      year = yr;
      understood.add('$yr');
      continue;
    }
    if (_months.containsKey(w) && !(w == 'may' && month != null)) {
      month = _months[w];
      understood.add(_monthNames[month!]);
      continue;
    }
    // Type, fees, categories.
    if ({'income', 'earned', 'sales', 'revenue', 'earnings'}.contains(w)) {
      income = true;
      understood.add('Income');
      continue;
    }
    if ({'expense', 'expenses', 'spent', 'spending', 'bought', 'purchases', 'costs'}.contains(w)) {
      income = false;
      understood.add('Expenses');
      continue;
    }
    if (w == 'fee' || w == 'fees') {
      fees = true;
      understood.add('Fees');
      continue;
    }
    if ({'uncategorized', 'uncategorised', 'uncategorized?', 'misc', 'miscellaneous'}.contains(w)) {
      cats.addAll(const {'other_expense', 'other_income'});
      understood.add('Uncategorized');
      continue;
    }
    final syn = _synonyms[w];
    if (syn != null) {
      if (cats.add(syn)) understood.add(syn.replaceAll('_', ' '));
      catWords.add(w);
      continue;
    }
    final amt = money(w);
    if (amt != null) {
      minC = amt;
      maxC = amt;
      understood.add(fmt(amt));
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
    understood: understood,
  );
}
