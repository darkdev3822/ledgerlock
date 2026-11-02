// Fuzz: receipt OCR text parser (ReDoS / invariants) and the natural-language search parser
// (FTS MATCH must only ever be quoted word tokens, also checked against real SQLCipher FTS5).
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerlock/data/database.dart';
import 'package:ledgerlock/media/receipt_parser.dart';
import 'package:ledgerlock/search/query_parser.dart';
import 'package:ledgerlock/search/search_service.dart';
import 'package:ledgerlock/security/crypto.dart';

import 'fuzz_util.dart';

final today = DateTime(2026, 11, 2);

void main() {
  test('parseReceipt: random text never throws/hangs; outputs respect the documented limits', () {
    final r = Random(10);
    for (var it = 0; it < 6000; it++) {
      final lines = [for (var i = 0; i < r.nextInt(25); i++) fuzzString(r, maxPieces: 10)];
      final text = lines.join(r.nextBool() ? '\n' : '\r\n');
      final g = timed(() => parseReceipt(text, today: today), input: text);
      if (g.merchant != null) expect(g.merchant!.length, lessThanOrEqualTo(40));
      if (g.totalCents != null) expect(g.totalCents, greaterThanOrEqualTo(0));
      if (g.taxCents != null && g.totalCents != null) expect(g.taxCents, lessThan(g.totalCents!), reason: text);
      if (g.date != null) {
        expect(g.date!.isAfter(today.add(const Duration(days: 1))), isFalse);
        expect(today.difference(g.date!).inDays, lessThanOrEqualTo(730));
      }
    }
  });

  test('parseReceipt: pathological OCR shapes stay fast (backtracking probes)', () {
    final probes = [
      '1' * 200000,
      '1,' * 100000,
      '1.' * 100000,
      '\$ ' * 100000,
      ' ' * 200000 + 'x',
      '${'total ' * 30000}12.34',
      '${'1,234' * 30000}.56',
      '${'Jan ' * 30000}5, 2026',
      List.filled(20000, 'TOTAL 1;23 TAX 0: 99').join('\n'),
      '${'a' * 100000} ${'9' * 100000}',
      '\n' * 200000,
      '${'12/' * 50000}2026',
      '${'sub-total ' * 20000}9.99',
    ];
    for (final p in probes) {
      timed(() => parseReceipt(p, today: today), limitMs: 1500, input: p);
    }
  });

  final ftsShape = RegExp(r'^"[\p{L}\p{N}]+"\*(?: (?:AND|OR) "[\p{L}\p{N}]+"\*)*$', unicode: true);

  test('parseQuery: FTS match is only quoted word tokens; caps hold; ranges sane', () {
    final r = Random(11);
    for (var it = 0; it < 20000; it++) {
      final s = fuzzString(r, maxPieces: 40);
      final q = timed(() => parseQuery(s, today: today), input: s);
      for (final m in [q.ftsMatch, q.categoryTextMatch]) {
        if (m != null) expect(ftsShape.hasMatch(m), isTrue, reason: 'input ${s.codeUnits} -> $m');
      }
      expect(q.terms.length + q.categoryWords.length, lessThanOrEqualTo(maxQueryWords));
      if (q.month != null) expect(q.month, inInclusiveRange(1, 12));
      if (q.minCents != null) expect(q.minCents, greaterThanOrEqualTo(0));
    }
  });

  group('runSearch on a real encrypted FTS5 table', () {
    late AppDatabase db;
    late Directory dir;
    setUpAll(() async {
      dir = Directory.systemTemp.createTempSync('fuzz_search');
      db = AppDatabase.open(File('${dir.path}/f.db'), LedgerCrypto.randomBytes(32));
      final r = Random(12);
      for (var i = 0; i < 60; i++) {
        await db.addEntry(
          LedgerEntriesCompanion.insert(
            isIncome: r.nextBool(),
            date: '2026-0${1 + r.nextInt(9)}-1${r.nextInt(9)}',
            amountCents: r.nextInt(100000),
            category: 'supplies',
          ),
        );
      }
    });
    tearDownAll(() async {
      await db.close();
      dir.deleteSync(recursive: true);
    });

    test('random and unicode-only queries never make SQLite throw', () async {
      final r = Random(13);
      // Tokens that unicode61 (remove_diacritics 2) may reduce to nothing: marks, modifier letters, numerals.
      const odd = ['́', 'ʰ', 'ˇ', '²', '½', '٣', 'ǅ', 'ﬁ', 'Ⅻ', '〇', 'ᅟ', 'ꙮ', 'ª', 'ª', '𝔸'];
      final failures = <String>[];
      for (var it = 0; it < 1500; it++) {
        final s = it.isEven
            ? fuzzString(r, maxPieces: 10)
            : List.generate(1 + r.nextInt(3), (_) => odd[r.nextInt(odd.length)]).join(r.nextBool() ? '' : ' ');
        try {
          await runSearch(db, parseQuery(s, today: today));
        } catch (e) {
          failures.add('${s.runes.map((c) => 'U+${c.toRadixString(16)}').join(' ')}: $e');
        }
      }
      expect(failures, isEmpty, reason: failures.take(5).join('\n'));
    });
  });
}
