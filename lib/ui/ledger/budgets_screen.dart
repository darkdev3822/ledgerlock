// Budgets (monthly, per expense category) and a yearly income goal (SPEC §3): Home card + Settings screen.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../data/budgets.dart';
import '../../data/database.dart';
import '../../data/tax_rules.dart';
import '../design/components.dart';
import '../design/theme.dart';
import 'category_icons.dart';

/// Whole dollars: budgets and goals are rough targets, cents are noise here.
String _money(int c) => formatCents(((c + 50) ~/ 100) * 100).replaceAll('.00', '');

class _Bar extends StatelessWidget {
  final double value;
  final Color color;
  const _Bar(this.value, this.color);
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(4),
    child: LinearProgressIndicator(
      value: value.clamp(0, 1),
      minHeight: 8,
      color: color,
      backgroundColor: context.ll.surfaceAlt,
    ),
  );
}

/// Home: this month's budgets and the year's income goal. Hidden until one of them is set.
class BudgetsCard extends ConsumerWidget {
  final int year;
  const BudgetsCard({super.key, required this.year});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgets = ref.watch(appControllerProvider.select((a) => a.budgets));
    final goal = ref.watch(appControllerProvider.select((a) => a.incomeGoals[year] ?? 0));
    final today = ref.watch(todayProvider);
    final entries = (ref.watch(entriesProvider(year)).value ?? const <LedgerEntry>[]).map((e) => e.data).toList();
    final rules = ref.watch(taxRulesProvider(year)).value;
    // Monthly budgets only mean something in the current year.
    final status = today.year == year ? budgetStatus(budgets, entries, today) : const <BudgetStatus>[];
    if (status.isEmpty && goal <= 0) return const SizedBox.shrink();
    final g = goalStatus(goal, year, entries, today);
    final ll = context.ll;
    // Carries its own bottom spacing: the Home list adds none for cards that can hide themselves.
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            'Budgets & goal',
            trailing: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BudgetsScreen())),
              child: const Text('Edit'),
            ),
          ),
          LLCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (goal > 0) ...[
                  Text('Income goal for $year', style: context.text.labelMedium),
                  const SizedBox(height: 4),
                  Text(
                    '${_money(g.receivedCents)} of ${_money(goal)} (${(g.progress * 100).floor()}%)',
                    style: context.text.titleSmall,
                  ),
                  const SizedBox(height: Space.sm),
                  _Bar(g.progress, ll.income),
                  if (g.projectedCents != null) ...[
                    const SizedBox(height: Space.sm),
                    Text(
                      g.projectedCents! >= goal
                          ? 'At this pace you reach it, with about ${_money(g.projectedCents!)} by Dec 31.'
                          : 'At this pace: about ${_money(g.projectedCents!)} by Dec 31.',
                      style: context.text.bodySmall,
                    ),
                  ],
                  if (status.isNotEmpty) const SizedBox(height: Space.lg),
                ],
                for (final (n, b) in status.indexed) ...[
                  if (n > 0) const SizedBox(height: Space.md),
                  Row(
                    children: [
                      Icon(categoryIcon(b.category), size: 18, color: ll.muted),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: Text(
                          rules?.category(b.category)?.name ?? b.category,
                          style: context.text.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        b.over
                            ? '${_money(b.spentCents - b.capCents)} over'
                            : '${_money(b.capCents - b.spentCents)} left',
                        style: context.text.labelMedium?.copyWith(color: b.over ? ll.expense : null),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _Bar(b.used, b.over ? ll.expense : (b.ahead ? ll.warning : ll.accent)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Settings > Records > Budgets & goal.
class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  Future<int?> _ask(BuildContext context, String title, int current, String helper) => showDialog<int>(
    context: context,
    builder: (_) => AmountDialog(title: title, currentCents: current, helper: helper, allowRemove: current > 0),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appControllerProvider);
    final year = app.selectedYear;
    final TaxRules? rules = ref.watch(taxRulesProvider(year)).value;
    final ll = context.ll;
    final goal = app.incomeGoals[year] ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Budgets & goal')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xxl),
        children: [
          Text(
            'Set a monthly limit for any expense category and a yearly income goal. Home shows how you are doing. '
            'Budgets count the full amount you paid; tax figures still use the business share.',
            style: context.text.bodySmall,
          ),
          const SectionHeader('Income goal'),
          LLGroup(
            children: [
              ListTile(
                leading: Icon(Icons.flag_outlined, color: ll.income),
                title: Text('$year income goal'),
                trailing: Text(goal > 0 ? _money(goal) : 'Not set', style: context.text.titleSmall),
                onTap: () async {
                  final v = await _ask(context, '$year income goal', goal, 'Gross income you want to reach this year');
                  if (v != null) await app.setIncomeGoal(year, v);
                },
              ),
            ],
          ),
          const SectionHeader('Monthly budgets'),
          if (rules != null)
            LLGroup(
              children: [
                for (final c in rules.expenseCategories)
                  ListTile(
                    leading: Icon(categoryIcon(c.id), color: ll.muted),
                    title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Text(
                      (app.budgets[c.id] ?? 0) > 0 ? '${_money(app.budgets[c.id]!)} / mo' : 'None',
                      style: context.text.titleSmall?.copyWith(color: (app.budgets[c.id] ?? 0) > 0 ? null : ll.muted),
                    ),
                    onTap: () async {
                      final v = await _ask(
                        context,
                        '${c.name} per month',
                        app.budgets[c.id] ?? 0,
                        'Leave empty for none',
                      );
                      if (v != null) await app.setBudget(c.id, v);
                    },
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
