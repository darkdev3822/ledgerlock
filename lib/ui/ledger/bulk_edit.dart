// Records selection (long-press a record): change category, add a tag, move to another business or delete several
// records at once. Every action is one transaction and can be undone from the snackbar.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../data/database.dart';
import '../../data/tax_rules.dart';
import '../design/components.dart';
import '../design/theme.dart';
import 'category_icons.dart';

/// Cash basis: income counts on the day it's received, which can be a later tax year than the invoice. Asks when the
/// money arrived. Returns null if cancelled; `(date: null)` = keep each invoice date.
Future<({DateTime? date})?> askReceivedDate(
  BuildContext context, {
  required DateTime today,
  required DateTime invoiced,
  int count = 1,
}) {
  final d = DateFormat.yMMMd();
  final day = DateTime(today.year, today.month, today.day);
  return showModalBottomSheet<({DateTime? date})>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            child: Text('When did the money arrive?', style: c.text.titleMedium),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.xs, Space.lg, Space.sm),
            child: Text(
              'Income counts on the day you receive it, which can be in a later tax year than the invoice.',
              style: c.text.bodySmall,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.today_rounded),
            title: Text('Today, ${d.format(day)}'),
            onTap: () => Navigator.pop(c, (date: day)),
          ),
          ListTile(
            leading: const Icon(Icons.event_outlined),
            title: const Text('Pick the date'),
            onTap: () async {
              final p = await showDatePicker(
                context: c,
                initialDate: day,
                firstDate: invoiced.isAfter(day) ? day : invoiced,
                lastDate: day,
              );
              if (p != null && c.mounted) Navigator.pop(c, (date: p));
            },
          ),
          ListTile(
            leading: const Icon(Icons.history_rounded),
            title: Text(count == 1 ? 'On the invoice date, ${d.format(invoiced)}' : 'On each invoice date'),
            onTap: () => Navigator.pop(c, (date: null)),
          ),
          const SizedBox(height: Space.sm),
        ],
      ),
    ),
  );
}

/// The floating bar shown while records are selected.
class SelectionBar extends ConsumerWidget {
  final List<LedgerEntry> selected;
  final int total;
  final TaxRules rules;
  final VoidCallback onSelectAll, onClear;
  const SelectionBar({
    super.key,
    required this.selected,
    required this.total,
    required this.rules,
    required this.onSelectAll,
    required this.onClear,
  });

  static String _records(int n) => '$n record${n == 1 ? '' : 's'}';

