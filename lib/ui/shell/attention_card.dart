// Home: "Needs attention". Loose ends with a one-tap way to fix each; a row can be hidden until its count grows.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../data/attention.dart';
import '../../data/database.dart';
import '../design/components.dart';
import '../design/theme.dart';
import '../search/search_screen.dart';
import '../taxes/tools.dart' show Forms1099Screen;

final linkedEntryIdsProvider = StreamProvider<Set<int>>((ref) {
  final db = ref.watch(appControllerProvider.select((a) => a.db));
  return db == null ? Stream.value(const {}) : db.watchLinkedEntryIds();
});

final attentionProvider = Provider.family<List<AttentionItem>, int>((ref, year) {
  final entries = ref.watch(entriesProvider(year)).value;
  final linked = ref.watch(linkedEntryIdsProvider).value;
  if (entries == null || linked == null) return const [];
  return attentionItems(
    entries: entries,
    withReceipt: linked,
    forms: ref.watch(forms1099Provider(year)).value ?? const <Form1099>[],
    today: ref.watch(todayProvider),
  );
});

String _n(int n, String one, String many) => '$n ${n == 1 ? one : many}';

String _key(String kind, int year) => 'attention:$kind:$year';

/// kind -> count when the user hid that row (setting `attention:KIND:YEAR` in the encrypted DB).
final attentionHiddenProvider = FutureProvider.family<Map<String, int>, int>((ref, year) async {
  final db = ref.watch(appControllerProvider.select((a) => a.db));
  if (db == null) return const {};
  final out = <String, int>{};
  for (final k in const ['no_receipt', 'old_invoice', 'form_1099']) {
    final v = int.tryParse(await db.getSetting(_key(k, year)) ?? '');
    if (v != null) out[k] = v;
  }
  return out;
});

/// What the card shows: a hidden row comes back once its count grows.
final visibleAttentionProvider = Provider.family<List<AttentionItem>, int>((ref, year) {
  final hidden = ref.watch(attentionHiddenProvider(year)).value;
  if (hidden == null) return const [];
  return [
    for (final i in ref.watch(attentionProvider(year)))
      if (i.count > (hidden[i.kind] ?? 0)) i,
  ];
});

class AttentionCard extends ConsumerWidget {
  final int year;
  const AttentionCard({super.key, required this.year});

  Future<void> _hide(WidgetRef ref, AttentionItem i) async {
    await ref.read(appControllerProvider).db?.setSetting(_key(i.kind, year), '${i.count}');
    ref.invalidate(attentionHiddenProvider(year));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(visibleAttentionProvider(year));
    if (items.isEmpty) return const SizedBox.shrink();
    final ll = context.ll;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Needs attention'),
        LLCard(
          padding: const EdgeInsets.symmetric(vertical: Space.xs),
          child: Column(
            children: [
              for (final i in items)
                ListTile(
                  leading: Icon(switch (i.kind) {
                    'no_receipt' => Icons.receipt_long_outlined,
                    'old_invoice' => Icons.schedule_rounded,
                    _ => Icons.compare_arrows_rounded,
                  }, color: ll.warning),
                  title: Text(switch (i.kind) {
                    'no_receipt' => '${_n(i.count, 'expense', 'expenses')} over \$75 without a receipt',
                    'old_invoice' => '${_n(i.count, 'invoice', 'invoices')} unpaid for over $oldInvoiceDays days',
                    _ => '${_n(i.count, '1099 is', '1099s are')} higher than your records',
                  }),
                  subtitle: Text(switch (i.kind) {
                    'no_receipt' => '${formatCents(i.cents)} in all. Add the receipts while you still have them.',
                    'old_invoice' => '${formatCents(i.cents)} outstanding. Mark them received when the money lands.',
                    _ => '${formatCents(i.cents)} more on the forms. Is some income missing?',
                  }),
                  onTap: () => switch (i.kind) {
                    'no_receipt' => openSearch(context, text: 'no receipt > 75 in $year'),
                    'old_invoice' => openSearch(context, text: 'unpaid in $year'),
                    _ => Navigator.of(context).push(MaterialPageRoute(builder: (_) => Forms1099Screen(year))),
                  },
                  trailing: IconButton(
                    tooltip: 'Hide until there are more',
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => _hide(ref, i),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
