// Tab contents (M3: live ledger data). Vault arrives in M4, tax tools in M6.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/app_controller.dart';
import '../../data/database.dart';
import '../../data/ledger.dart';
import '../../data/tax_rules.dart';
import '../design/components.dart';
import '../design/theme.dart';
import '../ledger/category_icons.dart';
import '../ledger/entry_screen.dart';
import '../search/search_screen.dart';
import '../taxes/checkin_screen.dart';
import '../taxes/guidance_section.dart';
import '../taxes/tools.dart';

const _pad = EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xxl);

// ============================== Home ==============================

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(appControllerProvider.select((a) => a.selectedYear));
    final rules = ref.watch(taxRulesProvider(year)).value;
    final s = ref.watch(summaryProvider(year));
    final entries = ref.watch(entriesProvider(year)).value ?? const [];
    final today = ref.watch(todayProvider);
    final sections = <Widget>[
      _Greeting(today: today, rules: rules, s: s, hasEntries: entries.isNotEmpty),
      const CheckInCard(),
      _HeroCard(year: year, s: s),
      if (entries.isNotEmpty)
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Set aside (${s.setAsidePct.round()}% of profit)',
                cents: s.setAsideCents,
                icon: Icons.savings_outlined,
                tint: context.ll.warning,
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: StatTile(label: 'Est. self-employment tax', cents: s.seTaxCents, icon: Icons.percent_rounded),
            ),
          ],
        ),
      if (rules != null) _NextDueCard(rules: rules, today: today, perQuarterCents: s.setAsideCents ~/ 4),
      if (entries.isNotEmpty)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader('Month by month'),
            LLCard(
              child: MonthlyChart(summary: s, currentMonth: today.year == year ? today.month : null),
            ),
          ],
        ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            'Recent activity',
            trailing: entries.isEmpty
                ? null
                : TextButton(onPressed: () => openEntry(context), child: const Text('Add')),
          ),
          if (entries.isEmpty)
            EmptyState(
              icon: Icons.add_card_rounded,
              title: 'Add your first income or expense',
              body: 'Three taps: amount, category, done. LedgerLock maps it to the right Schedule C line for you.',
              actionLabel: 'Add a record',
              onAction: () => openEntry(context),
            )
          else if (rules != null)
            LLGroup(
              children: [for (final e in entries.take(5)) EntryTile(entry: e, rules: rules)],
            ),
        ],
      ),
    ];
    return ListView(
      padding: _pad,
      children: [
        for (final (i, w) in sections.indexed)
          Padding(
            padding: EdgeInsets.only(bottom: i == 0 || i == sections.length - 1 ? 0 : Space.md),
            child: Reveal(index: i, child: w),
          ),
      ],
    );
  }
}

/// "Good evening" plus one line about where the user stands. Awareness, not decoration.
class _Greeting extends StatelessWidget {
  final DateTime today;
  final TaxRules? rules;
  final LedgerSummary s;
  final bool hasEntries;
  const _Greeting({required this.today, required this.rules, required this.s, required this.hasEntries});

  String get _hello {
    final h = today.hour;
    if (h >= 5 && h < 12) return 'Good morning';
    if (h >= 12 && h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _line {
    if (!hasEntries) return 'Let’s get your year started.';
    final next = rules?.nextDue(today);
    if (s.netCents <= 0) return 'Expenses are ahead of income so far. That’s common early on.';
    if (next == null) return 'This year’s quarterly payments are behind you.';
    final days = next.due.difference(DateTime(today.year, today.month, today.day)).inDays;
    if (days <= 14) return '${next.quarter} is due in $days day${days == 1 ? '' : 's'}. Worth a look today.';
    return 'You’re up ${formatCents(s.netCents)} this year. ${next.quarter} is due in $days days.';
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, Space.xs, 4, Space.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_hello, style: context.text.headlineMedium?.copyWith(fontWeight: FontWeight.w500)),
        const SizedBox(height: Space.xs),
        Text(_line, style: context.text.bodyMedium?.copyWith(color: context.ll.muted)),
      ],
    ),
  );
}

class _HeroCard extends StatelessWidget {
  final int year;
  final LedgerSummary s;
  const _HeroCard({required this.year, required this.s});