  Future<void> _edit(BuildContext context, WidgetRef ref, String done, LedgerEntry Function(LedgerEntry) change) async {
    final db = ref.read(appControllerProvider).db;
    if (db == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final before = await db.editEntries(selected.map((e) => e.id), change);
    HapticFeedback.mediumImpact();
    onClear();
    showUndo(messenger, '$done ${_records(before.length)}', () => db.replaceEntries(before));
  }

  Future<void> _category(BuildContext context, WidgetRef ref) async {
    final kinds = selected.map((e) => e.isIncome).toSet();
    if (kinds.length > 1) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select only income or only expenses to change the category.')));
      return;
    }
    final income = kinds.single;
    final cats = income ? rules.incomeCategories : rules.expenseCategories;
    final id = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * 0.7),
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.sm),
                child: Text('Category for ${_records(selected.length)}', style: c.text.titleMedium),
              ),
              for (final cat in cats)
                ListTile(
                  leading: Icon(categoryIcon(cat.id)),
                  title: Text(cat.name),
                  subtitle: Text('Schedule C line ${cat.line}'),
                  onTap: () => Navigator.pop(c, cat.id),
                ),
            ],
          ),
        ),
      ),
    );
    if (id == null || !context.mounted) return;
    await _edit(context, ref, 'Changed', (e) => e.copyWith(category: id));
  }

  Future<void> _tag(BuildContext context, WidgetRef ref) async {
    final tag = await showDialog<String>(context: context, builder: (_) => const _TagDialog());
    final t = normalizeTags(tag ?? '').trim();
    if (t.isEmpty || !context.mounted) return;
    final first = t.split(' ').first;
    await _edit(context, ref, 'Tagged', (e) => e.copyWith(tags: normalizeTags('${e.tags} $first')));
  }

  Future<void> _business(BuildContext context, WidgetRef ref) async {
    final app = ref.read(appControllerProvider);
    final id = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Move ${_records(selected.length)} to', style: c.text.titleMedium),
            const SizedBox(height: Space.sm),
            for (final b in app.businesses)
              ListTile(
                leading: const Icon(Icons.storefront_outlined),
                title: Text(b.name),
                onTap: () => Navigator.pop(c, b.id),
              ),
          ],
        ),
      ),
    );
    if (id == null || !context.mounted) return;
    await _edit(context, ref, 'Moved', (e) => e.copyWith(businessId: id));
  }

  Future<void> _received(BuildContext context, WidgetRef ref) async {
    final first = selected.map((e) => e.day).reduce((a, b) => a.isBefore(b) ? a : b);
    final r = await askReceivedDate(context, today: ref.read(todayProvider), invoiced: first, count: selected.length);
    if (r == null || !context.mounted) return;
    final date = r.date;
    await _edit(
      context,
      ref,
      'Marked received:',
      (e) => e.copyWith(paid: true, date: date == null ? e.date : isoDay(date)),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final db = ref.read(appControllerProvider).db;
    if (db == null) return;
    final n = selected.length;
    if (n > 1) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text('Delete ${_records(n)}?'),
          content: const Text('Their receipts stay in the Vault as unmatched. You can undo right after.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Keep')),
            FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Delete')),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final gone = await db.deleteEntries(selected.map((e) => e.id));
    HapticFeedback.mediumImpact();
    onClear();
    showUndo(messenger, 'Deleted ${_records(gone.length)}', () => db.restoreEntries(gone));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final multi = ref.watch(appControllerProvider.select((a) => a.multiBusiness));
    final ll = context.ll;
    Widget action(IconData icon, String label, VoidCallback onTap) => Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.input),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22),
              const SizedBox(height: 2),
              Text(label, style: context.text.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
    return Material(
      color: ll.surface,
      elevation: 6,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(Radii.card),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.xs, Space.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${selected.length} selected',
                    style: context.text.titleSmall,
                    semanticsLabel: '${_records(selected.length)} selected',
                  ),
                ),
                if (selected.length < total) TextButton(onPressed: onSelectAll, child: Text('Select all $total')),
                IconButton(tooltip: 'Cancel selection', icon: const Icon(Icons.close_rounded), onPressed: onClear),
              ],
            ),
            Row(
              children: [
                if (selected.every((e) => e.isIncome && !e.paid))
                  action(Icons.price_check_rounded, 'Received', () => _received(context, ref)),
                action(Icons.category_outlined, 'Category', () => _category(context, ref)),
                action(Icons.sell_outlined, 'Tag', () => _tag(context, ref)),
                if (multi) action(Icons.storefront_outlined, 'Business', () => _business(context, ref)),
                action(Icons.delete_outline_rounded, 'Delete', () => _delete(context, ref)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TagDialog extends StatefulWidget {
  const _TagDialog();
  @override
  State<_TagDialog> createState() => _TagDialogState();
}

class _TagDialogState extends State<_TagDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = normalizeTags(_c.text).isNotEmpty;
    return AlertDialog(
      title: const Text('Add a tag'),
      content: TextField(
        controller: _c,
        autofocus: true,
        maxLength: 24,
        enableIMEPersonalizedLearning: false,
        decoration: const InputDecoration(labelText: 'Tag', hintText: 'e.g. client-a, trip-chicago', prefixText: '#'),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => ok ? Navigator.pop(context, _c.text) : null,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: ok ? () => Navigator.pop(context, _c.text) : null, child: const Text('Add')),
      ],
    );
  }
}
