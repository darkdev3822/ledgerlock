// CSV import (SPEC §3): pick a file -> check columns -> review rows -> import. Everything stays in memory
// until the user taps Import; the file itself is never copied into app storage.
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/app_controller.dart';
import '../../data/csv_import.dart';
import '../../data/database.dart';
import '../../platform/document_picker.dart';
import '../design/components.dart';
import '../design/theme.dart';

/// One reviewable row: the parsed data plus the user's choices.
class _Pick {
  final ImportRow row;
  bool include;
  String category;
  int businessPct;
  _Pick(this.row, this.category, this.businessPct) : include = !row.duplicate;
}

class ImportScreen extends ConsumerStatefulWidget {
  /// For tests and goldens: skip the picker.
  final List<List<String>>? initialRows;
  const ImportScreen({super.key, this.initialRows});
  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  List<List<String>>? _rows; // header + data
  ColumnMap _map = const ColumnMap();
  List<int> _skipped = const [];
  List<_Pick>? _review;
  final _source = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialRows != null) _load(widget.initialRows!);
  }

  @override
  void dispose() {
    _source.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    setState(() => _error = null);
    try {
      final f = await ref
          .read(appControllerProvider)
          .picker
          .pick(mimeTypes: const ['text/csv', 'text/comma-separated-values', 'text/plain', 'application/vnd.ms-excel']);
      if (f == null) return;
      final rows = parseCsv(f.bytes);
      if (rows.length < 2) {
        setState(() => _error = 'That file has no rows to import.');
        return;
      }
      await _load(rows);
    } on ImportTooLarge catch (e) {
      setState(() => _error = '$e. Split it into smaller files (one year at a time works well).');
    } on PickTooLarge {
      setState(() => _error = 'That file is too large.');
    } catch (_) {
      setState(() => _error = 'Couldn\'t read that file. Is it a CSV?');
    }
  }

  Future<void> _load(List<List<String>> rows) async {
    final db = ref.read(appControllerProvider).db;
    final saved = db == null ? null : await db.getSetting(headerSignature(rows.first));
    ColumnMap? map;
    try {
      map = saved == null ? null : ColumnMap.fromJson(jsonDecode(saved));
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _map = map ?? guessColumns(rows.first);
      _review = null;
    });
  }

  Future<void> _toReview() async {
    final db = ref.read(appControllerProvider).db;
    final rows = _rows;
    if (db == null || rows == null) return;
    setState(() => _busy = true);
    final data = rows.sublist(1);
    final dates = [for (final r in data) parseImportDate(_map.date < r.length ? r[_map.date] : '')].nonNulls.toList()
      ..sort();
    final existing = dates.isEmpty ? <LedgerEntry>[] : await db.entriesBetween(isoDay(dates.first), isoDay(dates.last));
    final res = buildImport(data, _map, existing: existing);
    final rules = await db.allRules();
    final picks = <_Pick>[];
    for (final r in res.rows) {
      final rule = matchRule(rules, isIncome: r.isIncome, party: r.payee);
      final cat = rule?.category ?? await db.suggestCategory(isIncome: r.isIncome, party: r.payee, anyPayee: false);
      picks.add(
        _Pick(r, cat ?? (r.isIncome ? 'other_income' : 'other_expense'), r.isIncome ? 100 : (rule?.businessPct ?? 100)),
      );
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _skipped = res.skippedLines;
      _review = picks;
    });
  }

  Future<void> _import() async {
    final db = ref.read(appControllerProvider).db;
    final rows = _rows, picks = _review;
    if (db == null || rows == null || picks == null) return;
    final chosen = picks.where((p) => p.include).toList();
    setState(() => _busy = true);
    try {
      await db.addEntries([
        for (final p in chosen)
          LedgerEntriesCompanion.insert(
            isIncome: p.row.isIncome,
            date: isoDay(p.row.date),
            amountCents: p.row.amountCents,
            feeCents: Value(p.row.feeCents),
            businessPct: Value(p.businessPct),
            category: p.category,
            party: Value(p.row.payee),
            platform: Value(_source.text.trim()),
            notes: Value(safeTake(p.row.notes, 200)),
          ),
      ]);
      await db.setSetting(headerSignature(rows.first), jsonEncode(_map.toJson()));
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.of(context).pop();
      showSuccess(messenger, 'Imported ${chosen.length} record${chosen.length == 1 ? '' : 's'}. Find them in Records.');
    } catch (_) {
      if (mounted) setState(() => _error = 'Import failed. Nothing was added.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _rows == null ? 0 : (_review == null ? 1 : 2);
    return Scaffold(
      appBar: AppBar(title: Text(['Import a CSV', 'Check the columns', 'Review'][step])),
      body: switch (step) {
        0 => _pickStep(context),
        1 => _mapStep(context),
        _ => _reviewStep(context),
      },
    );
  }

  Widget _pickStep(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xxl),
    children: [
      Text(
        'Export a CSV from your bank, PayPal, Etsy, Fiverr or similar, then pick it here. It is read on this phone '
        'and nothing is uploaded. You review every row before anything is added.',
        style: context.text.bodyMedium,
      ),
      const SizedBox(height: Space.lg),
      FilledButton.icon(
        onPressed: _pick,
        icon: const Icon(Icons.upload_file_rounded),
        label: const Text('Choose a CSV file'),
      ),
      if (_error != null) ...[
        const SizedBox(height: Space.md),
        Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ],
      const SizedBox(height: Space.lg),
      Text(
        'Tip: after importing, delete the CSV from your Downloads. It isn\'t encrypted.',
        style: context.text.bodySmall,
      ),
    ],
  );

  Widget _mapStep(BuildContext context) {
    final rows = _rows!;
    final header = rows.first;
    Widget pick(String label, int value, ColumnMap Function(int) set, {bool optional = false}) => Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: DropdownButtonFormField<int>(
        key: ValueKey('map-$label'),
        isExpanded: true,
        initialValue: value < header.length ? value : -1,
        decoration: InputDecoration(labelText: label),
        items: [
          DropdownMenuItem(value: -1, child: Text(optional ? 'None' : 'Choose a column')),
          for (final (i, h) in header.indexed)
            DropdownMenuItem(
              value: i,
              child: Text(h.trim().isEmpty ? 'Column ${i + 1}' : h, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (v) => setState(() => _map = set(v ?? -1)),
      ),
    );
    final preview = buildImport(rows.sublist(1, rows.length.clamp(1, 4)), _map);
    final splitMode = _map.amount < 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xxl),
      children: [
        Text('${rows.length - 1} rows found. Match the columns:', style: context.text.bodyMedium),
        const SizedBox(height: Space.md),
        pick('Date', _map.date, (v) => _map.copyWith(date: v)),
        pick('Payee or description', _map.payee, (v) => _map.copyWith(payee: v)),
        pick('Amount (+/-)', _map.amount, (v) => _map.copyWith(amount: v), optional: true),
        if (splitMode) ...[
          pick('Money out (debit)', _map.debit, (v) => _map.copyWith(debit: v), optional: true),
          pick('Money in (credit)', _map.credit, (v) => _map.copyWith(credit: v), optional: true),
        ],
        pick('Fee (optional)', _map.fee, (v) => _map.copyWith(fee: v), optional: true),
        pick('Income or expense column (optional)', _map.kind, (v) => _map.copyWith(kind: v), optional: true),
        pick('Notes (optional)', _map.notes, (v) => _map.copyWith(notes: v), optional: true),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Positive amounts are expenses'),
          subtitle: const Text('Turn on if your purchases show as positive numbers'),
          value: _map.flipSign,
          onChanged: (v) => setState(() => _map = _map.copyWith(flipSign: v)),
        ),
        TextField(
          controller: _source,
          enableIMEPersonalizedLearning: false,
          maxLength: 40,
          decoration: const InputDecoration(
            labelText: 'Platform (optional)',
            helperText: 'Only for platform exports, e.g. PayPal or Etsy. Used to match your 1099s.',
          ),
        ),
        if (_map.fee >= 0)
          Padding(
            padding: const EdgeInsets.only(top: Space.sm),
            child: Text(
              'With a fee column, Amount should be the gross (before fees), or fees get counted twice.',
              style: context.text.bodySmall,
            ),
          ),
        const SectionHeader('Preview'),
        if (preview.rows.isEmpty)
          Text('No rows read yet. Check Date and Amount.', style: context.text.bodySmall)
        else
          LLGroup(children: [for (final r in preview.rows) _rowTile(context, r)]),
        const SizedBox(height: Space.lg),
        FilledButton(
          onPressed: _map.usable && !_busy ? _toReview : null,
          child: Text(_busy ? 'Reading…' : 'Next: review rows'),
        ),
        TextButton(onPressed: () => setState(() => _rows = null), child: const Text('Choose another file')),
      ],
    );
  }

  Widget _rowTile(BuildContext context, ImportRow r, {Widget? leading, String? extra}) => ListTile(
    leading: leading,
    title: Text(r.payee.isEmpty ? '(no description)' : r.payee, maxLines: 1, overflow: TextOverflow.ellipsis),
    subtitle: Text(
      '${DateFormat.yMMMd().format(r.date)} · ${r.isIncome ? 'Income' : 'Expense'}'
      '${r.feeCents > 0 ? ' · fee ${formatCents(r.feeCents)}' : ''}${extra ?? ''}',
    ),
    trailing: MoneyText(r.isIncome ? r.amountCents : -r.amountCents, style: context.text.titleSmall),
  );

  Widget _reviewStep(BuildContext context) {
    final picks = _review!;
    final year = ref.watch(appControllerProvider.select((a) => a.selectedYear));
    final rules = ref.watch(taxRulesProvider(year)).value;
    final n = picks.where((p) => p.include).length;
    final dups = picks.where((p) => p.row.duplicate).length;
    String catName(String id) => rules?.category(id)?.name ?? id;
    Future<void> changeCategory(_Pick p) async {
      if (rules == null) return;
      final cats = p.row.isIncome ? rules.incomeCategories : rules.expenseCategories;
      final v = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (c) => ListView(
          shrinkWrap: true,
          children: [
            for (final cat in cats)
              ListTile(title: Text(cat.name), selected: cat.id == p.category, onTap: () => Navigator.pop(c, cat.id)),
          ],
        ),
      );
      if (v != null) setState(() => p.category = v);
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.lg),
            children: [
              Text(
                [
                  '${picks.length} rows ready.',
                  if (dups > 0)
                    dups == 1
                        ? '1 looks like a record you already have and is unticked.'
                        : '$dups look like records you already have and are unticked.',
                  if (_skipped.isNotEmpty)
                    '${_skipped.length} skipped (no readable date or amount): line${_skipped.length == 1 ? '' : 's'} '
                        '${_skipped.take(6).join(', ')}${_skipped.length > 6 ? '…' : ''}.',
                  'Tap a category to change it.',
                ].join(' '),
                style: context.text.bodySmall,
              ),
              const SizedBox(height: Space.md),
              LLGroup(
                children: [
                  for (final p in picks)
                    InkWell(
                      onTap: () => changeCategory(p),
                      child: _rowTile(
                        context,
                        p.row,
                        extra: ' · ${catName(p.category)}${p.row.duplicate ? ' · already recorded?' : ''}',
                        leading: Checkbox(value: p.include, onChanged: (v) => setState(() => p.include = v ?? false)),
                      ),
                    ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: Space.md),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.md),
            child: Row(
              children: [
                TextButton(onPressed: () => setState(() => _review = null), child: const Text('Back')),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: n > 0 && !_busy ? _import : null,
                    child: Text('Import $n record${n == 1 ? '' : 's'}'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
