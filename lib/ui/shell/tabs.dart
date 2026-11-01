// Tab contents. Real data arrives in M3 (ledger), M4 (vault), M6 (taxes); the
// layout, components and empty states are final.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/app_controller.dart';
import '../../data/tax_rules.dart';
import '../design/components.dart';
import '../design/theme.dart';

const _pad = EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xxl);

void _soon(BuildContext context, String what) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text('$what arrives in the next milestone.')));

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(appControllerProvider.select((a) => a.selectedYear));
    final rules = ref.watch(taxRulesProvider(year)).value;
    final today = ref.watch(todayProvider);
    return ListView(
      padding: _pad,
      children: [
        _HeroCard(year: year, netCents: 0, incomeCents: 0, expenseCents: 0),
        const SizedBox(height: Space.md),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Set aside for taxes',
                cents: 0,
                icon: Icons.savings_outlined,
                tint: context.ll.warning,
              ),
            ),
            const SizedBox(width: Space.md),
            const Expanded(
              child: StatTile(label: 'Est. self-employment tax', cents: 0, icon: Icons.percent_rounded),
            ),
          ],
        ),
        if (rules != null) ...[const SizedBox(height: Space.md), _NextDueCard(rules: rules, today: today)],
        const SectionHeader('Recent activity'),
        EmptyState(
          icon: Icons.add_card_rounded,
          title: 'Add your first income or expense',
          body:
              'Three taps: amount, category, done. LedgerLock maps it to the right Schedule C line for you.',
          actionLabel: 'Add a record',
          onAction: () => _soon(context, 'Adding records'),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final int year, netCents, incomeCents, expenseCents;
  const _HeroCard({
    required this.year,
    required this.netCents,
    required this.incomeCents,
    required this.expenseCents,
  });

  @override
  Widget build(BuildContext context) {
    final ll = context.ll;
    const onHero = Colors.white;
    final dim = onHero.withValues(alpha: 0.72);
    return Container(
      padding: const EdgeInsets.all(Space.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.card),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ll.heroStart, ll.heroEnd],
        ),
        boxShadow: [
          BoxShadow(color: ll.heroEnd.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Net profit · $year', style: context.text.labelLarge?.copyWith(color: dim)),
              const Spacer(),
              Icon(Icons.lock_rounded, size: 16, color: dim),
              const SizedBox(width: 4),
              Text('Encrypted', style: context.text.labelSmall?.copyWith(color: dim)),
            ],
          ),
          const SizedBox(height: Space.sm),
          MoneyText(netCents, style: context.text.displaySmall, color: onHero),
          const SizedBox(height: Space.lg),
          Row(
            children: [
              Expanded(
                child: _HeroStat(label: 'Income', cents: incomeCents, icon: Icons.south_west_rounded),
              ),
              Container(width: 1, height: 36, color: onHero.withValues(alpha: 0.2)),
              const SizedBox(width: Space.lg),
              Expanded(
                child: _HeroStat(label: 'Expenses', cents: expenseCents, icon: Icons.north_east_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final int cents;
  final IconData icon;
  const _HeroStat({required this.label, required this.cents, required this.icon});

  @override
  Widget build(BuildContext context) {
    final dim = Colors.white.withValues(alpha: 0.72);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: dim),
            const SizedBox(width: 4),
            Text(label, style: context.text.labelMedium?.copyWith(color: dim)),
          ],
        ),
        const SizedBox(height: 2),
        MoneyText(cents, style: context.text.titleMedium, color: Colors.white),
      ],
    );
  }
}

class _NextDueCard extends StatelessWidget {
  final TaxRules rules;
  final DateTime today;
  const _NextDueCard({required this.rules, required this.today});

  @override
  Widget build(BuildContext context) {
    final next = rules.nextDue(today);
    final ll = context.ll;
    final days = next?.due.difference(DateTime(today.year, today.month, today.day)).inDays;
    return LLCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: ll.accentSoft, borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.event_rounded, color: ll.accent),
          ),
          const SizedBox(width: Space.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  next == null
                      ? '${rules.year} quarterly payments are behind you'
                      : '${next.quarter} estimated tax',
                  style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  next == null
                      ? 'The last one was due ${DateFormat.yMMMd().format(rules.quarterlyDue.last.due)}.'
                      : 'Due ${DateFormat.yMMMd().format(next.due)}',
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
          if (days != null)
            Pill(days == 0 ? 'Today' : 'in $days days', color: days <= 14 ? ll.warning : ll.accent),
        ],
      ),
    );
  }
}