  @override
  Widget build(BuildContext context) {
    final ll = context.ll;
    const onHero = Colors.white;
    final dim = onHero.withValues(alpha: 0.74);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.card + 4),
        boxShadow: [
          BoxShadow(
            color: ll.heroEnd.withValues(alpha: 0.30),
            blurRadius: 30,
            spreadRadius: -10,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.card + 4),
        child: _AmbientGlow(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.xl, Space.xl, Space.xl, Space.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${s.netCents < 0 ? 'Net loss' : 'Net profit'} · $year',
                      style: context.text.titleSmall?.copyWith(
                        color: dim,
                        fontFamily: Fonts.voice,
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: onHero.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(Radii.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_rounded, size: 12, color: dim),
                          const SizedBox(width: 4),
                          Text('On this phone only', style: context.text.labelSmall?.copyWith(color: dim)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.md),
                AnimatedMoney(s.netCents, style: context.text.displaySmall, color: onHero),
                const SizedBox(height: Space.xl),
                Row(
                  children: [
                    Expanded(
                      child: _HeroStat(label: 'Income', cents: s.grossCents, icon: Icons.south_west_rounded),
                    ),
                    Container(width: 1, height: 36, color: onHero.withValues(alpha: 0.18)),
                    const SizedBox(width: Space.lg),
                    Expanded(
                      child: _HeroStat(label: 'Deductible', cents: s.expensesCents, icon: Icons.north_east_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hero background: deep emerald with a warm glow that drifts very slowly (14 s loop). Static with reduce-motion.
class _AmbientGlow extends StatefulWidget {
  final Widget child;
  const _AmbientGlow({required this.child});
  @override
  State<_AmbientGlow> createState() => _AmbientGlowState();
}

class _AmbientGlowState extends State<_AmbientGlow> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 14));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final on = Motion.ambient && !Motion.reduced(context);
    if (on && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!on) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ll = context.ll;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (_, child) {
        final t = Curves.easeInOutSine.transform(_c.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [ll.heroStart, ll.heroEnd],
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.55 + 0.35 * t, -1.1 + 0.3 * t),
                radius: 1.15,
                colors: [ll.heroGlow.withValues(alpha: 0.30), ll.heroGlow.withValues(alpha: 0)],
              ),
            ),
            child: child,
          ),
        );
      },
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
            Flexible(
              child: Text(
                label,
                style: context.text.labelMedium?.copyWith(color: dim),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        AnimatedMoney(cents, style: context.text.titleMedium, color: Colors.white),
      ],
    );
  }
}

class _NextDueCard extends StatelessWidget {
  final TaxRules rules;
  final DateTime today;
  final int perQuarterCents;
  const _NextDueCard({required this.rules, required this.today, required this.perQuarterCents});

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
                  next == null ? '${rules.year} quarterly payments are behind you' : '${next.quarter} estimated tax',
                  style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  next == null
                      ? 'The last one was due ${DateFormat.yMMMd().format(rules.quarterlyDue.last.due)}.'
                      : 'Due ${DateFormat.yMMMd().format(next.due)}'
                            '${perQuarterCents > 0 ? ' · about ${formatCents(perQuarterCents)}' : ''}',
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
          if (days != null) Pill(days == 0 ? 'Today' : 'in $days days', color: days <= 14 ? ll.warning : ll.accent),
        ],
      ),
    );
  }
}

/// Income vs deductible expenses per month (custom-painted: no chart dependency).
class MonthlyChart extends StatelessWidget {
  final LedgerSummary summary;

  /// Highlighted (label in accent, bold) when viewing the current year.
  final int? currentMonth;
  const MonthlyChart({super.key, required this.summary, this.currentMonth});

  @override
  Widget build(BuildContext context) {
    final ll = context.ll;
    final maxV = summary.monthly.values.fold<int>(1, (m, v) => math.max(m, math.max(v.$1, v.$2)));
    return Semantics(
      label: 'Monthly income and expenses chart',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Legend(color: ll.accent, label: 'Income'),
              const SizedBox(width: Space.lg),
              _Legend(color: ll.expense.withValues(alpha: 0.75), label: 'Expenses'),
            ],
          ),
          const SizedBox(height: Space.md),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var m = 1; m <= 12; m++)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _Bar(fraction: math.max(0, summary.monthly[m]?.$1 ?? 0) / maxV, color: ll.accent),
                              const SizedBox(width: 2),
                              _Bar(
                                fraction: (summary.monthly[m]?.$2 ?? 0) / maxV,
                                color: ll.expense.withValues(alpha: 0.75),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          DateFormat('MMMMM').format(DateTime(2000, m)),
                          style: context.text.labelSmall?.copyWith(
                            color: m == currentMonth ? ll.accent : ll.muted,
                            fontWeight: m == currentMonth ? FontWeight.w800 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final double fraction;
  final Color color;
  const _Bar({required this.fraction, required this.color});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: fraction.clamp(0, 1)),
      duration: Motion.reduced(context) ? Duration.zero : Motion.slow,
      curve: Motion.enter,
      builder: (_, f, _) => Container(
        width: 9,
        height: math.max(f * c.maxHeight, f > 0 ? 4 : 0),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
      ),
    ),
  );
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
      ),
      const SizedBox(width: 6),
      Text(label, style: context.text.labelMedium),
    ],
  );
}

