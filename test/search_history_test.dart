import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerlock/search/search_history.dart';

void main() {
  test('newest first, case-insensitive dedupe, whitespace tidied, capped', () {
    var l = <String>[];
    for (final q in ['fuel', 'meals  last month', 'FUEL', '   ', 'x' * 500]) {
      l = pushSearch(l, q);
    }
    expect(l.length, 3);
    expect(l[0].length, 200);
    expect(l.sublist(1), ['FUEL', 'meals last month']);
    for (var i = 0; i < 20; i++) {
      l = pushSearch(l, 'q$i');
    }
    expect(l.length, maxRecent);
    expect(l.first, 'q19');
  });

  test('decode survives junk', () {
    expect(decodeSearches(null), isEmpty);
    expect(decodeSearches('not json'), isEmpty);
    expect(decodeSearches('{"a":1}'), isEmpty);
    expect(decodeSearches('["ok", 3, "", null, "fine"]'), ['ok', 'fine']);
    expect(decodeSearches(encodeSearches(['a "b"', 'c,d'])), ['a "b"', 'c,d']);
  });
}
