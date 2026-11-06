// Golden screenshots of the design system (M2). Regenerate with:
//   flutter test test/goldens_test.dart --update-goldens
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerlock/app/app_controller.dart';
import 'package:ledgerlock/data/database.dart';
import 'package:ledgerlock/data/tax_rules.dart';
import 'package:ledgerlock/security/biometric_reset.dart';
import 'package:ledgerlock/security/vault.dart';
import 'package:ledgerlock/ui/backup_screens.dart';
import 'package:ledgerlock/ui/design/components.dart';
import 'package:ledgerlock/ui/design/theme.dart';
import 'package:ledgerlock/ui/ledger/entry_screen.dart';
import 'package:ledgerlock/ui/lock_screens.dart';
import 'package:ledgerlock/ui/recovery_screens.dart';
import 'package:ledgerlock/search/search_service.dart';
import 'package:ledgerlock/ui/search/search_screen.dart';
import 'package:ledgerlock/tax/guidance.dart';
import 'package:ledgerlock/ui/settings_screen.dart';
import 'package:ledgerlock/tax/checkin.dart';
import 'package:ledgerlock/ui/taxes/checkin_screen.dart';
import 'package:ledgerlock/ui/taxes/guidance_section.dart';
import 'package:ledgerlock/data/tax_packet.dart';
import 'package:ledgerlock/ui/ledger/import_screen.dart';
import 'package:ledgerlock/ui/ledger/recurring_screen.dart';
import 'package:ledgerlock/ui/ledger/budgets_screen.dart';
import 'package:ledgerlock/ui/shell/insights_card.dart';
import 'package:ledgerlock/data/insights.dart';
import 'package:ledgerlock/ui/onboarding_screens.dart';
import 'package:ledgerlock/ui/taxes/tools.dart';
import 'package:ledgerlock/ui/shell/app_shell.dart';

class FakeBiometrics implements BiometricSecretStore {
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<void> save(Uint8List s) async {}
  @override
  Future<Uint8List?> read() async => null;
  @override
  Future<void> delete() async {}
}

/// Accessibility audit on every golden screen (M8): Android tap targets (48 dp) and labelled tap targets.
/// Contrast is checked exactly on the palette in a11y_palette_test.dart (the pixel-sampling guideline misreads
/// anti-aliased small text at 1x). LL_A11Y=report prints instead of failing; LL_A11Y=contrast adds the sampler.
Future<void> _audit(WidgetTester t, String name) async {
  final handle = t.ensureSemantics();
  try {
    for (final (label, g) in [
      ('tap-target', androidTapTargetGuideline),
      ('label', labeledTapTargetGuideline),
      if (Platform.environment['LL_A11Y'] == 'contrast') ('contrast', textContrastGuideline),
    ]) {
      final r = await g.evaluate(t);
      if (r.passed) continue;
      if (Platform.environment['LL_A11Y'] != null) {
        // ignore: avoid_print
        print('A11Y $name $label: ${(r.reason ?? '').replaceAll('\n', ' | ')}');
      } else {
        fail('A11Y $name $label: ${r.reason}');
      }
    }
  } finally {
    handle.dispose();
  }
}

Future<void> loadFonts() async {
  final dir = '${Platform.environment['HOME']}/flutter/bin/cache/artifacts/material_fonts';
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final file = File('$dir/$f');
      if (file.existsSync()) loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    }
    await loader.load();
  }

  await load('Roboto', ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']);
  Future<void> bundled(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(Future.value(ByteData.sublistView(File('assets/fonts/$f').readAsBytesSync())));
    }
    await loader.load();
  }

  await bundled('Manrope', [
    for (final w in [400, 500, 600, 700, 800]) 'Manrope-$w.ttf',
  ]);
  await bundled('Fraunces', ['Fraunces-500.ttf', 'Fraunces-600.ttf']);
  Motion.ambient = false; // looping animation would never settle
  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
}

int recordedEtsy() => recordedFrom('Etsy', fixtureEntries().where((e) => e.date.startsWith('2026')));

List<LedgerEntry> fixtureEntries() {
  final raw = jsonDecode(File('test/fixtures/ledger_records.json').readAsStringSync()) as List;
  var id = 0;
  return [
    for (final r in raw.cast<Map<String, dynamic>>())
      LedgerEntry(
        id: ++id,
        isIncome: r['kind'] == 'income',
        date: r['date'] as String,
        amountCents: r['amountCents'] as int,
        feeCents: r['feeCents'] as int? ?? 0,
        businessPct: r['businessPct'] as int? ?? 100,
        category: r['category'] as String,
        party: r['party'] as String? ?? '',
        paid: true,
        platform: r['platform'] as String? ?? '',
        notes: '',
        tags: '',
        createdAt: DateTime(2026),
      ),
  ]..sort((a, b) => b.date.compareTo(a.date));
}

