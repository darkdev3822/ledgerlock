// Year-end checklist screen + Home card (lib/data/year_end.dart). Shown Dec 1 - Jan 31 for the tax year ending,
// until it's all done or the year is marked filed.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../data/tax_rules.dart';
import '../../data/year_end.dart';
import '../backup_screens.dart';
import '../design/components.dart';
import '../design/theme.dart';
import '../search/search_screen.dart';
import '../shell/attention_card.dart';
import 'tools.dart';

/// The checklist for [year], or null while its data is loading / the year has no rules.
List<YearEndItem>? yearEndFor(WidgetRef ref, int year) {
  final app = ref.watch(appControllerProvider);
  final rules = ref.watch(taxRulesProvider(year)).value;
  final payments = ref.watch(paymentsProvider(year)).value;
  final trips = ref.watch(tripsProvider(year)).value;
  final forms = ref.watch(forms1099Provider(year)).value;
  if (rules == null || payments == null || trips == null || forms == null) return null;
  return yearEndItems(
    year: year,
    rules: rules,
    today: ref.watch(todayProvider),
    attention: ref.watch(attentionProvider(year)),
    payments: payments,
    trips: trips,
    forms: forms,
    drives: app.businessTypes.contains('driving'),
    lastBackup: app.lastBackup,
    ticked: app.yearEndTicks[year] ?? const {},
  );
}

/// The year whose checklist Home should show now, or null (outside the window, unsupported, filed or all done).
int? yearEndDue(WidgetRef ref) {
  final y = yearEndYear(ref.watch(todayProvider));
  final app = ref.watch(appControllerProvider);
  if (y == null || !TaxRules.supportedYears.contains(y) || app.filedYears.contains(y)) return null;
  final items = yearEndFor(ref, y);
  if (items == null || items.every((i) => i.done)) return null;
  return y;
}

class YearEndCard extends ConsumerWidget {
  final int year;
  const YearEndCard({super.key, required this.year});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = yearEndFor(ref, year) ?? const [];
    final done = items.where((i) => i.done).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('Wrapping up $year'),
        LLCard(
          padding: const EdgeInsets.symmetric(vertical: Space.xs),
          child: ListTile(
            leading: Icon(Icons.checklist_rounded, color: context.ll.accent),
            title: const Text('Year-end checklist'),
            subtitle: Text('$done of ${items.length} done · tie up loose ends before you file'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => YearEndScreen(year: year))),
          ),
        ),
      ],
    );
  }
}

class YearEndScreen extends ConsumerWidget {
  final int year;
  const YearEndScreen({super.key, required this.year});

  void _go(BuildContext context, WidgetRef ref, YearEndItem i) {
    final app = ref.read(appControllerProvider);
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    switch (i.action) {
      case 'backup':
        runBackup(context, app);
      case 'receipts':
        openSearch(context, text: 'no receipt > 75 in $year');
      case 'invoices':
        openSearch(context, text: 'unpaid in $year');
      case 'payments':
        push(PaymentLogScreen(year));
      case 'mileage':
        push(MileageScreen(year));
      case 'forms_1099':
        push(Forms1099Screen(year));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appControllerProvider);
    final items = yearEndFor(ref, year);
    final filed = app.filedYears.contains(year);
    return Scaffold(
      appBar: AppBar(title: Text('Wrapping up $year')),
      body: items == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xl),
              children: [
                Text(
                  'A few loose ends to tie up before you file. LedgerLock ticks what it can check; tick the rest '
                  'yourself.',
                  style: context.text.bodyMedium,
                ),
                const SizedBox(height: Space.md),
                LLGroup(
                  children: [
                    for (final i in items)
                      ListTile(
                        leading: i.auto
                            ? Icon(
                                i.done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                color: i.done ? context.ll.accent : null,
                                semanticLabel: i.done ? 'Done' : 'Not done',
                              )
                            : Checkbox(value: i.done, onChanged: (_) => app.toggleYearEnd(year, i.id)),
                        title: Text(i.title),
                        subtitle: Text(i.detail),
                        trailing: i.action == 'none' ? null : const Icon(Icons.chevron_right_rounded),
                        onTap: i.action == 'none' ? () => app.toggleYearEnd(year, i.id) : () => _go(context, ref, i),
                      ),
                  ],
                ),
                const SizedBox(height: Space.lg),
                LLCard(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('I\'ve filed my $year return'),
                    subtitle: const Text('Marks the year Filed; edits to it then warn you first.'),
                    value: filed,
                    onChanged: (v) => app.setFiled(year, v),
                  ),
                ),
              ],
            ),
    );
  }
}