// ============================== Records ==============================

/// One ledger row: icon, payee/category, date, signed amount. Tap to edit.
class EntryTile extends StatelessWidget {
  final LedgerEntry entry;
  final TaxRules rules;

  /// Search terms to highlight in the title.
  final List<String> highlight;
  const EntryTile({super.key, required this.entry, required this.rules, this.highlight = const []});

  @override
  Widget build(BuildContext context) {
    final ll = context.ll;
    final cat = rules.category(entry.category);
    final title = entry.party.isNotEmpty ? entry.party : (cat?.name ?? entry.category);
    final refund = entry.isIncome && cat?.line == '2';
    final sign = entry.isIncome && !refund ? '+' : '−';
    final color = entry.isIncome && !refund ? ll.income : ll.text;
    final extra = [
      if (!entry.isIncome && entry.businessPct < 100) '${entry.businessPct}% business',
      if (entry.isIncome && entry.feeCents > 0) 'fee ${formatCents(entry.feeCents)}',
    ];
    return ListTile(
      onTap: () => openEntry(context, existing: entry),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: entry.isIncome ? ll.accentSoft : ll.surfaceAlt,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(categoryIcon(entry.category), size: 20, color: entry.isIncome ? ll.accent : ll.muted),
      ),
      title: HighlightText(title, highlight, maxLines: 1),
      subtitle: Text(
        [if (entry.party.isNotEmpty) cat?.name ?? '', DateFormat.MMMd().format(entry.day), ...extra].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$sign${formatCents(entry.amountCents)}',
            style: context.text.titleSmall?.copyWith(
              color: entry.isIncome && !entry.paid ? ll.muted : color,
              fontFamily: Fonts.ui,
              fontWeight: FontWeight.w700,
              fontFeatures: tabular,
            ),
          ),
          if (entry.isIncome && !entry.paid) ...[const SizedBox(height: 3), Pill('Unpaid', color: ll.warning)],
        ],
      ),
    );
  }
}

class RecordsTab extends ConsumerStatefulWidget {
  const RecordsTab({super.key});
  @override
  ConsumerState<RecordsTab> createState() => _RecordsTabState();
}

enum _Filter { all, income, expenses }

class _RecordsTabState extends ConsumerState<RecordsTab> {
  _Filter _filter = _Filter.all;

  bool _matches(LedgerEntry e, TaxRules rules) => _filter == _Filter.all || (_filter == _Filter.income) == e.isIncome;

