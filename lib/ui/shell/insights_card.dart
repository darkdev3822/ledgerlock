// Home: "Compared with last year" (SPEC §3 year-over-year insights). Hidden when there is nothing worth saying.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../data/database.dart';
import '../../data/insights.dart';
import '../../data/tax_rules.dart';
import '../design/components.dart';
import '../design/theme.dart';

final insightsProvider = Provider.family<List<Insight>, int>((ref, year) {
  final now = ref.watch(entriesProvider(year)).value ?? const <LedgerEntry>[];
  final before = ref.watch(entriesProvider(year - 1)).value ?? const <LedgerEntry>[];
  return yearInsights(year, now.map((e) => e.data), before.map((e) => e.data), ref.watch(todayProvider));
});

String _money(int c) => formatCents(c).replaceAll('.00', '');

/// Plain-language line for one insight. [ytd]: the comparison is year-to-date.
String insightText(Insight i, TaxRules? rules, int year, {required bool ytd}) {
  final name = i.category == null ? '' : (rules?.category(i.category!)?.name ?? i.category!.replaceAll('_', ' '));
  final when = ytd ? 'this point in ${year - 1}' : '${year - 1}';
  String move(String what) {
    final up = i.deltaCents > 0;
    final pct = i.pct;
    final by = pct == null ? '' : ' ${pct.abs()}%';
    return '$what ${up ? 'up' : 'down'}$by vs $when (${_money(i.thisCents)} vs ${_money(i.lastCents)}).';
  }

  return switch (i.kind) {
    'income' => move('Income'),
    'category' => move('$name spending'),
    'new_category' => 'New this year: $name, ${_money(i.thisCents)} so far.',
    'top_category' =>
      'Most of your spending is $name: '
          '${(i.thisCents * 100 / (i.lastCents == 0 ? 1 : i.lastCents)).round()}% (${_money(i.thisCents)}).',
    _ => '',
  };
}

class InsightsCard extends ConsumerWidget {
  final int year;
  const InsightsCard({super.key, required this.year});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(insightsProvider(year));
    if (list.isEmpty) return const SizedBox.shrink();
    final rules = ref.watch(taxRulesProvider(year)).value;
    final ytd = ref.watch(todayProvider).year == year;
    final ll = context.ll;
    final compared = list.first.kind != 'top_category';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(compared ? 'Compared with ${year - 1}' : 'Where it goes'),
        LLCard(
          child: Column(
            children: [
              for (final (n, i) in list.indexed) ...[
                if (n > 0) const SizedBox(height: Space.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      switch (i.kind) {
                        'new_category' => Icons.fiber_new_outlined,
                        'top_category' => Icons.pie_chart_outline_rounded,
                        _ => i.deltaCents >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      },
                      size: 20,
                      color: i.kind == 'income' ? (i.deltaCents >= 0 ? ll.income : ll.warning) : ll.muted,
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Text(insightText(i, rules, year, ytd: ytd), style: context.text.bodyMedium),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
