// Recent and saved searches (SPEC §4). Kept as settings inside the encrypted DB, never anywhere else.
import 'dart:convert';

import 'query_parser.dart' show maxQueryChars;
import '../data/database.dart' show safeTake;

const maxRecent = 8, maxSaved = 12;

/// [q] moved to the front of [list] (case-insensitive duplicates removed), trimmed to [max].
List<String> pushSearch(List<String> list, String q, {int max = maxRecent}) {
  final t = safeTake(q.trim().replaceAll(RegExp(r'\s+'), ' '), maxQueryChars);
  if (t.isEmpty) return list;
  return [t, ...list.where((x) => x.toLowerCase() != t.toLowerCase())].take(max).toList();
}

List<String> decodeSearches(String? json) {
  try {
    return [
      for (final x in jsonDecode(json ?? '[]') as List)
        if (x is String && x.trim().isNotEmpty) safeTake(x, maxQueryChars),
    ];
  } catch (_) {
    return [];
  }
}

String encodeSearches(List<String> list) => jsonEncode(list);
