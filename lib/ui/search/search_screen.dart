// One search bar for everything (SPEC §4): records and documents, natural-language
// filters shown as chips, instant results.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../data/database.dart';
import '../../data/tax_rules.dart';
import '../../search/query_parser.dart';
import '../../search/search_history.dart';
import '../../search/search_service.dart';
import '../design/components.dart';
import '../design/theme.dart';
import '../shell/tabs.dart';
import '../vault/vault_screens.dart';

Future<void> openSearch(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchScreen()));

/// Pull down past the top of a list to open search (SPEC §4: "pull down on any list"). Counts overscroll during
/// one drag; opens once per drag when it passes [threshold]. Works with Android's clamping scroll.
class PullToSearch extends StatefulWidget {
  final Widget child;
  final double threshold;
  const PullToSearch({super.key, required this.child, this.threshold = 90});
  @override
  State<PullToSearch> createState() => _PullToSearchState();
}

class _PullToSearchState extends State<PullToSearch> {
  double _pulled = 0;
  bool _fired = false;

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    if (n is ScrollStartNotification) {
      _pulled = 0;
      _fired = false;
    } else if (n is OverscrollNotification && n.overscroll < 0 && n.dragDetails != null) {
      _pulled -= n.overscroll;
      if (!_fired && _pulled > widget.threshold) {
        _fired = true;
        HapticFeedback.lightImpact();
        openSearch(context);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(onNotification: _onScroll, child: widget.child);
}

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
  List<String> _recent = const [], _saved = const [];
  Timer? _remember;

  static const _examples = ['no receipt > 75', 'meals last month', 'fiverr fees', 'income 2026', 'over 500'];

  AppDatabase? get _db => widget.searchOverride == null ? ref.read(appControllerProvider).db : null;

  Future<void> _loadHistory() async {
    final db = _db;
    if (db == null) return;
    final r = decodeSearches(await db.getSetting('recentSearches'));
    final s = decodeSearches(await db.getSetting('savedSearches'));
    if (!mounted) return;
    setState(() {
      _recent = r;
      _saved = s;
    });
  }

  /// A query that stayed on screen for 2 s with results is worth remembering (not every keystroke).
  void _scheduleRemember(String text, bool hasResults) {
    _remember?.cancel();
    if (!hasResults || text.trim().isEmpty) return;
    _remember = Timer(const Duration(seconds: 2), () async {
      final db = _db;
      if (db == null || !mounted) return;
      final next = pushSearch(_recent, text);
      setState(() => _recent = next);
      await db.setSetting('recentSearches', encodeSearches(next));
    });
  }

  Future<void> _toggleSaved() async {
    final db = _db;
    final t = _c.text.trim();
    if (db == null || t.isEmpty) return;
    final isSaved = _saved.any((x) => x.toLowerCase() == t.toLowerCase());
    final next = isSaved
        ? _saved.where((x) => x.toLowerCase() != t.toLowerCase()).toList()
        : pushSearch(_saved, t, max: maxSaved);
    setState(() => _saved = next);
    await db.setSetting('savedSearches', encodeSearches(next));
    HapticFeedback.selectionClick();
  }

  Future<void> _clearRecent() async {
    setState(() => _recent = const []);
    await _db?.setSetting('recentSearches', encodeSearches(const []));
  }

  @override
  void initState() {
    super.initState();
    _loadHistory();
    if (widget.initialText.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fill(widget.initialText));
    }
  }

  @override
  void dispose() {
    _remember?.cancel();
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
      _scheduleRemember(text, r.entries.isNotEmpty || r.documents.isNotEmpty);
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
    final savedNow = _saved.any((x) => x.toLowerCase() == _c.text.trim().toLowerCase());
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
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_db != null)
                          IconButton(
                            tooltip: savedNow ? 'Remove from saved' : 'Save this search',
                            icon: Icon(savedNow ? Icons.star_rounded : Icons.star_outline_rounded),
                            color: savedNow ? context.ll.accent : null,
                            onPressed: _toggleSaved,
                          ),
                        IconButton(tooltip: 'Clear', icon: const Icon(Icons.close_rounded), onPressed: () => _fill('')),
                      ],
                    )
                  : null,
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xxl),
        children: [
          if (!typed) ...[
            if (_saved.isNotEmpty) ...[
              Text('Saved', style: context.text.labelMedium),
              const SizedBox(height: Space.sm),
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
                children: [
                  for (final e in _saved)
                    ActionChip(
                      avatar: Icon(Icons.star_rounded, size: 16, color: ll.accent),
                      label: Text(e, maxLines: 1, overflow: TextOverflow.ellipsis),
                      onPressed: () => _fill(e),
                    ),
                ],
              ),
              const SizedBox(height: Space.xl),
            ],
            if (_recent.isNotEmpty) ...[
              Row(
                children: [
                  Expanded(child: Text('Recent', style: context.text.labelMedium)),
                  TextButton(onPressed: _clearRecent, child: const Text('Clear')),
                ],
              ),
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
                children: [
                  for (final e in _recent)
                    ActionChip(
                      avatar: const Icon(Icons.history_rounded, size: 16),
                      label: Text(e, maxLines: 1, overflow: TextOverflow.ellipsis),
                      onPressed: () => _fill(e),
                    ),
                ],
              ),
              const SizedBox(height: Space.xl),
            ],
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
                children: [
                  for (var i = 0; i < _q.chips.length; i++)
                    InputChip(
                      avatar: const Icon(Icons.filter_alt_outlined, size: 16),
                      label: Text(_q.chips[i].label),
                      deleteButtonTooltipMessage: 'Remove filter',
                      onDeleted: () => _fill(_q.without(i)),
                      onPressed: () => _fill(_q.without(i)),
                    ),
                ],
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
