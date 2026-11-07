// Scale: a busy seller (10,000 records in a year, 2,000 receipts). Every screen's maths must stay fast enough to
// run on each rebuild on a mid-range phone. Budgets are ~10x what this machine needs, so they catch regressions
// (accidental O(n^2)) without being flaky.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerlock/app/app_controller.dart';
import 'package:ledgerlock/data/attention.dart';
import 'package:ledgerlock/data/database.dart';
import 'package:ledgerlock/data/insights.dart';
import 'package:ledgerlock/data/tax_rules.dart';
import 'package:ledgerlock/search/query_parser.dart';
import 'package:ledgerlock/search/search_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('10,000 records: load, summaries, insights, attention, search and quick fill stay fast', () async {
    final rules = await TaxRules.load(2026);
    final db = AppDatabase(NativeDatabase.memory(setup: (d) => d.execute('PRAGMA foreign_keys = ON')));
    final cats = rules.expenseCategories.map((c) => c.id).toList();
    await db.transaction(() async {
      for (var i = 0; i < 10000; i++) {
        final income = i % 4 == 0;
        final day = DateTime(2026, 1, 1).add(Duration(days: i % 365));
        await db.addEntry(
          LedgerEntriesCompanion.insert(
            isIncome: income,
            date: isoDay(day),
            amountCents: 100 + (i * 7919) % 50000,
            category: income ? 'gross_receipts' : cats[i % cats.length],
            party: Value('Party ${i % 300}'),
            platform: Value(i % 5 == 0 ? 'Etsy' : ''),
            notes: Value('order #$i'),
            paid: Value(!(income && i % 40 == 0)),
            tags: Value(i % 9 == 0 ? ' client-a ' : ''),
            businessId: Value(1 + i % 2),
          ),
        );
      }
    });
    for (var i = 0; i < 2000; i++) {
      await db.addAttachment(
        AttachmentsCompanion.insert(
          folder: 'receipt',
          year: 2026,
          entryId: Value(i * 5 + 1),
          fileId: 'f$i',
          mime: 'image/jpeg',
          sizeBytes: 1,
        ),
      );
    }

    Future<T> timed<T>(String what, int budgetMs, Future<T> Function() f) async {
      final sw = Stopwatch()..start();
      final r = await f();
      sw.stop();
      // ignore: avoid_print
      print('$what: ${sw.elapsedMilliseconds} ms');
      expect(sw.elapsedMilliseconds, lessThan(budgetMs), reason: what);
      return r;
    }

    final entries = await timed('watchYear', 3000, () => db.watchYear(2026).first);
    expect(entries.length, 10000);
    final last = await db.watchYear(2025).first;
    for (var i = 0; i < 2; i++) {
      businessSummary(rules, entries, const []); // warm up the JIT: the budget is for steady state
      yearInsights(2026, entries.map((e) => e.data), last.map((e) => e.data), DateTime(2026, 11, 1));
    }
    await timed('businessSummary x3', 250, () async {
      for (final v in [0, 1, 2]) {
        businessSummary(rules, entries, const [], view: v);
      }
    });
    await timed(
      'insights',
      1500,
      () async => yearInsights(2026, entries.map((e) => e.data), last.map((e) => e.data), DateTime(2026, 11, 1)),
    );
    final linked = await timed('linked ids', 1500, () => db.watchLinkedEntryIds().first);
    await timed(
      'attention',
      1000,
      () async => attentionItems(entries: entries, withReceipt: linked, forms: const [], today: DateTime(2026, 11, 1)),
    );
    for (final q in ['etsy', 'no receipt > 75', 'party 12 over 50 q2', '#client-a', 'unpaid', 'order']) {
      await timed('search "$q"', 3000, () => runSearch(db, parseQuery(q, today: DateTime(2026, 11, 1))));
    }
    await timed('frequentEntries', 2000, () => db.frequentEntries(isIncome: false, since: '2025-11-01'));
    await timed(
      'bulk edit 2,000',
      5000,
      () => db.editEntries(entries.take(2000).map((e) => e.id), (e) => e.copyWith(tags: ' bulk ')),
    );
    await db.close();
  }, timeout: const Timeout(Duration(minutes: 5)));
}
