import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerlock/data/database.dart';
import 'package:ledgerlock/search/query_parser.dart';
import 'package:ledgerlock/search/search_service.dart';
import 'package:ledgerlock/security/crypto.dart';

final today = DateTime(2026, 11, 1);
SearchQuery p(String s) => parseQuery(s, today: today);

void main() {
  group('parser (SPEC §4 examples)', () {
    test('fuel over 50 in 2026', () {
      final q = p('fuel over 50 in 2026');
      expect(q.terms, ['fuel']);
      expect(q.minCents, 5000);
      expect(q.year, 2026);
    });
    test('fiverr fees march', () {
      final q = p('fiverr fees march');
      expect(q.terms, ['fiverr']);
      expect(q.feesOnly, isTrue);
      expect(q.month, 3);
    });
    test('no receipt > 75', () {
      final q = p('no receipt > 75');
      expect(q.hasReceipt, isFalse);
      expect(q.minCents, 7500);
      expect(q.terms, isEmpty);
    });
    test('uncategorized last year', () {
      final q = p('uncategorized last year');
      expect(q.categories, {'other_expense', 'other_income'});
      expect(q.year, 2025);
    });
    test('unpaid / invoiced', () {
      final q = p('unpaid etsy');
      expect(q.unpaidOnly, isTrue);
      expect(q.terms, ['etsy']);
      expect(q.documentsApply, isFalse);
    });

    test('synonyms, ranges, exact amounts, last month', () {
      expect(p('lunch').categories, {'meals'});
      final b = p('between 20 and 10');
      expect((b.minCents, b.maxCents), (1000, 2000));
      expect(p(r'$42.50').minCents, 4250);
      expect(p(r'$42.50').maxCents, 4250);
      final lm = p('expenses last month');
      expect((lm.year, lm.month, lm.isIncome), (2026, 10, false));
      expect(p('income under \$1,000').maxCents, 100000);
      expect(p('>75').minCents, 7500);
      expect(p('').isEmpty, isTrue);
    });
  });

  group('FTS input safety (SECURITY.md T6)', () {
    test('ftsMatch only ever contains quoted word tokens', () {
      for (final evil in [
        '"',
        '"*',
        'a" OR 1=1 --',
        'NEAR(a b)',
        'col:value',
        '-x',
        '((((',
        'a*b',
        "'; DROP TABLE x; --",
        '\u0000',
        'café',
        '^start',
        '{a b}',
        'AND OR NOT',
      ]) {
        final m = p(evil).ftsMatch;
        if (m != null) {
          expect(
            RegExp(r'^("[\p{L}\p{N}]+"\*)( AND "[\p{L}\p{N}]+"\*)*$', unicode: true).hasMatch(m),
            isTrue,
            reason: '$evil -> $m',
          );
        }
      }
    });
  });

  group('search over the encrypted DB', () {
    late Directory dir;
    late AppDatabase db;
    setUpAll(() async {
      dir = Directory.systemTemp.createTempSync('ll_search');
      db = AppDatabase.open(File('${dir.path}/s.db'), LedgerCrypto.randomBytes(32));
      final r = Random(7);
      const parties = [
        'Shell',
        'Chevron',
        'Adobe',
        'Staples',
        'Fiverr',
        'Etsy',
        'Delta',
        'Cafe Uno',
        'Verizon',
        'Udemy',
      ];
      const cats = [
        'other_expense',
        'other_expense',
        'software',
        'supplies',
        'services',
        'product_sales',
        'travel',
        'meals',
        'utilities',
        'education',
      ];
      await db.batch((b) {
        for (var i = 0; i < 10000; i++) {
          final k = r.nextInt(parties.length);
          final income = cats[k] == 'services' || cats[k] == 'product_sales';
          b.insert(
            db.ledgerEntries,
            LedgerEntriesCompanion.insert(
              isIncome: income,
              date:
                  '${2025 + r.nextInt(2)}-${(1 + r.nextInt(12)).toString().padLeft(2, '0')}-${(1 + r.nextInt(28)).toString().padLeft(2, '0')}',
              amountCents: 100 + r.nextInt(30000),
              feeCents: Value(income ? r.nextInt(500) : 0),
              category: cats[k],
              party: Value(parties[k]),
              notes: Value(k < 2 ? 'fuel for client trip' : ''),
            ),
          );
        }
      });
      final firstShell =
          (await db.customSelect("SELECT id FROM ledger_entries WHERE party = 'Shell' LIMIT 1").getSingle()).read<int>(
            'id',
          );
      await db.addAttachment(
        AttachmentsCompanion.insert(
          folder: 'receipt',
          year: 2026,
          entryId: Value(firstShell),
          fileId: 'a' * 32,
          name: const Value('Shell receipt'),
          mime: 'image/jpeg',
          sizeBytes: 1,
        ),
      );
      await db.addAttachment(
        AttachmentsCompanion.insert(
          folder: 'tax_form',
          year: 2026,
          fileId: 'b' * 32,
          name: const Value('Fiverr 1099-K'),
          mime: 'application/pdf',
          sizeBytes: 1,
        ),
      );
    });
    tearDownAll(() async {
      await db.close();
      dir.deleteSync(recursive: true);
    });

    test('results respect every filter', () async {
      final r = await runSearch(db, p('fuel over 50 in 2026'));
      expect(r.entries, isNotEmpty);
      for (final e in r.entries) {
        expect(e.notes, contains('fuel'));
        expect(e.amountCents, greaterThanOrEqualTo(5000));
        expect(e.date, startsWith('2026-'));
      }
      final fees = await runSearch(db, p('fiverr fees march'));
      expect(
        fees.entries.every((e) => e.party == 'Fiverr' && e.date.substring(5, 7) == '03' && e.feeCents > 0),
        isTrue,
      );
      final noRec = await runSearch(db, p('shell no receipt'));
      final withRec = await runSearch(db, p('shell with receipt'));
      expect(withRec.entries.length, 1);
      expect(noRec.entries.any((e) => e.id == withRec.entries.single.id), isFalse);
      expect((await runSearch(db, p('cafe'))).entries.every((e) => e.party == 'Cafe Uno'), isTrue);
    });

    test('documents are found by name; text-only queries include them', () async {
      final r = await runSearch(db, p('fiverr 2026'));
      expect(r.documents.map((d) => d.name), contains('Fiverr 1099-K'));
      expect((await runSearch(db, p('fiverr over 10'))).documents, isEmpty);
    });

    test('a keyword prefix still matches text as you type ("ad" -> Adobe)', () async {
      final r = await runSearch(db, p('ad'));
      expect(r.entries, isNotEmpty);
      expect(r.entries.every((e) => e.party == 'Adobe' || e.category == 'advertising'), isTrue);
      final meals = await runSearch(db, p('meals'));
      expect(meals.entries.every((e) => e.category == 'meals'), isTrue);
      expect(meals.entries, isNotEmpty);
    });

    test('hostile input never throws', () async {
      for (final evil in [
        '"',
        'a" OR 1=1 --',
        'NEAR(a b)',
        '((((',
        "'; DROP TABLE ledger_entries; --",
        '*',
        '-',
        List.filled(5000, 'ab').join(' '), // pasted wall of text (T7)
        '9' * 5000,
      ]) {
        await runSearch(db, p(evil));
      }
      expect(p(List.filled(5000, 'ab').join(' ')).terms.length, lessThanOrEqualTo(maxQueryWords));
      expect((await db.customSelect('SELECT count(*) AS c FROM ledger_entries').getSingle()).read<int>('c'), 10000);
    });

    test('< 50 ms on 10k records (SPEC §4)', () async {
      await runSearch(db, p('warm up'));
      for (final q in [
        'shell',
        'fuel over 50 in 2026',
        'fiverr fees march',
        'no receipt > 75',
        'meals last year',
        'ad',
      ]) {
        final r = await runSearch(db, p(q));
        // ignore: avoid_print
        print('"$q": ${r.entries.length} results in ${r.took.inMilliseconds} ms');
        expect(r.took.inMilliseconds, lessThan(50), reason: q);
      }
    });
  });
}
