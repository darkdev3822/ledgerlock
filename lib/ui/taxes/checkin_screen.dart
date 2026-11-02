// "Keep me in check" check-in (SPEC §2.13): a few questions from the user's own records, each with a fix-it
// action, "Nothing missed", or skip. Everything is computed on the device.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../data/database.dart';
import '../../data/tax_rules.dart';
import '../../tax/checkin.dart';
import '../design/components.dart';
import '../design/theme.dart';
import '../ledger/entry_screen.dart';
import '../search/search_screen.dart';
import 'tools.dart';

/// Ids of entries that have a receipt attached, for a year.
final receiptEntryIdsProvider = StreamProvider.family<Set<int>, int>((ref, year) {
  final db = ref.watch(appControllerProvider.select((a) => a.db));
  if (db == null) return Stream.value(const {});
  return db
      .watchAttachments(year, folder: 'receipt')
      .map(
        (l) => {
          for (final a in l)
            if (a.entryId != null) a.entryId!,
        },
      );
});

/// Current questions (empty while data loads or nothing to ask).
final checkInProvider = Provider<List<CheckInQuestion>>((ref) {
  final today = ref.watch(todayProvider);
  final y = today.year;
  final app = ref.watch(appControllerProvider);
  final supported = TaxRules.supportedYears.contains(y);
  return checkInQuestions(
    today: today,
    entries: [
      ...ref.watch(entriesProvider(y)).value ?? const <LedgerEntry>[],
      ...ref.watch(entriesProvider(y - 1)).value ?? const <LedgerEntry>[],
    ],
    entriesWithReceipt: ref.watch(receiptEntryIdsProvider(y)).value ?? const {},
    payments: [
      ...ref.watch(paymentsProvider(y)).value ?? const <TaxPayment>[],
      ...ref.watch(paymentsProvider(y - 1)).value ?? const <TaxPayment>[],
    ],
    formsLastYear: ref.watch(forms1099Provider(y - 1)).value ?? const [],
    rules: supported ? ref.watch(taxRulesProvider(y)).value : null,
    previousRules: TaxRules.supportedYears.contains(y - 1) ? ref.watch(taxRulesProvider(y - 1)).value : null,
    dismissed: app.dismissedCheckIns,
  );
});

/// True when check-ins are on, the period has passed, and there's something to ask.
final checkInDueProvider = Provider<bool>((ref) {
  final app = ref.watch(appControllerProvider);
  final days = checkInFrequencies[app.checkInFrequency] ?? 0;
  if (days == 0) return false;
  final last = app.lastCheckIn;
  final due = last == null || daysBetween(last, ref.watch(todayProvider)) >= days;
  return due && ref.watch(checkInProvider).isNotEmpty;
});

class CheckInCard extends ConsumerWidget {
  const CheckInCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(checkInDueProvider)) return const SizedBox.shrink();
    final n = ref.watch(checkInProvider).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: LLCard(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.fact_check_outlined, color: context.ll.accent),
          title: const Text('Quick check-in'),
          subtitle: Text('$n question${n == 1 ? '' : 's'} to catch anything you missed'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CheckInScreen())),
        ),
      ),
    );
  }
}

class CheckInScreen extends ConsumerWidget {
  const CheckInScreen({super.key});

  (String, VoidCallback) _action(BuildContext context, CheckInQuestion q, int year) {
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    return switch (q.action) {
      CheckInAction.addEntry => ('Add a record', () => push(const EntryScreen())),
      CheckInAction.paymentLog => ('Log a payment', () => push(PaymentLogScreen(year))),
      CheckInAction.forms1099 => ('Add 1099s', () => push(Forms1099Screen(year - 1))),
      CheckInAction.receipts => ('Show them', () => push(SearchScreen(initialText: q.query))),
      CheckInAction.unpaid => ('Show them', () => push(SearchScreen(initialText: q.query))),
      CheckInAction.categorize => ('Show them', () => push(SearchScreen(initialText: q.query))),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appControllerProvider);
    final qs = ref.watch(checkInProvider);
    final today = ref.watch(todayProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Quick check-in')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xxl),
        children: [
          Text(
            'Built from your own records, on this phone. It can only spot gaps in what you’ve entered.',
            style: context.text.bodySmall,
          ),
          const SizedBox(height: Space.md),
          if (qs.isEmpty)
            const EmptyState(
              icon: Icons.task_alt_rounded,
              title: 'All caught up',
              body: 'Nothing looks missing right now.',
            ),
          for (final q in qs) ...[
            LLCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(q.text, style: context.text.bodyLarge),
                  const SizedBox(height: Space.sm),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => app.dismissCheckIn(q.key),
                          child: const Text('Nothing missed'),
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final (label, go) = _action(context, q, today.year);
                            return FilledButton.tonal(onPressed: go, child: Text(label));
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.md),
          ],
          FilledButton(
            onPressed: () async {
              await app.finishCheckIn(DateTime.now());
              if (!context.mounted) return;
              final messenger = ScaffoldMessenger.maybeOf(context);
              final days = checkInFrequencies[app.checkInFrequency] ?? 0;
              Navigator.of(context).pop();
              showSuccess(
                messenger,
                days == 0
                    ? 'Check-in done. Nice work keeping things tidy.'
                    : 'Check-in done. Next one in ${days == 7 ? 'a week' : '$days days'}.',
              );
            },
            child: const Text('Done for now'),
          ),
        ],
      ),
    );
  }
}
