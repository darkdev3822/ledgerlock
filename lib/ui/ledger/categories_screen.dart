// Settings > Records > Your categories (SPEC §3 custom categories). Each counts as a built-in category.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../data/tax_rules.dart';
import '../design/components.dart';
import '../design/theme.dart';
import 'category_icons.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref, TaxRules rules) async {
    final r = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _AddCategoryDialog(rules: rules),
    );
    if (r == null) return;
    final ok = await ref.read(appControllerProvider).addCustomCategory(r.$1, r.$2);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('You already have a category with that name.')));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, CustomCategory c, String baseName) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Delete "${c.name}"?'),
        content: Text('Its records, repeats and rules move to $baseName. Nothing is deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await ref.read(appControllerProvider).deleteCustomCategory(c);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(appControllerProvider.select((a) => a.selectedYear));
    final custom = ref.watch(appControllerProvider.select((a) => a.customCategories));
    final rules = ref.watch(taxRulesProvider(year)).value;
    final ll = context.ll;
    return Scaffold(
      appBar: AppBar(title: const Text('Your categories')),
      floatingActionButton: rules == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _add(context, ref, rules),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add category'),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, 96),
        children: [
          Text(
            'Name things your way, like "Studio rent" or "Camera gear". Each one counts as a standard category, '
            'so it lands on the right Schedule C line.',
            style: context.text.bodySmall,
          ),
          const SectionHeader('Yours'),
          if (custom.isEmpty)
            const EmptyState(
              icon: Icons.label_outline_rounded,
              title: 'No categories of your own yet',
              body: 'The standard ones cover every Schedule C line. Add your own when a name helps you.',
            )
          else
            LLGroup(
              children: [
                for (final c in custom)
                  Builder(
                    builder: (context) {
                      final base = rules?.category(c.baseId);
                      final baseName = base?.name ?? c.baseId;
                      return ListTile(
                        leading: Icon(categoryIcon(c.baseId), color: ll.muted),
                        title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          base == null
                              ? 'Counts as $baseName (not in $year rules)'
                              : '${base.isIncome ? 'Income' : 'Expense'} · counts as $baseName · line ${base.line}',
                        ),
                        trailing: IconButton(
                          tooltip: 'Delete ${c.name}',
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () => _delete(context, ref, c, baseName),
                        ),
                      );
                    },
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _AddCategoryDialog extends StatefulWidget {
  final TaxRules rules;
  const _AddCategoryDialog({required this.rules});
  @override
  State<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<_AddCategoryDialog> {
  final _name = TextEditingController();
  String? _base;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final builtIn = [
      for (final c in [...widget.rules.expenseCategories, ...widget.rules.incomeCategories])
        if (!c.id.startsWith('custom_')) c,
    ];
    final ok = _name.text.trim().isNotEmpty && _base != null;
    return AlertDialog(
      title: const Text('New category'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            maxLength: 40,
            textCapitalization: TextCapitalization.sentences,
            enableIMEPersonalizedLearning: false,
            decoration: const InputDecoration(labelText: 'Name'),
            onChanged: (_) => setState(() {}),
          ),
          DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Counts as', helperText: 'Sets the Schedule C line'),
            items: [
              for (final c in builtIn)
                DropdownMenuItem(value: c.id, child: Text('${c.isIncome ? 'Income' : 'Expense'} · ${c.name}')),
            ],
            onChanged: (v) => setState(() => _base = v),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: ok ? () => Navigator.pop(context, (_name.text, _base!)) : null,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
