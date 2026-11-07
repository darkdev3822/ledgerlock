// Learn (lib/learn/lessons.dart): tracks matched to how the user earns, two-minute lessons with a "What this means
// for you" part computed from their own records, one action, and verified sources. Offline; progress is encrypted.
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/app_controller.dart';
import '../../data/database.dart';
import '../../data/ledger.dart';
import '../../data/tax_rules.dart';
import '../../learn/lessons.dart';
import '../../tax/guidance.dart';
import '../design/components.dart';
import '../design/theme.dart';
import '../ledger/entry_screen.dart';
import '../search/search_screen.dart';
import '../shell/attention_card.dart';
import '../taxes/guidance_section.dart' show confirmOpenResource;
import '../taxes/tools.dart';

final lessonLibraryProvider = FutureProvider<LessonLibrary>((ref) => LessonLibrary.load());

/// Debug builds show draft lessons (badged) so the owner can review them on a device; release builds never do.
/// Off under `flutter test` (goldens stay as users see them) unless a test turns it on.
bool showLessonDrafts = kDebugMode && !Platform.environment.containsKey('FLUTTER_TEST');

Future<void> openLearn(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LearnScreen()));

Future<void> openLesson(BuildContext context, Lesson l) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => LessonScreen(lesson: l)));

class LearnScreen extends ConsumerWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lib = ref.watch(lessonLibraryProvider).value;
    final app = ref.watch(appControllerProvider);
    final tracks = lib?.tracksFor(app.businessTypes, drafts: showLessonDrafts) ?? const <LessonTrack>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Learn')),
      body: lib == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xl),
              children: [
                Text(
                  'Short lessons on taxes and running a side business, picked for how you earn. Everything here is '
                  'on this phone; nothing is sent anywhere.',
                  style: context.text.bodyMedium,
                ),
                if (tracks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: Space.xl),
                    child: Text('Lessons are on their way.', style: context.text.titleSmall),
                  ),
                for (final t in tracks) ...[
                  SectionHeader(t.title),
                  LLGroup(
                    children: [
                      for (final l in lib.inTrack(t.id, drafts: showLessonDrafts))
                        ListTile(
                          leading: Icon(
                            app.lessonsDone.contains(l.id) ? Icons.check_circle_rounded : Icons.circle_outlined,
                            color: app.lessonsDone.contains(l.id) ? context.ll.accent : null,
                          ),
                          title: Text(l.title),
                          subtitle: Text('${l.minutes} min${l.verified ? '' : ' · DRAFT, not reviewed'}'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => openLesson(context, l),
                        ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}

class LessonScreen extends ConsumerWidget {
  final Lesson lesson;
  const LessonScreen({super.key, required this.lesson});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appControllerProvider);
    final year = app.selectedYear;
    final rules = ref.watch(taxRulesProvider(year)).value;
    final resources = ref.watch(resourcesProvider).value ?? const <Resource>[];
    final done = app.lessonsDone.contains(lesson.id);
    final you = rules == null ? null : _youText(ref, lesson.you, year, rules);
    final action = _action(context, ref, lesson.action, year);
    return Scaffold(
      appBar: AppBar(title: Text('${lesson.minutes}-minute read')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xl),
        children: [
          if (!lesson.verified)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: Text(
                'DRAFT: not reviewed yet. Shown only in test builds.',
                style: context.text.labelMedium?.copyWith(color: context.ll.warning, fontWeight: FontWeight.w700),
              ),
            ),
          Text(lesson.title, style: context.text.headlineSmall),
          const SizedBox(height: Space.md),
          if (rules == null)
            const LinearProgressIndicator()
          else
            for (final p in lesson.body)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.md),
                child: Text(fillLesson(p, rules), style: context.text.bodyLarge),
              ),
          if (you != null) ...[
            const SectionHeader('What this means for you'),
            LLCard(child: Text(you, style: context.text.bodyMedium)),
          ],
          if (action != null) ...[
            const SizedBox(height: Space.md),
            Align(alignment: Alignment.centerLeft, child: action),
          ],
          if (lesson.sources.isNotEmpty) ...[
            const SectionHeader('From the source'),
            LLGroup(
              children: [
                for (final r in resources.where((r) => lesson.sources.contains(r.id)))
                  ListTile(
                    leading: const Icon(Icons.open_in_new_rounded),
                    title: Text(r.name),
                    subtitle: Text(Uri.parse(r.url).host),
                    onTap: () => confirmOpenResource(context, r),
                  ),
              ],
            ),
          ],
          const SizedBox(height: Space.lg),
          Text(
            'General information, not tax advice. Your situation can differ; a preparer or the IRS can confirm.',
            style: context.text.bodySmall,
          ),
          const SizedBox(height: Space.lg),
          FilledButton.icon(
            onPressed: () {
              app.markLessonDone(lesson.id, done: !done);
              if (!done) Navigator.of(context).pop();
            },
            icon: Icon(done ? Icons.undo_rounded : Icons.check_rounded),
            label: Text(done ? 'Mark as not read' : 'Got it'),
          ),
        ],
      ),
    );
  }
}

