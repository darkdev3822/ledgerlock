// Executes a parsed query against the encrypted DB (FTS5 + filters). All values are bound
// parameters; the FTS expression comes only from SearchQuery.ftsMatch (sanitised).
import 'package:drift/drift.dart';

import '../data/database.dart';
import 'query_parser.dart';

class SearchResults {
  final List<LedgerEntry> entries;
  final List<Attachment> documents;
  final Duration took;
  const SearchResults(this.entries, this.documents, this.took);
  static const empty = SearchResults([], [], Duration.zero);
}

/// [lineCategories]: Schedule C line -> category ids (from the year rules, custom categories included), for "line 9".
Future<SearchResults> runSearch(
  AppDatabase db,
  SearchQuery q, {
  int limit = 200,
  Map<String, Set<String>> lineCategories = const {},
}) async {
  if (q.isEmpty) return SearchResults.empty;
  final sw = Stopwatch()..start();
  final where = <String>[];
  final args = <Variable>[];
  final match = q.ftsMatch;
  if (match != null) {
    where.add('e.id IN (SELECT rowid FROM search_fts WHERE search_fts MATCH ? AND rowid > 0)');
    args.add(Variable.withString(match));
  }
  Variable<String> mm(int m) => Variable.withString(m.toString().padLeft(2, '0'));
  if (q.month != null && q.monthTo != null) {
    where.add('substr(e.date, 6, 2) BETWEEN ? AND ?');
    args.addAll([mm(q.month!), mm(q.monthTo!)]);
    if (q.year != null) {
      where.add('e.date LIKE ?');
      args.add(Variable.withString('${q.year}-%'));
    }
  } else if (q.year != null) {
    where.add('e.date LIKE ?');
    args.add(
      Variable.withString(q.month == null ? '${q.year}-%' : '${q.year}-${q.month.toString().padLeft(2, '0')}-%'),
    );
  } else if (q.month != null) {
    where.add('substr(e.date, 6, 2) = ?');
    args.add(Variable.withString(q.month.toString().padLeft(2, '0')));
  }
  if (q.isIncome != null) {
    where.add('e.is_income = ?');
    args.add(Variable.withBool(q.isIncome!));
  }
  if (q.minCents != null) {
    where.add('e.amount_cents >= ?');
    args.add(Variable.withInt(q.minCents!));
  }
  if (q.maxCents != null) {
    where.add('e.amount_cents <= ?');
    args.add(Variable.withInt(q.maxCents!));
  }
  if (q.categories.isNotEmpty) {
    final inCats = 'e.category IN (${List.filled(q.categories.length, '?').join(', ')})';
    args.addAll(q.categories.map(Variable.withString));
    final text = q.categoryTextMatch;
    if (text == null) {
      where.add(inCats);
    } else {
      where.add('($inCats OR e.id IN (SELECT rowid FROM search_fts WHERE search_fts MATCH ? AND rowid > 0))');
      args.add(Variable.withString(text));
    }
  }
  if (q.lines.isNotEmpty) {
    final cats = {for (final l in q.lines) ...?lineCategories[l]};
    if (cats.isEmpty) {
      where.add('0'); // a line with no categories: nothing matches
    } else {
      where.add('e.category IN (${List.filled(cats.length, '?').join(', ')})');
      args.addAll(cats.map(Variable.withString));
    }
  }
  if (q.mixedUse) where.add('(e.is_income = 0 AND e.business_pct < 100)');
  for (final t in q.tags) {
    where.add('instr(e.tags, ?) > 0'); // stored ' a b ': exact tag, no LIKE wildcards
    args.add(Variable.withString(' $t '));
  }
  if (q.unpaidOnly) where.add('(e.is_income = 1 AND e.paid = 0)');
  if (q.feesOnly) where.add("(e.fee_cents > 0 OR e.category = 'platform_fees')");
  if (q.hasReceipt != null) {
    where.add('${q.hasReceipt! ? '' : 'NOT '}EXISTS (SELECT 1 FROM attachments a WHERE a.entry_id = e.id)');
  }
  // Only punctuation typed: nothing to constrain on, so no results (and no empty WHERE).
  if (where.isEmpty) return SearchResults(const [], const [], sw.elapsed);
  final rows = await db
      .customSelect(
        'SELECT e.* FROM ledger_entries e WHERE ${where.join(' AND ')} '
        'ORDER BY e.date DESC, e.id DESC LIMIT $limit',
        variables: args,
        readsFrom: {db.ledgerEntries, db.attachments},
      )
      .get();
  final entries = [for (final r in rows) db.ledgerEntries.map(r.data)];

  var docs = <Attachment>[];
  if (match != null && q.documentsApply) {
    final dargs = <Variable>[Variable.withString(match)];
    var dsql =
        'SELECT a.* FROM attachments a WHERE a.id IN '
        '(SELECT -rowid FROM search_fts WHERE search_fts MATCH ? AND rowid < 0)';
    if (q.year != null) {
      dsql += ' AND a.year = ?';
      dargs.add(Variable.withInt(q.year!));
    }
    final drows = await db
        .customSelect('$dsql ORDER BY a.created_at DESC LIMIT 50', variables: dargs, readsFrom: {db.attachments})
        .get();
    docs = [for (final r in drows) db.attachments.map(r.data)];
  }
  return SearchResults(entries, docs, sw.elapsed);
}
