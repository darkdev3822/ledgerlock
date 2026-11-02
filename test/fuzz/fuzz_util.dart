// Shared helpers for the fuzz suite (seeded, reproducible, time-boxed).
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

/// Fails if one call takes longer than [limitMs]. Returns the call's result.
T timed<T>(T Function() f, {int limitMs = 200, Object? input}) {
  final sw = Stopwatch()..start();
  final r = f();
  sw.stop();
  if (sw.elapsedMilliseconds > limitMs) {
    fail('took ${sw.elapsedMilliseconds} ms (> $limitMs ms) on input: ${_show(input)}');
  }
  return r;
}

String _show(Object? o) {
  final s = o.toString();
  return s.length > 300 ? '${s.substring(0, 300)}... (${s.length} chars)' : s;
}

const _pieces = [
  'a',
  'Z',
  '0',
  '9',
  '1',
  ' ',
  '  ',
  '\t',
  '\r',
  '\n',
  '\r\n',
  ',',
  ';',
  '"',
  '""',
  "'",
  '=',
  '+',
  '-',
  '@',
  '\$',
  '.',
  '(',
  ')',
  '/',
  ':',
  '*',
  '<',
  '>',
  '>=',
  'é',
  'ß',
  'İ',
  '漢',
  '😀',
  '\u200b',
  '\u202e',
  '\u0301',
  '\u0000',
  '\ufeff',
  '½',
  '²',
  '٣',
  'NEAR',
  'AND',
  'OR',
  'NOT',
  'total',
  'tax',
  'TOTAL DUE',
  'over',
  'under',
  'between',
  'and',
  'than',
  'more',
  'last',
  'this',
  'year',
  'month',
  'may',
  'jan',
  '2026',
  '1999',
  '12.34',
  '1,234.56',
  'receipt',
  'no',
  'fees',
  'ad',
  'meals',
  'Jan 5, 2026',
  '03/04/2026',
  '2026-02-29',
  '(12.00)',
];

/// Random string built from "interesting" pieces and random code units.
String fuzzString(Random r, {int maxPieces = 12}) {
  final n = r.nextInt(maxPieces + 1);
  final b = StringBuffer();
  for (var i = 0; i < n; i++) {
    switch (r.nextInt(5)) {
      case 0:
        b.writeCharCode(32 + r.nextInt(95));
      case 1:
        b.writeCharCode(r.nextInt(0x3000));
      default:
        b.write(_pieces[r.nextInt(_pieces.length)]);
    }
  }
  return b.toString();
}