  Future<void> _delete(LedgerEntry e) async {
    final db = ref.read(appControllerProvider).db;
    if (db == null) return;
    HapticFeedback.mediumImpact();
    await db.deleteEntry(e.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Record deleted'),
          action: SnackBarAction(label: 'Undo', onPressed: () => db.restoreEntry(e)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final year = ref.watch(appControllerProvider.select((a) => a.selectedYear));
    final rules = ref.watch(taxRulesProvider(year)).value;
    final all = ref.watch(entriesProvider(year)).value ?? const [];
    final ll = context.ll;
    final shown = rules == null ? const <LedgerEntry>[] : all.where((e) => _matches(e, rules)).toList();
    final byMonth = <int, List<LedgerEntry>>{};
    for (final e in shown) {
      byMonth.putIfAbsent(e.day.month, () => []).add(e);
    }
    int sum(Iterable<LedgerEntry> l, bool income) =>
        l.where((e) => e.isIncome == income && (!income || e.paid)).fold(0, (a, e) => a + e.amountCents);
    return ListView(
      padding: _pad,
      children: [
        TextField(
          readOnly: true,
          onTap: () => openSearch(context),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            hintText: 'Search everything: "meals over 50", "no receipt"…',
          ),
        ),
        const SizedBox(height: Space.md),
        LLSegmented<_Filter>(
          options: const [(_Filter.all, 'All'), (_Filter.income, 'Income'), (_Filter.expenses, 'Expenses')],
          value: _filter,
          onChanged: (f) => setState(() => _filter = f),
        ),
        if (all.isNotEmpty) ...[
          const SizedBox(height: Space.lg),
          _InOutStrip(
            inCents: _filter == _Filter.expenses ? null : sum(all, true),
            outCents: _filter == _Filter.income ? null : sum(all, false),
            count: shown.length,
          ),
        ],
        if (all.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: Space.lg),
            child: EmptyState(
              icon: Icons.receipt_long_rounded,
              title: 'No records for $year yet',
              body: 'Everything you add lands here, grouped by month and searchable in an instant.',
              actionLabel: 'Add a record',
              onAction: () => openEntry(context),
            ),
          )
        else if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.all(Space.xxl),
            child: Text(
              'Nothing here yet for this filter.',
              textAlign: TextAlign.center,
              style: context.text.bodySmall,
            ),
          )
        else
          AnimatedSwitcher(
            duration: Motion.reduced(context) ? Duration.zero : Motion.medium,
            switchInCurve: Motion.enter,
            child: Column(
              key: ValueKey(_filter),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, m) in byMonth.entries.indexed)
                  Reveal(
                    index: i,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _MonthHeader(
                          month: DateTime(year, m.key),
                          count: m.value.length,
                          netCents: sum(m.value, true) - sum(m.value, false),
                        ),
                        LLGroup(
                          children: [
                            for (final e in m.value)
                              Dismissible(
                                key: ValueKey(e.id),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: Space.xl),
                                  color: ll.expense,
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Delete',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                                      ),
                                      SizedBox(width: Space.sm),
                                      Icon(Icons.delete_outline_rounded, color: Colors.white),
                                    ],
                                  ),
                                ),
                                onDismissed: (_) => _delete(e),
                                child: EntryTile(entry: e, rules: rules!),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Money in / out for the current filter. Counts when the filter changes.
class _InOutStrip extends StatelessWidget {
  final int? inCents, outCents;
  final int count;
  const _InOutStrip({required this.inCents, required this.outCents, required this.count});

  @override
  Widget build(BuildContext context) {
    final ll = context.ll;
    Widget cell(String label, int cents, Color color, IconData icon) => Expanded(
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: Space.sm),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: context.text.labelMedium),
                AnimatedMoney(cents, style: context.text.titleMedium),
              ],
            ),
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          if (inCents != null) cell('Money in', inCents!, ll.income, Icons.south_west_rounded),
          if (outCents != null) cell('Money out', outCents!, ll.expense, Icons.north_east_rounded),
          Text('$count record${count == 1 ? '' : 's'}', style: context.text.labelMedium),
        ],
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  final DateTime month;
  final int count, netCents;
  const _MonthHeader({required this.month, required this.count, required this.netCents});

