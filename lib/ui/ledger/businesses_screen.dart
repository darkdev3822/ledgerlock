// Settings > Records > Businesses (SPEC §3: multiple businesses, each with its own books and Schedule C).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../data/database.dart';
import '../design/components.dart';
import '../design/theme.dart';

class BusinessesScreen extends ConsumerWidget {
  const BusinessesScreen({super.key});

  static void _toast(BuildContext context, String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const BusinessNameDialog(title: 'New business', action: 'Add'),
    );
    if (name == null) return;
    final id = await ref.read(appControllerProvider).addBusiness(name);
    if (!context.mounted) return;
    _toast(context, id == null ? 'You already have a business with that name.' : 'Added. Pick it at the top.');
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, Business b) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => BusinessNameDialog(title: 'Rename', action: 'Save', initial: b.name),
    );
    if (name == null) return;
    final ok = await ref.read(appControllerProvider).renameBusiness(b.id, name);
    if (!ok && context.mounted) _toast(context, 'You already have a business with that name.');
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Business b, String main) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Remove "${b.name}"?'),
        content: Text('Its records, trips, 1099s and repeats move to $main. Nothing is deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok == true) await ref.read(appControllerProvider).deleteBusiness(b.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appControllerProvider);
    final year = app.selectedYear;
    final entries = ref.watch(allEntriesProvider(year)).value ?? const <LedgerEntry>[];
    final count = <int, int>{};
    for (final e in entries) {
      count[e.businessId] = (count[e.businessId] ?? 0) + 1;
    }
    final main = app.businessName(AppDatabase.mainBusinessId);
    return Scaffold(
      appBar: AppBar(title: const Text('Businesses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add business'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, 96),
        children: [
          Text(
            'Run more than one side business? Give each its own books. Each one gets its own Schedule C. '
            'Self-employment tax and the amount to set aside are figured on all of them together, because '
            'one Schedule SE covers them all.',
            style: context.text.bodySmall,
          ),
          const SectionHeader('Yours'),
          LLGroup(
            children: [
              for (final b in app.businesses)
                ListTile(
                  leading: Icon(Icons.storefront_outlined, color: context.ll.muted),
                  title: Text(b.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${count[b.id] ?? 0} records in $year'
                    '${b.id == AppDatabase.mainBusinessId ? ' · main (home office counts here)' : ''}',
                  ),
                  onTap: () => _rename(context, ref, b),
                  trailing: b.id == AppDatabase.mainBusinessId
                      ? IconButton(
                          tooltip: 'Rename ${b.name}',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _rename(context, ref, b),
                        )
                      : IconButton(
                          tooltip: 'Remove ${b.name}',
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () => _delete(context, ref, b, main),
                        ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A name prompt that owns its controller (no disposed-controller crash while the route animates out).
class BusinessNameDialog extends StatefulWidget {
  final String title, action, initial;
  const BusinessNameDialog({super.key, required this.title, required this.action, this.initial = ''});
  @override
  State<BusinessNameDialog> createState() => _BusinessNameDialogState();
}

class _BusinessNameDialogState extends State<BusinessNameDialog> {
  late final _name = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = _name.text.trim().isNotEmpty;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _name,
        autofocus: true,
        maxLength: 40,
        textCapitalization: TextCapitalization.words,
        enableIMEPersonalizedLearning: false,
        decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Etsy shop, Tutoring'),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => ok ? Navigator.pop(context, _name.text) : null,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: ok ? () => Navigator.pop(context, _name.text) : null, child: Text(widget.action)),
      ],
    );
  }
}