/// "What this means for you": plain sentences from the user's own numbers. Null when there's nothing to say.
String? _youText(WidgetRef ref, String kind, int year, TaxRules rules) {
  final app = ref.read(appControllerProvider);
  final s = ref.watch(summaryProvider(year));
  String m(int c) => formatCents(c);
  switch (kind) {
    case 'se_tax':
      return s.netCents <= 0
          ? 'No profit recorded for $year yet, so no self-employment tax so far.'
          : 'So far in $year: ${m(s.netCents)} profit, about ${m(s.seTaxCents)} in self-employment tax on it '
                '(on all your businesses together).';
    case 'profit':
      return 'So far in $year: ${m(s.grossCents)} in, ${m(s.expensesCents)} in deductible expenses, '
          '${m(s.netCents)} ${s.netCents < 0 ? 'loss' : 'profit'}.';
    case 'set_aside':
      return s.netCents <= 0
          ? 'Nothing to set aside yet for $year.'
          : 'At ${s.setAsidePct.round()}% of ${m(s.netCents)} profit, that\'s ${m(s.setAsideCents)} so far for $year.';
    case 'quarterly':
      final today = ref.read(todayProvider);
      final paid = (ref.watch(paymentsProvider(year)).value ?? const <TaxPayment>[]).fold(
        0,
        (a, p) => a + p.amountCents,
      );
      final next = rules.quarterlyDue.where((q) => !q.due.isBefore(DateTime(today.year, today.month, today.day)));
      final left = s.setAsideCents - paid;
      return [
        if (next.isNotEmpty) 'Next payment: ${next.first.quarter}, due ${DateFormat.yMMMd().format(next.first.due)}.',
        'Logged so far for $year: ${m(paid)}.',
        if (left > 0) 'About ${m(left)} more keeps you on pace with your set-aside.',
      ].join(' ');
    case 'records':
      final missing = ref.watch(attentionProvider(year)).where((i) => i.kind == 'no_receipt');
      return missing.isEmpty
          ? 'Every expense over \$75 this year has a receipt attached.'
          : '${missing.first.count} expense${missing.first.count == 1 ? '' : 's'} over \$75 '
                'this year ${missing.first.count == 1 ? 'has' : 'have'} no receipt yet.';
    case 'cash_basis':
      final unpaid = (ref.watch(entriesProvider(year)).value ?? const <LedgerEntry>[])
          .where((e) => e.isIncome && !e.paid)
          .toList();
      return unpaid.isEmpty
          ? 'You have no unpaid invoices for $year.'
          : '${unpaid.length} unpaid invoice${unpaid.length == 1 ? '' : 's'} '
                '(${m(unpaid.fold(0, (a, e) => a + e.amountCents))}) ${unpaid.length == 1 ? 'is' : 'are'} '
                'not counted yet.';
    case 'forms_1099':
      final forms = ref.watch(forms1099Provider(year)).value ?? const <Form1099>[];
      final off = ref.watch(attentionProvider(year)).where((i) => i.kind == 'form_1099');
      return forms.isEmpty
          ? 'No 1099s entered for $year yet.'
          : '${forms.length} 1099${forms.length == 1 ? '' : 's'} entered for $year'
                '${off.isEmpty ? ', all matching your records.' : '; ${off.first.count} higher than your records.'}';
    case 'home_office':
      final sq = app.homeOfficeSqft[year];
      return sq == null || sq == 0
          ? 'You haven\'t set up a home office for $year.'
          : 'You\'ve entered $sq sq ft for $year.';
    case 'mileage':
      final trips = ref.watch(tripsProvider(year)).value ?? const <Trip>[];
      if (trips.isEmpty) return 'No trips logged for $year yet.';
      final tenths = trips.fold(0, (a, t) => a + t.milesTenths);
      final cents = mileageDeductionCents(trips.map((t) => (t.date, t.milesTenths)), rules);
      return '${trips.length} trip${trips.length == 1 ? '' : 's'}, ${(tenths / 10).toStringAsFixed(1)} miles in $year'
          '${cents > 0 ? ': about ${m(cents)} at the standard rate.' : '.'}';
  }
  return null;
}