final _storeMode = Platform.environment['LL_STORE'] == '1';

/// Screens for the store listing, in order (file name = order_name).
const _storeShots = {
  'home': '1_home',
  'records_filled': '2_records',
  'taxes_filled': '3_taxes',
  'search_results': '4_search',
  'vault': '5_vault',
  'welcome': '6_privacy',
};

void main() {
  late Map<int, TaxRules> rules;
  late Directory dir;

  setUpAll(() async {
    await loadFonts();
    rules = {for (final y in TaxRules.supportedYears) y: await TaxRules.load(y)};
  });
  setUp(() => dir = Directory.systemTemp.createTempSync('ll_gold'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> shoot(
    WidgetTester t,
    String name,
    Widget home,
    Brightness b, {
    AppController? app,
    bool data = false,
    List<Override> extra = const [],
    double height = 844,
  }) async {
    // LL_STORE=1 + --update-goldens: re-render the store screens at 3x into the F-Droid/fastlane listing instead.
    final store = _storeShots[name];
    if (_storeMode && (store == null || b != Brightness.light)) return;
    final dpr = _storeMode ? 3.0 : 1.0;
    t.view.physicalSize = Size(390 * dpr, height * dpr); // logical phone size at 1x: small PNGs
    t.view.devicePixelRatio = dpr;
    addTearDown(t.view.reset);
    final controller = app ?? AppController(dataDir: dir, biometrics: FakeBiometrics(), year: 2026)
      ..biometricsAvailable = true;
    if (app == null) controller.debugShowReady(slots: {Slot.password, Slot.recovery, Slot.biometric});
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          ...extra,
          appControllerProvider.overrideWith((ref) => controller),
          todayProvider.overrideWithValue(DateTime(2026, 11, 1)),
          taxRulesProvider.overrideWith((ref, year) async => rules[year]!),
          entriesProvider.overrideWith(
            (ref, year) => Stream.value(data ? fixtureEntries().where((e) => e.date.startsWith('$year')).toList() : []),
          ),
        ],
        child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildTheme(b), home: home),
      ),
    );
    await t.pumpAndSettle();
    // Stream overrides deliver on a real event-loop turn.
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await t.pumpAndSettle();
    if (_storeMode) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../fastlane/metadata/android/en-US/images/phoneScreenshots/$store.png'),
      );
      return;
    }
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/${name}_${b.name}.png'));
    await _audit(t, '${name}_${b.name}');
  }

  for (final b in Brightness.values) {
    testWidgets('success ${b.name}', (t) async {
      t.view.physicalSize = const Size(390, 300);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildTheme(b),
          home: Builder(
            builder: (c) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showSuccess(
                    ScaffoldMessenger.of(c),
                    'Logged \$450.00 for Q4. It now counts toward your payments.',
                  ),
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('go'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 800));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/success_${b.name}.png'));
    });
  }

  for (final b in Brightness.values) {
    testWidgets('home ${b.name}', (t) => shoot(t, 'home', const AppShell(), b, data: true));
    testWidgets('welcome ${b.name}', (t) => shoot(t, 'welcome', WelcomeScreen(onStart: () {}, onRestore: () {}), b));
    testWidgets('restore ${b.name}', (t) => shoot(t, 'restore', const RestoreScreen(replacing: true), b));
    testWidgets(
      'business_type ${b.name}',
      (t) => shoot(t, 'business_type', BusinessTypeScreen(initial: const {'services'}, onDone: (_) async {}), b),
    );
    testWidgets('first_steps ${b.name}', (t) => shoot(t, 'first_steps', FirstStepsScreen(onDone: (_) {}), b));
    testWidgets('entry_expense ${b.name}', (t) => shoot(t, 'entry_expense', const EntryScreen(), b));
    testWidgets('entry_income ${b.name}', (t) => shoot(t, 'entry_income', const EntryScreen(startIncome: true), b));
    testWidgets('home_empty ${b.name}', (t) => shoot(t, 'home_empty', const AppShell(), b));
    testWidgets(
      'records_filled ${b.name}',
      (t) => shoot(t, 'records_filled', const AppShell(initialTab: 1), b, data: true),
    );
    testWidgets(
      'taxes_filled ${b.name}',
      (t) => shoot(
        t,
        'taxes_filled',
        const AppShell(initialTab: 3),
        b,
        data: true,
        extra: [
          paymentsProvider.overrideWith(
            (ref, y) => Stream.value(const [
              TaxPayment(
                id: 1,
                taxYear: 2026,
                quarter: 'Q1',
                date: '2026-04-14',
                amountCents: 40000,
                method: '',
                notes: '',
              ),
              TaxPayment(
                id: 2,
                taxYear: 2026,
                quarter: 'Q2',
                date: '2026-06-12',
                amountCents: 40000,
                method: '',
                notes: '',
              ),
            ]),
          ),
        ],
      ),
    );
    testWidgets(
      'taxes_full ${b.name}',
      (t) => shoot(t, 'taxes_full', const AppShell(initialTab: 3), b, data: true, height: 2300),
    );
    testWidgets('records ${b.name}', (t) => shoot(t, 'records', const AppShell(initialTab: 1), b));
    testWidgets('vault ${b.name}', (t) => shoot(t, 'vault', const AppShell(initialTab: 2), b));
    testWidgets('taxes ${b.name}', (t) => shoot(t, 'taxes', const AppShell(initialTab: 3), b));
    testWidgets(
      'taxes_guidance ${b.name}',
      (t) => shoot(
        t,
        'taxes_guidance',
        const Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: GuidanceSection(year: 2026),
            ),
          ),
        ),
        b,
        data: true,
        extra: [
          // Layout preview only: the shipped list stays unverified until the owner-led review.
          resourcesProvider.overrideWith(
            (ref) async => [
              for (final r in jsonDecode(File('assets/tax_rules/resources.json').readAsStringSync())['resources'])
                Resource.fromJson({...r as Map<String, dynamic>, 'verified': 'preview'}),
            ],
          ),
        ],
      ),
    );
    testWidgets(
      'mileage ${b.name}',
      (t) => shoot(
        t,
        'mileage',
        const MileageScreen(2026),
        b,
        extra: [
          tripsProvider.overrideWith(
            (ref, y) => Stream.value(const [
              Trip(id: 2, date: '2026-08-04', milesTenths: 236, purpose: 'Client workshop', route: 'Home to Riverside'),
              Trip(id: 1, date: '2026-05-12', milesTenths: 84, purpose: 'Supplies run', route: ''),
            ]),
          ),
        ],
      ),
    );
    testWidgets(
      'forms1099 ${b.name}',
      (t) => shoot(
        t,
        'forms1099',
        const Forms1099Screen(2026),
        b,
        data: true,
        extra: [
          forms1099Provider.overrideWith(
            (ref, y) => Stream.value([
              Form1099(id: 1, year: 2026, kind: '1099-K', payer: 'Etsy', amountCents: recordedEtsy()),
              const Form1099(id: 2, year: 2026, kind: '1099-NEC', payer: 'Studio Co', amountCents: 120000),
            ]),
          ),
        ],
      ),
    );
    testWidgets(
      'rules ${b.name}',
      (t) => shoot(
        t,
        'rules',
        const RulesScreen(),
        b,
        data: true,
        extra: [
          categoryRulesProvider.overrideWith(
            (ref) => Stream.value(const [
              CategoryRule(id: 1, isIncome: false, contains: 'anthropic', category: 'software', learned: false),
              CategoryRule(
                id: 2,
                isIncome: false,
                contains: 'verizon',
                category: 'utilities',
                businessPct: 40,
                learned: false,
              ),
              CategoryRule(id: 3, isIncome: false, contains: 'staples', category: 'office', learned: true),
            ]),
          ),
        ],
      ),
    );
    AppController budgetApp() => AppController(dataDir: dir, biometrics: FakeBiometrics(), year: 2026)
      ..biometricsAvailable = true
      ..debugShowReady(slots: {Slot.password, Slot.recovery, Slot.biometric})
      ..budgets = {'meals': 2000, 'software': 5000, 'office': 30000}
      ..incomeGoals = {2026: 2000000};
    testWidgets(
      'budgets_card ${b.name}',
      (t) => shoot(
        t,
        'budgets_card',
        const Scaffold(
          body: Padding(padding: EdgeInsets.all(16), child: BudgetsCard(year: 2026)),
        ),
        b,
        data: true,
        app: budgetApp(),
      ),
    );
    testWidgets(
      'budgets_screen ${b.name}',
      (t) => shoot(t, 'budgets_screen', const BudgetsScreen(), b, data: true, app: budgetApp()),
    );
    testWidgets(
      'insights ${b.name}',
      (t) => shoot(
        t,
        'insights',
        const Scaffold(
          body: Padding(padding: EdgeInsets.all(16), child: InsightsCard(year: 2026)),
        ),
        b,
        data: true,
        extra: [
          insightsProvider.overrideWith(
            (ref, y) => const [
              Insight('income', thisCents: 1245000, lastCents: 940000),
              Insight('category', category: 'software', thisCents: 142000, lastCents: 98000),
              Insight('new_category', category: 'travel', thisCents: 38750, lastCents: 0),
              Insight('category', category: 'office', thisCents: 21000, lastCents: 64000),
            ],
          ),
        ],
      ),
    );
    testWidgets(
      'recurring ${b.name}',
      (t) => shoot(
        t,
        'recurring',
        const RecurringScreen(),
        b,
        data: true,
        extra: [
          recurringProvider.overrideWith(
            (ref) => Stream.value(const [
              Recurring(
                tags: '',
                paid: true,
                id: 1,
                isIncome: false,
                amountCents: 2000,
                feeCents: 0,
                businessPct: 100,
                category: 'software',
                party: 'Adobe',
                platform: '',
                notes: '',
                every: 'month',
                anchorDay: 14,
                nextDate: '2026-11-14',
              ),
              Recurring(
                tags: '',
                paid: true,
                id: 2,
                isIncome: false,
                amountCents: 8500,
                feeCents: 0,
                businessPct: 40,
                category: 'utilities',
                party: 'Verizon',
                platform: '',
                notes: '',
                every: 'month',
                anchorDay: 3,
                nextDate: '2026-12-03',
              ),
              Recurring(
                tags: '',
                paid: true,
                id: 3,
                isIncome: true,
                amountCents: 60000,
                feeCents: 0,
                businessPct: 100,
                category: 'services',
                party: 'Retainer client',
                platform: '',
                notes: '',
                every: 'week',
                anchorDay: 2,
                nextDate: '2026-11-02',
              ),
            ]),
          ),
        ],
      ),
    );
    testWidgets(
      'import_map ${b.name}',
      (t) => shoot(
        t,
        'import_map',
        const ImportScreen(
          initialRows: [
            ['Posting Date', 'Description', 'Amount', 'Type', 'Balance'],
            ['01/05/2026', 'ADOBE *CREATIVE CLD', '-19.99', 'Debit', '1,980.01'],
            ['01/06/2026', 'STRIPE TRANSFER', '500.00', 'Credit', '2,480.01'],
            ['01/08/2026', 'STAPLES 0042', '-36.50', 'Debit', '2,443.51'],
          ],
        ),
        b,
      ),
    );
    testWidgets(
      'checkin ${b.name}',
      (t) => shoot(
        t,
        'checkin',
        const CheckInScreen(),
        b,
        extra: [
          checkInProvider.overrideWithValue(const [
            CheckInQuestion(
              'a',
              'Q4 estimated tax is due Jan 15. Have you paid? Log it so your numbers stay right.',
              CheckInAction.paymentLog,
            ),
            CheckInQuestion(
              'b',
              'You usually record Adobe every month. Nothing for November yet: missed one?',
              CheckInAction.addEntry,
            ),
            CheckInQuestion(
              'c',
              '3 expenses have no receipt attached. Add the ones you have?',
              CheckInAction.receipts,
              query: 'no receipt',
            ),
          ]),
        ],
      ),
    );
    testWidgets('search ${b.name}', (t) => shoot(t, 'search', const SearchScreen(), b));
    testWidgets(
      'search_results ${b.name}',
      (t) => shoot(
        t,
        'search_results',
        SearchScreen(
          initialText: 'over 20 in 2026',
          searchOverride: (q) async => SearchResults(
            [
              for (final e in fixtureEntries())
                if (e.date.startsWith('2026') && !e.isIncome && e.amountCents >= q.minCents!) e,
            ].take(6).toList(),
            const [],
            const Duration(milliseconds: 3),
          ),
        ),
        b,
      ),
    );
    testWidgets('settings ${b.name}', (t) => shoot(t, 'settings', const SettingsScreen(), b));
    testWidgets(
      'unlock ${b.name}',
      (t) => shoot(t, 'unlock', UnlockScreen(onSubmit: (_) async {}, onForgot: () {}), b),
    );
    testWidgets('setup ${b.name}', (t) => shoot(t, 'setup', SetupScreen(onSubmit: (_) async {}), b));
    testWidgets(
      'recovery_key ${b.name}',
      (t) => shoot(
        t,
        'recovery_key',
        RecoveryKeyScreen(code: 'K7Q2M-9XH4T-PB3WN-R6ZC8-JD1VF-5GAEY', onConfirmed: () {}),
        b,
      ),
    );
  }
}