  @override
  Widget build(BuildContext context) {
    final ll = context.ll;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, Space.xl, 4, Space.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            DateFormat.MMMM().format(month),
            style: context.text.titleLarge?.copyWith(fontFamily: Fonts.voice, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: Space.sm),
          Text('$count record${count == 1 ? '' : 's'}', style: context.text.labelMedium),
          const Spacer(),
          Text(
            '${netCents >= 0 ? '+' : '−'}${formatCents(netCents.abs())}',
            semanticsLabel: '${netCents >= 0 ? 'net' : 'net minus'} ${formatCents(netCents.abs())}',
            style: context.text.labelLarge?.copyWith(
              color: netCents >= 0 ? ll.income : ll.muted,
              fontFeatures: tabular,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================== Taxes ==============================

String _pct(double? f, int digits) => f == null ? '…' : '${(f * 100).toStringAsFixed(digits)}%';

class TaxesTab extends ConsumerWidget {
  const TaxesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appControllerProvider);
    final year = app.selectedYear;
    final rules = ref.watch(taxRulesProvider(year)).value;
    final s = ref.watch(summaryProvider(year));
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
              Text('Self-employment tax so far ($year)', style: context.text.bodySmall),
              const SizedBox(height: 4),
              MoneyText(s.seTaxCents, style: context.text.headlineMedium),
              const SizedBox(height: Space.sm),
              Text(
                s.netCents <= 0
                    ? 'No profit yet, so no self-employment tax. Add income to see an estimate.'
                    : '${formatCents(s.netCents)} profit × ${_pct(rules?.seNetEarningsFactor, 2)} × '
                          '${_pct(rules?.seRate, 1)}. Half of it is deductible on Schedule 1. '
                          'Income tax comes on top and depends on your whole return.',
                style: context.text.bodySmall,
              ),
              const Divider(height: Space.lg),
              InkWell(
                onTap: () => _editW2(context, app, year),
                child: Row(
                  children: [
                    Expanded(child: Text('W-2 wages this year (optional)', style: context.text.bodyMedium)),
                    Text(
                      app.w2WagesCents[year] == null ? 'Add' : formatCents(app.w2WagesCents[year]!),
                      style: context.text.bodyMedium?.copyWith(color: ll.accent, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Wages from a job use up the Social Security limit first, which can lower this estimate. '
                'At high incomes a separate 0.9% Medicare tax may also apply (Form 8959).',
                style: context.text.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.md),
        LLCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Set aside for taxes',
                      style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  MoneyText(s.setAsideCents, style: context.text.titleMedium),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${s.setAsidePct.round()}% of profit. A quarter of this per payment is a reasonable rule of thumb.',
                style: context.text.bodySmall,
              ),
              Slider(
                value: s.setAsidePct.clamp(10, 45),
                min: 10,
                max: 45,
                divisions: 7,
                label: '${s.setAsidePct.round()}%',
                onChanged: (v) => app.setSetAsidePct(v),
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
        if (rules != null && s.lines.isNotEmpty) ...[
          const SectionHeader('Schedule C so far'),
          LLGroup(
            children: [
              for (final l in rules.lineNames.entries)
                if (s.lines[l.key] != null)
                  ListTile(
                    dense: true,
                    leading: SizedBox(
                      width: 36,
                      child: Text(
                        l.key,
                        style: context.text.labelLarge?.copyWith(color: ll.muted, fontFeatures: tabular),
                      ),
                    ),
                    title: Text(l.value),
                    trailing: MoneyText(s.lines[l.key]!, style: context.text.bodyMedium),
                  ),
            ],
          ),
        ],
        GuidanceSection(year: year),
        const SectionHeader('Tools'),
        LLGroup(
          children: [
            for (final (icon, title, sub, Widget screen) in [
              (Icons.payments_outlined, 'Payment log', 'Record what you\'ve paid the IRS', PaymentLogScreen(year)),
              (Icons.directions_car_outlined, 'Mileage', 'Standard mileage rate, trip by trip', MileageScreen(year)),
              (Icons.home_work_outlined, 'Home office', 'Simplified method', HomeOfficeScreen(year)),
              (Icons.description_outlined, '1099 tracker', 'Match forms to your income', Forms1099Screen(year)),
            ])
              ListTile(
                leading: Icon(icon),
                title: Text(title),
                subtitle: Text(sub),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen)),
              ),
            ListTile(
              leading: const Icon(Icons.ios_share_rounded),
              title: const Text('Export CSV'),
              subtitle: const Text('Records, mileage or payments for a spreadsheet or preparer'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => showExportSheet(context, ref, year),
            ),
          ],
        ),
      ],
    );
  }
}

/// Text with case-insensitive prefix matches of [terms] in bold accent colour.
class HighlightText extends StatelessWidget {
  final String text;
  final List<String> terms;
  final int? maxLines;
  const HighlightText(this.text, this.terms, {super.key, this.maxLines});

  @override
  Widget build(BuildContext context) {
    final words = [
      for (final t in terms)
        if (t.trim().isNotEmpty) RegExp.escape(t.trim()),
    ];
    if (words.isEmpty) return Text(text, maxLines: maxLines, overflow: TextOverflow.ellipsis);
    final re = RegExp('(?:^|(?<=[^\\p{L}\\p{N}]))(${words.join('|')})', caseSensitive: false, unicode: true);
    final spans = <TextSpan>[];
    var last = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      spans.add(
        TextSpan(
          text: m[0],
          style: TextStyle(fontWeight: FontWeight.w700, color: context.ll.accent),
        ),
      );
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return Text.rich(
      TextSpan(children: spans),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}

Future<void> _editW2(BuildContext context, AppController app, int year) async {
  final c = TextEditingController(
    text: app.w2WagesCents[year] == null ? '' : (app.w2WagesCents[year]! / 100).toStringAsFixed(0),
  );
  final v = await showDialog<int>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text('W-2 wages for $year'),
      content: TextField(
        controller: c,
        autofocus: true,
        enableIMEPersonalizedLearning: false,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
        decoration: const InputDecoration(
          prefixText: '\$',
          helperText: 'Social Security wages (W-2 box 3), all jobs. Stays on this phone.',
          helperMaxLines: 2,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(d, (int.tryParse(c.text) ?? 0) * 100), child: const Text('Save')),
      ],
    ),
  );
  c.dispose();
  if (v != null) await app.setW2Wages(year, v);
}
