// Settings > Records > Repeating records: what repeats, how often, when next, and Stop.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/app_controller.dart';
import '../../data/database.dart';
import '../../data/recurring.dart';
import '../design/components.dart';
import '../design/theme.dart';
import 'category_icons.dart';

class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  Future<void> _stop(BuildContext context, WidgetRef ref, Recurring r, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Stop "$name"?'),
        content: const Text('No new copies will be added. Records already made stay in your books.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Stop')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(appControllerProvider).db?.stopRecurring(r.id);
    if (context.mounted) showSuccess(ScaffoldMessenger.maybeOf(context), 'Stopped. Records already made stay.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(appControllerProvider.select((a) => a.selectedYear));
    final rules = ref.watch(taxRulesProvider(year)).value;
    final list = ref.watch(recurringProvider).value ?? const <Recurring>[];
    final ll = context.ll;
    return Scaffold(
      appBar: AppBar(title: const Text('Repeating records')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xxl),
        children: [
          Text(
            'To add one, make a record and set "Repeats". A copy is added on each date when you open LedgerLock, '
            'including dates you missed while the app was closed.',
            style: context.text.bodySmall,
          ),
          const SectionHeader('Repeating'),
          if (list.isEmpty)
            const EmptyState(
              icon: Icons.repeat_rounded,
              title: 'Nothing repeats yet',
              body: 'Good for subscriptions, a phone plan, rent share or a regular client.',
            )
          else
            LLGroup(
              children: [
                for (final r in list)
                  Builder(
                    builder: (context) {
                      final cat = rules?.category(r.category)?.name ?? r.category;
                      final name = r.party.isNotEmpty ? r.party : cat;
                      return ListTile(
                        leading: Icon(categoryIcon(r.category), color: ll.muted),
                        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          '${formatCents(r.amountCents)} ${r.isIncome ? 'in' : 'out'} · '
                          '${everyLabel(r.every).toLowerCase()} · next '
                          '${DateFormat.yMMMd().format(DateTime.parse(r.nextDate))}',
                        ),
                        trailing: TextButton(onPressed: () => _stop(context, ref, r, name), child: const Text('Stop')),
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
