// Taxes tab: "What changed for you" + free help matched to the user (SPEC §2.12). All matching is local.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../data/database.dart';
import '../../data/tax_rules.dart';
import '../../platform/open_link.dart';
import '../../tax/guidance.dart';
import '../design/components.dart';
import '../design/theme.dart';

/// Facts about the user for [year], from their own records.
UserFacts userFacts(WidgetRef ref, int year) {
  final app = ref.watch(appControllerProvider);
  final s = ref.watch(summaryProvider(year));
  final entries = ref.watch(entriesProvider(year)).value ?? const <LedgerEntry>[];
  final last = ref.watch(entriesProvider(year - 1)).value ?? const <LedgerEntry>[];
  final platformIncome = [
    for (final e in entries)
      if (e.isIncome && isPaymentPlatform(e.platform)) e,
  ];
  return UserFacts(
    year: year,
    netCents: s.netCents,
    seTaxCents: s.seTaxCents,
    hasIncome: entries.any((e) => e.isIncome),
    hadIncomeLastYear: last.any((e) => e.isIncome),
    hasIrsLetter: ref.watch(hasIrsLetterProvider(year)).value ?? false,
    platforms: {for (final e in platformIncome) e.platform.trim()},
    platformIncomeCents: platformIncome.fold(0, (a, e) => a + e.amountCents),
    age60OptIn: app.age60OptIn,
    irsProblemOptIn: app.irsProblemOptIn,
  );
}

class GuidanceSection extends ConsumerWidget {
  final int year;
  const GuidanceSection({super.key, required this.year});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appControllerProvider);
    final facts = userFacts(ref, year);
    final cur = ref.watch(taxRulesProvider(year)).value;
    final prev = TaxRules.supportedYears.contains(year - 1) ? ref.watch(taxRulesProvider(year - 1)).value : null;
    final entries = ref.watch(entriesProvider(year)).value ?? const <LedgerEntry>[];
    final changes = cur == null || prev == null
        ? const <RuleChange>[]
        : whatChanged(
            prev,
            cur,
            netCents: facts.netCents,
            largestPlatformIncomeCents: _largestPlatform(entries),
            expenseByCategory: _businessSpend(entries),
          );
    final suggestions = suggestResources(ref.watch(resourcesProvider).value ?? const [], facts);
    final ll = context.ll;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (changes.isNotEmpty) ...[
          SectionHeader('What changed for you in $year'),
          LLGroup(
            children: [
              for (final c in changes)
                ListTile(
                  leading: Icon(Icons.change_circle_outlined, color: ll.accent),
                  title: Text(c.title),
                  subtitle: Text([c.detail, if (c.forYou != null) c.forYou!].join('\n')),
                  isThreeLine: c.forYou != null,
                ),
            ],
          ),
        ],
        const SectionHeader('Free help that may fit you'),
        if (suggestions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.sm),
            child: Text(
              'Nothing to suggest yet. Add income and expenses to see matches.',
              style: context.text.bodySmall,
            ),
          )
        else
          LLGroup(
            children: [
              for (final s in suggestions)
                ListTile(
                  title: Text(s.resource.name),
                  subtitle: Text([s.resource.purpose, if (s.why != null) s.why!].join('\n')),
                  isThreeLine: s.why != null,
                  trailing: Icon(Icons.open_in_new_rounded, size: 20, color: ll.muted),
                  onTap: () => confirmOpenResource(context, s.resource),
                ),
            ],
          ),
        const SizedBox(height: Space.sm),
        LLGroup(
          children: [
            SwitchListTile(
              title: const Text('I’m 60 or older'),
              subtitle: const Text('Shows help aimed at older taxpayers. Stays on this phone.'),
              value: app.age60OptIn,
              onChanged: (v) => app.setOptIns(age60: v),
            ),
            SwitchListTile(
              title: const Text('I have an IRS problem that isn’t solved'),
              subtitle: const Text('Shows free help with IRS disputes. Stays on this phone.'),
              value: app.irsProblemOptIn,
              onChanged: (v) => app.setOptIns(irsProblem: v),
            ),
          ],
        ),
        const SizedBox(height: Space.sm),
        Text(
          'Information from official sources, not tax advice. These may be worth checking; '
          'only each program can say whether you qualify. Matching happens on this phone.',
          style: context.text.bodySmall,
        ),
      ],
    );
  }
}

/// Asks before leaving the app for a resource link (shared with Learn lessons).
Future<void> confirmOpenResource(BuildContext context, Resource r) async {
  final host = Uri.parse(r.url).host.replaceFirst('www.', '');
  final go = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.lg),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Open $host?', style: c.text.titleMedium),
              const SizedBox(height: Space.sm),
              Text(
                'This opens ${r.name} in your browser. LedgerLock stays offline and sends nothing; '
                'the link carries no information about you.',
                style: c.text.bodyMedium,
              ),
              if (r.siteNote.isNotEmpty) ...[
                const SizedBox(height: Space.sm),
                Text(r.siteNote, style: c.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: Space.lg),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Open in browser')),
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            ],
          ),
        ),
      ),
    ),
  );
  if (go != true) return;
  final err = await openOfficialLink(r.url);
  if (err != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
  }
}

/// Business-share spend per expense category, in cents.
Map<String, int> _businessSpend(List<LedgerEntry> entries) {
  final m = <String, int>{};
  for (final e in entries.where((e) => !e.isIncome)) {
    m.update(
      e.category,
      (v) => v + (e.amountCents * e.businessPct / 100).round(),
      ifAbsent: () => (e.amountCents * e.businessPct / 100).round(),
    );
  }
  return m;
}

/// Income through the user's biggest single payment platform (the 1099-K threshold counts per platform).
int _largestPlatform(List<LedgerEntry> entries) {
  final m = <String, int>{};
  for (final e in entries.where((e) => e.isIncome && isPaymentPlatform(e.platform))) {
    m.update(e.platform.trim().toLowerCase(), (v) => v + e.amountCents, ifAbsent: () => e.amountCents);
  }
  return m.values.fold(0, (a, v) => v > a ? v : a);
}