class RecordsTab extends StatelessWidget {
  const RecordsTab({super.key});

  @override
  Widget build(BuildContext context) => ListView(
    padding: _pad,
    children: [
      TextField(
        readOnly: true,
        onTap: () => _soon(context, 'Search'),
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search_rounded),
          hintText: 'Search payee, amount, category…',
        ),
      ),
      const SizedBox(height: Space.md),
      Wrap(
        spacing: Space.sm,
        children: [
          for (final c in const ['All', 'Income', 'Expenses', 'Needs receipt'])
            FilterChip(label: Text(c), selected: c == 'All', onSelected: (_) {}, showCheckmark: false),
        ],
      ),
      const SizedBox(height: Space.lg),
      EmptyState(
        icon: Icons.receipt_long_rounded,
        title: 'No records for this year yet',
        body: 'Everything you add lands here, grouped by month and searchable in an instant.',
        actionLabel: 'Add a record',
        onAction: () => _soon(context, 'Adding records'),
      ),
    ],
  );
}

class VaultTab extends StatelessWidget {
  const VaultTab({super.key});

  static const _folders = [
    (Icons.work_outline_rounded, 'W-2 & 1099s'),
    (Icons.receipt_rounded, 'Receipts'),
    (Icons.history_edu_rounded, 'Prior returns'),
    (Icons.mail_outline_rounded, 'Letters'),
  ];

  @override
  Widget build(BuildContext context) => ListView(
    padding: _pad,
    children: [
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: Space.md,
        crossAxisSpacing: Space.md,
        childAspectRatio: 1.55,
        children: [
          for (final (icon, label) in _folders)
            LLCard(
              onTap: () => _soon(context, 'The documents vault'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: context.ll.accent),
                  const Spacer(),
                  Text(label, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  Text('0 files', style: context.text.bodySmall),
                ],
              ),
            ),
        ],
      ),
      const SizedBox(height: Space.lg),
      EmptyState(
        icon: Icons.document_scanner_rounded,
        title: 'Scan your first receipt',
        body:
            'Tap the scan button below. Every photo and document is encrypted on this phone and never '
            'shows up in your gallery.',
      ),
    ],
  );
}

class TaxesTab extends ConsumerWidget {
  const TaxesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(appControllerProvider.select((a) => a.selectedYear));
    final rules = ref.watch(taxRulesProvider(year)).value;
    final today = ref.watch(todayProvider);
    final ll = context.ll;
    final next = rules?.nextDue(today);
    return ListView(
      padding: _pad,
      children: [
        LLCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Estimated tax owed for $year', style: context.text.bodySmall),
              const SizedBox(height: 4),
              MoneyText(0, style: context.text.headlineMedium),
              const SizedBox(height: Space.sm),
              Text(
                'Based on your records so far. Add income to see an estimate.',
                style: context.text.bodySmall,
              ),
            ],
          ),
        ),
        const SectionHeader('Quarterly payments (Form 1040-ES)'),
        if (rules != null)
          LLGroup(
            children: [
              for (final q in rules.quarterlyDue)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: q == next ? ll.accent : ll.surfaceAlt,
                    foregroundColor: q == next ? ll.onAccent : ll.muted,
                    child: Text(q.quarter, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                  title: Text('Due ${DateFormat.yMMMd().format(q.due)}'),
                  subtitle: Text('Covers ${q.covers}'),
                  trailing: q == next
                      ? Pill('Next', color: ll.accent)
                      : q.due.isBefore(today)
                      ? Pill('Past', color: ll.muted)
                      : null,
                ),
            ],
          ),
        const SectionHeader('Tools'),
        LLGroup(
          children: [
            for (final (icon, title, sub) in const [
              (Icons.payments_outlined, 'Payment log', 'Record what you\'ve paid the IRS'),
              (Icons.directions_car_outlined, 'Mileage', 'Standard mileage rate, trip by trip'),
              (Icons.home_work_outlined, 'Home office', 'Simplified or regular method'),
              (Icons.description_outlined, '1099 tracker', 'Match forms to your income'),
            ])
              ListTile(
                leading: Icon(icon),
                title: Text(title),
                subtitle: Text(sub),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _soon(context, title),
              ),
          ],
        ),
      ],
    );
  }
}
