// One search bar for everything (SPEC §4): records and documents, natural-language
// filters shown as chips, instant results.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../data/database.dart';
import '../../data/tax_rules.dart';
import '../../search/query_parser.dart';
import '../../search/search_service.dart';
import '../design/components.dart';
import '../design/theme.dart';
import '../shell/tabs.dart';
import '../vault/vault_screens.dart';

Future<void> openSearch(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchScreen()));

class SearchScreen extends ConsumerStatefulWidget {
  /// Pre-filled query (tests, deep links).
  final String initialText;

  /// Replaces the database search (goldens).
  final Future<SearchResults> Function(SearchQuery q)? searchOverride;
  const SearchScreen({super.key, this.initialText = '', this.searchOverride});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _c = TextEditingController();
  SearchQuery _q = const SearchQuery();
  SearchResults _r = SearchResults.empty;
  int _seq = 0;

  static const _examples = ['no receipt > 75', 'meals last month', 'fiverr fees', 'income 2026', 'over 500'];

  @override
  void initState() {
    super.initState();
    if (widget.initialText.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fill(widget.initialText));
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _run(String text) async {
    final db = ref.read(appControllerProvider).db;
    final search = widget.searchOverride ?? (db == null ? null : (SearchQuery q) => runSearch(db, q));
    if (search == null) return;
    final q = parseQuery(text, today: ref.read(todayProvider));
    final seq = ++_seq;
    SearchResults r;
    try {
      r = await search(q);
    } catch (_) {
      r = SearchResults.empty; // fail quiet: a bad query must never crash the screen
    }
    if (mounted && seq == _seq) {
      setState(() {
        _q = q;
        _r = r;
      });
    }
  }

  void _fill(String s) {
    _c.text = s;
    _c.selection = TextSelection.collapsed(offset: s.length);
    _run(s);
  }

  @override
  Widget build(BuildContext context) {
    final rules = {for (final y in TaxRules.supportedYears) y: ref.watch(taxRulesProvider(y)).value};
    final ll = context.ll;
    final typed = _c.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: Space.lg),
          child: TextField(
            controller: _c,
            autofocus: true,
            enableIMEPersonalizedLearning: false,
            textInputAction: TextInputAction.search,
            inputFormatters: [LengthLimitingTextInputFormatter(maxQueryChars)],
            onChanged: _run,
            decoration: InputDecoration(
              hintText: 'Search everything…',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: typed
                  ? IconButton(tooltip: 'Clear', icon: const Icon(Icons.close_rounded), onPressed: () => _fill(''))
                  : null,
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xxl),
        children: [
          if (!typed) ...[
            Text('Try', style: context.text.labelMedium),
            const SizedBox(height: Space.sm),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (final e in _examples)
                  ActionChip(
                    avatar: const Icon(Icons.north_west_rounded, size: 16),
                    label: Text(e),
                    onPressed: () => _fill(e),
                  ),
              ],
            ),
            const SizedBox(height: Space.xl),
            Text(
              'Search payees, notes, platforms and document names. Add words like "over 50", "no receipt", '
              '"march", "last year" or a category ("meals", "software") to filter.',
              style: context.text.bodySmall,
            ),
          ] else ...[
            if (_q.understood.isNotEmpty)
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
                children: [for (final u in _q.understood) Pill(u, icon: Icons.filter_alt_outlined)],
              ),
            SectionHeader(
              'Records',
              trailing: Text(
                '${_r.entries.length}${_r.entries.length == 200 ? '+' : ''} · ${_r.took.inMilliseconds} ms',
                style: context.text.labelMedium,
              ),
            ),
            if (_r.entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.lg),
                child: Text('No matching records.', style: context.text.bodySmall),
              )
            else
              LLGroup(
                children: [
                  for (final e in _r.entries)
                    if (rules[e.day.year] != null)
                      EntryTile(entry: e, rules: rules[e.day.year]!, highlight: [..._q.terms, ..._q.categoryWords]),
                ],
              ),
            if (_r.documents.isNotEmpty) ...[
              SectionHeader('Documents', trailing: Text('${_r.documents.length}', style: context.text.labelMedium)),
              LLGroup(
                children: [
                  for (final a in _r.documents)
                    ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(width: 40, height: 48, child: EncryptedThumb(a, size: 48)),
                      ),
                      title: HighlightText(a.name.isEmpty ? 'Untitled' : a.name, _q.terms, maxLines: 1),
                      subtitle: Text('${a.year} · ${a.folder.replaceAll('_', ' ')}'),
                      trailing: Icon(Icons.chevron_right_rounded, color: ll.muted),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ViewerScreen(a))),
                    ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}