Widget? _action(BuildContext context, WidgetRef ref, String action, int year) {
  Widget b(IconData i, String label, VoidCallback go) =>
      OutlinedButton.icon(onPressed: go, icon: Icon(i), label: Text(label));
  void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
  return switch (action) {
    'add_expense' => b(Icons.add_rounded, 'Add an expense', () => openEntry(context)),
    'add_income' => b(Icons.add_rounded, 'Add income', () => openEntry(context, income: true)),
    'open_payments' => b(Icons.payments_outlined, 'Log a payment', () => push(PaymentLogScreen(year))),
    'search_no_receipt' => b(
      Icons.receipt_long_outlined,
      'Find expenses without receipts',
      () => openSearch(context, text: 'no receipt > 75 in $year'),
    ),
    'search_unpaid' => b(
      Icons.schedule_rounded,
      'See unpaid invoices',
      () => openSearch(context, text: 'unpaid in $year'),
    ),
    'open_1099s' => b(Icons.description_outlined, 'Your 1099s', () => push(Forms1099Screen(year))),
    'open_home_office' => b(Icons.home_work_outlined, 'Home office', () => push(HomeOfficeScreen(year))),
    'log_trip' => b(Icons.directions_car_outlined, 'Log a trip', () {
      final m = MileageScreen(year);
      push(m);
      m.addTrip(context, ref);
    }),
    _ => null,
  };
}

/// Home: the one lesson whose moment has come ("Worth knowing"), dismissible. Hidden when there's none.
class LessonSuggestionCard extends ConsumerWidget {
  final int year;
  const LessonSuggestionCard({super.key, required this.year});

  static Lesson? pick(WidgetRef ref, int year) {
    final lib = ref.watch(lessonLibraryProvider).value;
    if (lib == null) return null;
    final app = ref.watch(appControllerProvider);
    final entries = ref.watch(entriesProvider(year)).value ?? const <LedgerEntry>[];
    final rules = ref.watch(taxRulesProvider(year)).value;
    final today = ref.watch(todayProvider);
    final day = DateTime(today.year, today.month, today.day);
    final next = rules?.quarterlyDue.where((q) => !q.due.isBefore(day)).firstOrNull;
    return suggestLesson(
      lib,
      types: app.businessTypes,
      done: app.lessonsDone,
      dismissed: app.lessonsDismissed,
      drafts: showLessonDrafts,
      triggers: activeTriggers(
        hasIncome: entries.any((e) => e.isIncome),
        has1099: (ref.watch(forms1099Provider(year)).value ?? const []).isNotEmpty,
        hasTrips: (ref.watch(tripsProvider(year)).value ?? const []).isNotEmpty,
        hasUnpaid: entries.any((e) => e.isIncome && !e.paid),
        hasMissingReceipts: ref.watch(attentionProvider(year)).any((i) => i.kind == 'no_receipt'),
        daysToNextDue: next?.due.difference(day).inDays,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = pick(ref, year);
    if (l == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Worth knowing'),
        LLCard(
          padding: const EdgeInsets.symmetric(vertical: Space.xs),
          child: ListTile(
            leading: Icon(Icons.school_outlined, color: context.ll.accent),
            title: Text(l.title),
            subtitle: Text('${l.minutes}-minute read${l.verified ? '' : ' · DRAFT'}'),
            onTap: () => openLesson(context, l),
            trailing: IconButton(
              tooltip: 'Not now',
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: () => ref.read(appControllerProvider).dismissLesson(l.id),
            ),
          ),
        ),
      ],
    );
  }
}

/// Taxes tab: entry to Learn with progress. Hidden until there's at least one lesson to show.
class LearnEntryCard extends ConsumerWidget {
  const LearnEntryCard({super.key});

  /// This user's lessons (empty until some are verified, in a release build).
  static List<Lesson> mine(WidgetRef ref) {
    final lib = ref.watch(lessonLibraryProvider).value;
    if (lib == null) return const [];
    final app = ref.watch(appControllerProvider);
    final tracks = {for (final t in lib.tracksFor(app.businessTypes, drafts: showLessonDrafts)) t.id};
    return [
      for (final l in lib.visible(drafts: showLessonDrafts))
        if (tracks.contains(l.track)) l,
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appControllerProvider);
    final mine = LearnEntryCard.mine(ref);
    if (mine.isEmpty) return const SizedBox.shrink();
    final read = mine.where((l) => app.lessonsDone.contains(l.id)).length;
    return LLCard(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: ListTile(
        leading: Icon(Icons.school_outlined, color: context.ll.accent),
        title: const Text('Learn'),
        subtitle: Text('Taxes and money for how you earn · $read of ${mine.length} read'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => openLearn(context),
      ),
    );
  }
}
