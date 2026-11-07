// QA fuzz: layout stress (text scale, narrow width, hostile data, both themes) and logic repros.
// Cases named FINDING were confirmed bugs, fixed in M9.5; they now run as regression tests.
// Run: flutter test test/fuzz/ui_stress_test.dart
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerlock/app/app_controller.dart';
import 'package:ledgerlock/data/csv_import.dart';
import 'package:ledgerlock/data/database.dart';
import 'package:ledgerlock/data/tax_rules.dart';
import 'package:ledgerlock/main.dart';
import 'package:ledgerlock/security/biometric_reset.dart';
import 'package:ledgerlock/security/vault.dart';
import 'package:ledgerlock/tax/checkin.dart';
import 'package:ledgerlock/ui/design/theme.dart';
import 'package:ledgerlock/ui/ledger/entry_screen.dart';
import 'package:ledgerlock/ui/ledger/import_screen.dart';
import 'package:ledgerlock/ui/ledger/recurring_screen.dart';
import 'package:ledgerlock/ui/search/search_screen.dart';
import 'package:ledgerlock/ui/ledger/budgets_screen.dart';
import 'package:ledgerlock/ui/ledger/businesses_screen.dart';
import 'package:ledgerlock/ui/ledger/categories_screen.dart';
import 'package:ledgerlock/ui/onboarding_screens.dart';
import 'package:ledgerlock/ui/recovery_screens.dart';
import 'package:ledgerlock/ui/settings_screen.dart';
import 'package:ledgerlock/ui/shell/app_shell.dart';
import 'package:ledgerlock/ui/shell/tabs.dart';
import 'package:ledgerlock/ui/taxes/checkin_screen.dart';
import 'package:ledgerlock/ui/taxes/tools.dart';

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

/// Controller backed by a plain in-memory database (no vault/session), for logic repros.
class DbController extends AppController {
  AppDatabase? testDb;
  DbController({required super.dataDir, required this.testDb}) : super(biometrics: FakeBiometrics(), year: 2026);
  @override
  AppDatabase? get db => testDb;
}

/// Simulates a slow phone: writes take 300 ms (real DB runs in a background isolate).
class SlowDb extends AppDatabase {
  SlowDb() : super(NativeDatabase.memory(setup: (d) => d.execute('PRAGMA foreign_keys = ON')));
  static const lag = Duration(milliseconds: 300);
  @override
  Future<int> addEntry(LedgerEntriesCompanion e) async {
    await Future<void>.delayed(lag);
    return super.addEntry(e);
  }

  @override
  Future<int> addPayment(TaxPaymentsCompanion p) async {
    await Future<void>.delayed(lag);
    return super.addPayment(p);
  }
}

/// Known findings are skipped; run with LL_FUZZ_CONFIRM=1 to see them fail.
/// testWidgets only takes a bool skip, so their names carry the FINDING text.
// All findings were fixed in M9.5, so every case now runs as a regression test.
const _confirm = true;

AppDatabase memDb() => AppDatabase(NativeDatabase.memory(setup: (d) => d.execute('PRAGMA foreign_keys = ON')));

Future<void> loadFonts() async {
  Future<void> bundled(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final p in paths) {
      final f = File(p);
      if (f.existsSync()) loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
    await loader.load();
  }

  final mf = '${Platform.environment['HOME']}/flutter/bin/cache/artifacts/material_fonts';
  await bundled('Roboto', ['$mf/Roboto-Regular.ttf', '$mf/Roboto-Medium.ttf', '$mf/Roboto-Bold.ttf']);
  await bundled('Manrope', [
    for (final w in [400, 500, 600, 700, 800]) 'assets/fonts/Manrope-$w.ttf',
  ]);
  await bundled('Fraunces', ['assets/fonts/Fraunces-500.ttf', 'assets/fonts/Fraunces-600.ttf']);
  await bundled('MaterialIcons', ['$mf/MaterialIcons-Regular.otf']);
  Motion.ambient = false;
}

final longName = 'X' * 200;
final emojiName = '🧾💸🔥🙂👩🏽‍💻' * 30;
final arabicName = 'شركة التصميم الرقمي المحدودة للخدمات الإبداعية ' * 4;
const huge = 99999999999; // $999,999,999.99

LedgerEntry _e(
  int id,
  String date, {
  bool income = false,
  int cents = 1000,
  int fee = 0,
  int pct = 100,
  String cat = 'software',
  String party = '',
  String platform = '',
  String notes = '',
  bool paid = true,
}) => LedgerEntry(
  businessId: 1,
  id: id,
  isIncome: income,
  date: date,
  amountCents: cents,
  feeCents: fee,
  businessPct: pct,
  category: cat,
  party: party,
  paid: paid,
  platform: platform,
  notes: notes,
  tags: '',
  createdAt: DateTime(2026),
);

List<LedgerEntry> hostileEntries() => [
  _e(1, '2026-10-30', cents: huge, party: longName, notes: longName),
  _e(2, '2026-10-29', income: true, cat: 'services', cents: huge, fee: huge, party: emojiName, platform: emojiName),
  _e(3, '2026-10-28', income: true, cat: 'product_sales', cents: huge, party: arabicName, platform: arabicName),
  _e(4, '2026-09-15', cents: 0, party: 'Zero'),
  _e(5, '2026-09-14', cents: -500000, party: 'Negative', pct: 0),
  _e(6, '2026-08-01', income: true, cat: 'services', cents: huge, party: longName, paid: false),
  _e(7, '2026-01-02', cat: 'other_expense', cents: huge, party: arabicName, pct: 35),
];

List<Override> hostileTools() => [
  paymentsProvider.overrideWith(
    (ref, y) => Stream.value([
      TaxPayment(id: 1, taxYear: y, quarter: 'Q1', date: '$y-04-14', amountCents: huge, method: longName, notes: ''),
      TaxPayment(id: 2, taxYear: y, quarter: '', date: '$y-06-12', amountCents: -100, method: emojiName, notes: ''),
    ]),
  ),
  tripsProvider.overrideWith(
    (ref, y) => Stream.value([
      Trip(businessId: 1, id: 1, date: '$y-08-04', milesTenths: 999999999, purpose: longName, route: arabicName),
      Trip(businessId: 1, id: 2, date: '$y-05-12', milesTenths: 0, purpose: emojiName, route: ''),
    ]),
  ),
  allTripsProvider.overrideWith(
    (ref, y) => Stream.value([
      Trip(businessId: 1, id: 1, date: '$y-08-04', milesTenths: 999999999, purpose: longName, route: arabicName),
      Trip(businessId: 1, id: 2, date: '$y-05-12', milesTenths: 0, purpose: emojiName, route: ''),
    ]),
  ),
  forms1099Provider.overrideWith(
    (ref, y) => Stream.value([
      Form1099(businessId: 1, id: 1, year: y, kind: '1099-K', payer: emojiName, amountCents: huge),
      Form1099(businessId: 1, id: 2, year: y, kind: '1099-NEC', payer: longName, amountCents: 0),
      Form1099(businessId: 1, id: 3, year: y, kind: '1099-MISC', payer: arabicName, amountCents: -1),
    ]),
  ),
  recurringProvider.overrideWith(
    (ref) => Stream.value([
      Recurring(
        businessId: 1,
        tags: '',
        paid: true,
        id: 1,
        isIncome: false,
        amountCents: huge,
        feeCents: 0,
        businessPct: 100,
        category: 'software',
        party: emojiName,
        platform: '',
        notes: '',
        every: 'month',
        anchorDay: 31,
        nextDate: '2026-11-30',
      ),
      Recurring(
        businessId: 1,
        tags: '',
        paid: true,
        id: 2,
        isIncome: true,
        amountCents: 1,
        feeCents: 0,
        businessPct: 100,
        category: 'unknown_cat',
        party: longName,
        platform: '',
        notes: '',
        every: 'year',
        anchorDay: 1,
        nextDate: '2027-01-01',
      ),
    ]),
  ),
  categoryRulesProvider.overrideWith(
    (ref) => Stream.value([
      CategoryRule(id: 1, isIncome: false, contains: longName.toLowerCase(), category: 'software', learned: false),
      CategoryRule(id: 2, isIncome: false, contains: arabicName, category: 'utilities', businessPct: 0, learned: true),
    ]),
  ),
];

/// Fixed check-in questions with long text (CheckInScreen layout).
final hostileCheckIn = checkInProvider.overrideWithValue([
  CheckInQuestion(
    'a',
    'You usually record $longName every month. Nothing for November yet: missed one?',
    CheckInAction.addEntry,
  ),
  CheckInQuestion('b', 'You usually record $arabicName every month.', CheckInAction.paymentLog),
  const CheckInQuestion('c', '99999 expenses have no receipt attached.', CheckInAction.receipts, query: 'no receipt'),
]);

void main() {
  late Map<int, TaxRules> rules;
  late Directory dir;

  setUpAll(() async {
    await loadFonts();
    rules = {for (final y in TaxRules.supportedYears) y: await TaxRules.load(y)};
  });
  setUp(() => dir = Directory.systemTemp.createTempSync('ll_fuzz'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<Object?> stress(
    WidgetTester t,
    Widget home, {
    required Brightness b,
    required double width,
    required double scale,
    List<LedgerEntry> entries = const [],
    List<Override> extra = const [],
    DateTime? today,
    double height = 844,
  }) async {
    t.view.physicalSize = Size(width, height);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final controller = AppController(dataDir: dir, biometrics: FakeBiometrics(), year: 2026)
      ..biometricsAvailable = true
      ..checkInFrequency = 'weekly'
      ..debugShowReady(slots: {Slot.password, Slot.recovery, Slot.biometric});
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          ...extra,
          appControllerProvider.overrideWith((ref) => controller),
          todayProvider.overrideWithValue(today ?? DateTime(2026, 11, 1, 9)),
          taxRulesProvider.overrideWith((ref, year) async => rules[year]!),
          entriesProvider.overrideWith(
            (ref, year) => Stream.value(entries.where((e) => e.date.startsWith('$year')).toList()),
          ),
          allEntriesProvider.overrideWith(
            (ref, year) => Stream.value(entries.where((e) => e.date.startsWith('$year')).toList()),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildTheme(b),
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: home,
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await t.pumpAndSettle();
    // LL_FUZZ_RAW=1: leave the error to the framework, which prints the full report (culprit widget + file).
    if (Platform.environment['LL_FUZZ_RAW'] == '1') return null;
    final err = t.takeException();
    return err;
  }

  // ---------------------------------------------------------------- layout stress
  final screens = <String, (Widget, List<Override>)>{
    'home': (const AppShell(), const []),
    'records': (const AppShell(initialTab: 1), const []),
    'vault': (const AppShell(initialTab: 2), const []),
    'taxes': (const AppShell(initialTab: 3), const []),
    'entry_new': (const EntryScreen(), const []),
    'entry_edit_long': (
      EntryScreen(
        existing: _e(
          9,
          '2026-10-01',
          income: true,
          cat: 'services',
          cents: 9999999999,
          fee: 500,
          party: longName,
          platform: emojiName,
          notes: arabicName,
        ),
      ),
      const [],
    ),
    'settings': (const SettingsScreen(), const []),
    'rules': (const RulesScreen(), const []),
    'recurring': (const RecurringScreen(), const []),
    'budgets': (const BudgetsScreen(), const []),
    'categories': (const CategoriesScreen(), const []),
    'businesses': (const BusinessesScreen(), const []),
    'import_map': (
      ImportScreen(
        initialRows: [
          ['Posting Date', 'Description $longName', 'Amount', 'Type', 'Balance'],
          ['01/05/2026', emojiName, '-999999999.99', 'Debit', '1,980.01'],
          ['01/06/2026', arabicName, '999999999.99', 'Credit', '2,480.01'],
          ['01/08/2026', longName, '0', 'Debit', '-2,443.51'],
        ],
      ),
      const [],
    ),
    'welcome': (WelcomeScreen(onStart: () {}), const []),
    'business_type': (BusinessTypeScreen(initial: const {'services'}, onDone: (_) async {}), const []),
    'first_steps': (FirstStepsScreen(onDone: (_) {}), const []),
    'biometric_offer': (BiometricOfferScreen(onEnable: () async {}, onSkip: () {}), const []),
    'checkin': (const CheckInScreen(), [hostileCheckIn]),
    'forms1099': (const Forms1099Screen(2026), const []),
    'mileage': (const MileageScreen(2026), const []),
    'payment_log': (const PaymentLogScreen(2026), const []),
    'home_office': (const HomeOfficeScreen(2026), const []),
  };
  // (width, text scale, height). The last two: a foldable's inner screen unfolded, upright and sideways (tester).
  const configs = [
    (390.0, 1.0, 844.0),
    (390.0, 1.3, 844.0),
    (320.0, 1.0, 844.0),
    (320.0, 1.3, 844.0),
    (390.0, 2.0, 844.0),
    (320.0, 2.0, 844.0),
    (880.0, 1.0, 950.0),
    (980.0, 1.0, 680.0),
  ];

  // Known failures found by this suite. AppShell uses an IndexedStack, so every tab test lays out all four tabs.
  String? layoutFinding(String name, double w, double s) {
    if ({'home', 'records', 'vault', 'taxes'}.contains(name) && !(w == 390 && s == 1.0)) {
      return 'FINDING L1-L4: AppShell overflows (hero header tabs.dart:175, app bar app_shell.dart:61, '
          'vault grid vault_screens.dart:122, quarter timeline tabs.dart:1140${s >= 2 ? ', bottom bar app_shell.dart:193, '
                    'EntryTile trailing tabs.dart:499' : ''})';
    }
    if (name == 'import_map' && !(w == 320 && s == 2.0)) {
      return 'FINDING U9: emoji payee cut mid surrogate pair (csv_import.dart:307) -> ArgumentError in Text';
    }
    return null;
  }

  for (final MapEntry(key: name, value: (widget, over)) in screens.entries) {
    for (final b in Brightness.values) {
      for (final (w, s, h) in configs) {
        for (final data in [true, false]) {
          final finding = layoutFinding(name, w, s);
          final id =
              'layout $name ${b.name} w${w.round()}${h == 844 ? '' : 'h${h.round()}'} x$s ${data ? 'hostile' : 'empty'}${finding == null ? '' : ' $finding'}';
          testWidgets(id, skip: finding != null && !_confirm, (t) async {
            final err = await stress(
              t,
              widget,
              b: b,
              width: w,
              scale: s,
              height: h,
              entries: data ? hostileEntries() : const [],
              extra: [...over, if (data) ...hostileTools()],
            );
            expect(err, isNull, reason: '$id: $err');
          });
        }
      }
    }
  }

  // ---------------------------------------------------------------- logic repros
  Future<DbController> pumpWithDb(WidgetTester t, Widget home, AppDatabase db, {DateTime? today}) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final c = DbController(dataDir: dir, testDb: db)..debugShowReady();
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          appControllerProvider.overrideWith((ref) => c),
          todayProvider.overrideWithValue(today ?? DateTime(2026, 11, 1, 9)),
          taxRulesProvider.overrideWith((ref, year) async => rules[year]!),
        ],
        child: MaterialApp(theme: buildTheme(Brightness.light), home: home),
      ),
    );
    await t.pumpAndSettle();
    return c;
  }

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 5; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await t.pump(const Duration(milliseconds: 100));
    }
    await t.pumpAndSettle();
  }

  Widget opener(Widget Function() screen) => Scaffold(
    body: Builder(
      builder: (c) => TextButton(
        onPressed: () => Navigator.of(c).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => screen())),
        child: const Text('open'),
      ),
    ),
  );

  // Tester report 2026-11-06: "keypad wasn't working", "couldn't put in records".
  testWidgets('U10 keypad comes back after typing in a text field', (t) async {
    final db = memDb();
    await pumpWithDb(t, opener(() => const EntryScreen()), db);
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextField, 'Paid to'), 'Staples');
    await t.pumpAndSettle();
    // Back closes the soft keyboard; the user then taps the amount or empty space.
    FocusManager.instance.primaryFocus?.unfocus();
    await t.pumpAndSettle();
    expect(find.text('5'), findsOneWidget, reason: 'keypad must be visible once no text field has focus');
    await t.tap(find.text('5'));
    await t.pump();
    expect(find.text(r'$0.05'), findsOneWidget);
    await t.runAsync(db.close);
  });

  testWidgets('U10b Android Back closing the soft keyboard brings the keypad back', (t) async {
    final db = memDb();
    await pumpWithDb(t, opener(() => const EntryScreen()), db);
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(TextField, 'Paid to'));
    t.view.viewInsets = const FakeViewPadding(bottom: 900); // keyboard up
    await t.pumpAndSettle();
    expect(find.text('5'), findsNothing, reason: 'keypad hides while the soft keyboard is up');
    t.view.viewInsets = FakeViewPadding.zero; // Back: keyboard down, field still focused
    await t.pumpAndSettle();
    addTearDown(t.view.resetViewInsets);
    expect(find.text('5'), findsOneWidget);
    await t.runAsync(db.close);
  });

  // Tester's phone is a foldable: the keypad grew with the screen WIDTH (aspect-ratio keys), so on the wide inner
  // screen it filled the page and the category chips were squeezed out -> Save never enabled.
  for (final (name, w, h) in [
    ('fold inner portrait', 880.0, 950.0),
    ('fold inner landscape', 980.0, 680.0),
    ('fold cover', 360.0, 800.0),
    ('tablet landscape', 1280.0, 760.0),
  ]) {
    testWidgets('U13 entry screen usable on $name (${w.toInt()}x${h.toInt()} dp)', (t) async {
      final db = memDb();
      await pumpWithDb(t, opener(() => const EntryScreen()), db);
      t.view.physicalSize = Size(w, h);
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      final screen = Offset.zero & Size(w, h);
      final keypadTop = t.getTopLeft(find.text('1')).dy;
      expect(keypadTop, greaterThan(h * 0.4), reason: 'keypad must not take over the screen');
      for (final f in [find.text('5'), find.text('Save expense'), find.byType(ChoiceChip).first]) {
        expect(screen.contains(t.getCenter(f)), isTrue, reason: '$f must be on screen');
      }
      await t.tap(find.text('5'));
      await t.tap(find.byType(ChoiceChip).first);
      await t.pump();
      await t.tap(find.text('Save expense'));
      await settle(t);
      final rows = await t.runAsync(() => db.watchYear(2026).first);
      expect(rows!.length, 1);
      await t.runAsync(db.close);
    });
  }

  testWidgets('R1 a new record set to repeat monthly saves the record and its repeat', (t) async {
    final db = memDb();
    await pumpWithDb(t, opener(() => const EntryScreen()), db);
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.tap(find.text('1'));
    await t.tap(find.text('5'));
    await t.tap(find.byType(ChoiceChip).first);
    await t.tap(find.text('Repeats'));
    await t.pumpAndSettle();
    await t.tap(find.text('Every month'));
    await t.pumpAndSettle();
    expect(find.text('Every month'), findsOneWidget);
    await t.tap(find.text('Save expense'));
    await settle(t);
    final rows = await t.runAsync(() => db.watchYear(2026).first);
    final rec = await t.runAsync(() => db.watchRecurring().first);
    expect(rows!.single.recurringId, rec!.single.id);
    expect(rec.single.every, 'month');
    expect(rec.single.amountCents, 15);
    expect(DateTime.parse(rec.single.nextDate).isAfter(DateTime.parse(rows.single.date)), isTrue);
    await t.runAsync(db.close);
  });

  testWidgets('B1 setting a budget from the dialog saves it without errors', (t) async {
    final db = memDb();
    final app = await pumpWithDb(t, opener(() => const BudgetsScreen()), db);
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.tap(find.text('Contract labor'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), '100');
    await t.tap(find.text('Save'));
    await settle(t);
    expect(t.takeException(), isNull);
    expect(find.text(r'$100 / mo'), findsOneWidget);
    expect(app.budgets['contract_labor'], 10000);
    await t.runAsync(db.close);
  });

  testWidgets('S1 search remembers a query after 2 s with results, and saves one with the star', (t) async {
    final db = memDb();
    await t.runAsync(
      () => db.addEntry(
        LedgerEntriesCompanion.insert(
          isIncome: false,
          date: '2026-03-01',
          amountCents: 500,
          category: 'office',
          party: const Value('Fuel stop'),
        ),
      ),
    );
    await pumpWithDb(t, opener(() => const SearchScreen()), db);
    await t.tap(find.text('open'));
    await settle(t);
    await t.enterText(find.byType(TextField), 'fuel');
    await settle(t);
    await t.pump(const Duration(seconds: 3));
    await settle(t);
    await t.tap(find.byTooltip('Save this search'));
    await settle(t);
    await t.tap(find.byTooltip('Clear'));
    await settle(t);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Recent'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'fuel'), findsNWidgets(2));
    final stored = await t.runAsync(
      () async => (await db.getSetting('recentSearches'), await db.getSetting('savedSearches')),
    );
    expect(stored, ('["fuel"]', '["fuel"]'));
    await t.tap(find.text('Clear'));
    await settle(t);
    expect(find.text('Recent'), findsNothing);
    await t.runAsync(db.close);
  });

  testWidgets('D1 Duplicate makes a new record dated today with the same details', (t) async {
    final db = memDb();
    final id = await t.runAsync(
      () => db.addEntry(
        LedgerEntriesCompanion.insert(
          isIncome: false,
          date: '2026-02-03',
          amountCents: 1234,
          category: 'office',
          party: const Value('Staples'),
          businessPct: const Value(60),
          tags: Value(normalizeTags('client-a')),
        ),
      ),
    );
    final row = (await t.runAsync(() => db.select(db.ledgerEntries).getSingle()))!;
    expect(row.id, id);
    await pumpWithDb(t, opener(() => EntryScreen(existing: row)), db, today: DateTime(2026, 11, 6));
    await t.tap(find.text('open'));
    await settle(t);
    await t.tap(find.byTooltip('Duplicate'));
    await settle(t);
    expect(find.text('New expense'), findsOneWidget);
    await t.tap(find.text('Save expense'));
    await settle(t);
    final rows = (await t.runAsync(() => db.select(db.ledgerEntries).get()))!;
    expect(rows.length, 2);
    final copy = rows.firstWhere((r) => r.id != id);
    expect(
      (copy.date, copy.amountCents, copy.party, copy.businessPct, copy.category, copy.tags),
      ('2026-11-06', 1234, 'Staples', 60, 'office', ' client-a '),
    );
    expect(find.text('open'), findsOneWidget, reason: 'duplicate replaced the edit screen; save pops back');
    // Unmount and let pending queries finish inside the fake clock, or close() waits forever (test-only).
    await t.pumpWidget(const SizedBox());
    await settle(t);
    await t.runAsync(db.close);
  });

  testWidgets('P1 pulling down at the top of a list opens search', (t) async {
    final db = memDb();
    await pumpWithDb(t, const Scaffold(body: PullToSearch(child: _LongList())), db);
    await t.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await settle(t);
    expect(find.byType(SearchScreen), findsOneWidget);
    await t.runAsync(db.close);
  });

  testWidgets('C1 adding your own category saves it and shows the line it counts on', (t) async {
    final db = memDb();
    final app = await pumpWithDb(t, opener(() => const CategoriesScreen()), db);
    await t.tap(find.text('open'));
    await settle(t);
    await t.tap(find.text('Add category'));
    await settle(t);
    await t.enterText(find.byType(TextField), '  Client   lunches ');
    await t.tap(find.text('Counts as'));
    await settle(t);
    await t.tap(find.text('Expense · Meals').last);
    await settle(t);
    await t.tap(find.text('Add'));
    await settle(t);
    expect(find.text('Client lunches'), findsOneWidget);
    expect(find.textContaining('counts as Meals · line'), findsOneWidget);
    expect(app.customCategories.single.baseId, 'meals');
    final stored = await t.runAsync(() => db.getSetting('customCategories'));
    expect(stored, contains('Client lunches'));
    await t.pumpWidget(const SizedBox());
    await settle(t);
    await t.runAsync(db.close);
  });

  testWidgets('M1 adding a business lists it, and removing it moves its records to the main business', (t) async {
    final db = memDb();
    final app = await pumpWithDb(t, opener(() => const BusinessesScreen()), db);
    app.businesses = (await t.runAsync(db.allBusinesses))!;
    await t.tap(find.text('open'));
    await settle(t);
    await t.tap(find.text('Add business'));
    await settle(t);
    await t.enterText(find.byType(TextField), '  Etsy   shop ');
    await t.pump();
    await t.tap(find.text('Add'));
    await settle(t);
    expect(find.text('Etsy shop'), findsOneWidget);
    expect(app.multiBusiness, isTrue);
    final etsy = app.businesses.last.id;
    await t.runAsync(
      () => db.addEntry(
        LedgerEntriesCompanion.insert(
          isIncome: true,
          date: '2026-03-01',
          amountCents: 500,
          category: 'services',
          businessId: Value(etsy),
        ),
      ),
    );
    await t.tap(find.byTooltip('Remove Etsy shop'));
    await settle(t);
    expect(find.textContaining('Nothing is deleted'), findsOneWidget);
    await t.tap(find.text('Remove'));
    await settle(t);
    expect(find.text('Etsy shop'), findsNothing);
    final rows = await t.runAsync(() => db.watchYear(2026).first);
    expect(rows!.single.businessId, AppDatabase.mainBusinessId, reason: 'record kept, moved to main');
    await t.pumpWidget(const SizedBox());
    await settle(t);
    await t.runAsync(db.close);
  });

  testWidgets('M2 with a business on screen, a new record saves to it (and can be switched)', (t) async {
    final db = memDb();
    final id = (await t.runAsync(() => db.addBusiness('Tutoring')))!;
    final app = await pumpWithDb(t, opener(() => const EntryScreen()), db);
    app.businesses = (await t.runAsync(db.allBusinesses))!;
    app.viewBusiness = id;
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.tap(find.text('2'));
    await t.tap(find.byType(ChoiceChip).first);
    await t.pumpAndSettle();
    expect(find.text('Business'), findsOneWidget);
    expect(find.text('Tutoring'), findsOneWidget);
    await t.tap(find.text('Save expense'));
    await settle(t);
    final rows = await t.runAsync(() => db.watchYear(2026).first);
    expect(rows!.single.businessId, id);
    await t.pumpWidget(const SizedBox());
    await settle(t);
    await t.runAsync(db.close);
  });

  testWidgets('Q1 "Again?" chip fills a frequent record in one tap and saves it', (t) async {
    final db = memDb();
    for (final d in ['2026-09-01', '2026-10-01']) {
      await t.runAsync(
        () => db.addEntry(
          LedgerEntriesCompanion.insert(
            isIncome: false,
            date: d,
            amountCents: 540,
            category: 'meals',
            party: const Value('Starbucks'),
            tags: Value(normalizeTags('client-a')),
          ),
        ),
      );
    }
    await pumpWithDb(t, opener(() => const EntryScreen()), db);
    await t.tap(find.text('open'));
    await settle(t);
    expect(find.text('Again?'), findsOneWidget);
    await t.tap(find.text('Starbucks · \$5.40'));
    await t.pumpAndSettle();
    expect(find.text('Again?'), findsNothing, reason: 'hidden once an amount is in');
    await t.tap(find.text('Save expense'));
    await settle(t);
    final rows = (await t.runAsync(() => db.watchYear(2026).first))!;
    expect(rows.length, 3);
    final n = rows.firstWhere((e) => e.date == '2026-11-01');
    expect((n.party, n.amountCents, n.category, n.tags), ('Starbucks', 540, 'meals', ' client-a '));
    await t.pumpWidget(const SizedBox());
    await settle(t);
    await t.runAsync(db.close);
  });

  testWidgets('S2 select records: change category with undo, select all, delete with undo', (t) async {
    final db = memDb();
    for (final (d, p) in [('2026-10-01', 'Alpha'), ('2026-10-02', 'Beta'), ('2026-10-03', 'Gamma')]) {
      await t.runAsync(
        () => db.addEntry(
          LedgerEntriesCompanion.insert(
            isIncome: false,
            date: d,
            amountCents: 100,
            category: 'supplies',
            party: Value(p),
          ),
        ),
      );
    }
    Future<List<String>> cats() async => [
      for (final e in (await t.runAsync(() => db.watchYear(2026).first))!) '${e.party}:${e.category}',
    ];
    await pumpWithDb(t, const Scaffold(body: RecordsTab()), db);
    await settle(t);
    await t.longPress(find.text('Alpha'));
    await settle(t);
    await t.tap(find.text('Beta'));
    await settle(t);
    expect(find.text('2 selected'), findsOneWidget);
    await t.tap(find.text('Category'));
    await settle(t);
    await t.tap(find.text('Advertising & marketing'));
    await settle(t);
    expect(find.text('2 selected'), findsNothing, reason: 'selection ends after an action');
    expect((await cats())..sort(), ['Alpha:advertising', 'Beta:advertising', 'Gamma:supplies']);
    await t.tap(find.text('Undo'));
    await settle(t);
    expect((await cats()).every((c) => c.endsWith(':supplies')), isTrue);

    await t.longPress(find.text('Gamma'));
    await settle(t);
    await t.tap(find.text('Select all 3'));
    await settle(t);
    await t.tap(find.text('Delete'));
    await settle(t);
    await t.tap(find.widgetWithText(FilledButton, 'Delete'));
    await settle(t);
    expect(await cats(), isEmpty);
    await t.tap(find.text('Undo'));
    await settle(t);
    expect((await cats()).length, 3);
    await t.pumpWidget(const SizedBox());
    await settle(t);
    await t.runAsync(db.close);
  });

  for (final (w, scale) in [(320.0, 2.0), (880.0, 1.3), (390.0, 1.0)]) {
    testWidgets('S3 selection bar fits at w$w x$scale with several businesses', (t) async {
      final db = memDb();
      await t.runAsync(() => db.addBusiness('A very long business name that goes on'));
      for (var i = 0; i < 12; i++) {
        await t.runAsync(
          () => db.addEntry(
            LedgerEntriesCompanion.insert(
              isIncome: i.isEven,
              date: '2026-10-${(i + 1).toString().padLeft(2, '0')}',
              amountCents: 100,
              category: i.isEven ? 'services' : 'supplies',
              party: Value('Payee $i'),
            ),
          ),
        );
      }
      final app = await pumpWithDb(
        t,
        MediaQuery(
          data: MediaQueryData(size: Size(w, 844), textScaler: TextScaler.linear(scale)),
          child: const Scaffold(body: RecordsTab()),
        ),
        db,
      );
      t.view.physicalSize = Size(w, 844);
      app.businesses = (await t.runAsync(db.allBusinesses))!;
      await settle(t);
      await t.longPress(find.text('Payee 11'));
      await settle(t);
      expect(find.text('Business'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.tap(find.text('Category'));
      await settle(t);
      expect(find.textContaining('Select only income or only expenses'), findsNothing);
      await t.tapAt(const Offset(10, 10));
      await settle(t);
      await t.pumpWidget(const SizedBox());
      await settle(t);
      await t.runAsync(db.close);
    });
  }

  Future<int> addInvoice(WidgetTester t, AppDatabase db, String date, String party) async => (await t.runAsync(
    () => db.addEntry(
      LedgerEntriesCompanion.insert(
        isIncome: true,
        date: date,
        amountCents: 90000,
        category: 'services',
        party: Value(party),
        paid: const Value(false),
      ),
    ),
  ))!;

  testWidgets('I1 marking an old invoice received asks when, and moves it to that day (cash basis)', (t) async {
    final db = memDb();
    await addInvoice(t, db, '2026-09-01', 'Acme');
    final e = (await t.runAsync(() => db.watchYear(2026).first))!.single;
    await pumpWithDb(t, opener(() => EntryScreen(existing: e)), db);
    await t.tap(find.text('open'));
    await settle(t);
    await t.scrollUntilVisible(find.byType(SwitchListTile), 200, scrollable: find.byType(Scrollable).first);
    await t.drag(find.byType(Scrollable).first, const Offset(0, -400));
    await settle(t);
    await t.tap(find.byType(SwitchListTile));
    await settle(t);
    expect(find.text('When did the money arrive?'), findsOneWidget);
    await t.tap(find.textContaining('Today,'));
    await settle(t);
    await t.tap(find.text('Save changes'));
    await settle(t);
    final n = (await t.runAsync(() => db.watchYear(2026).first))!.single;
    expect((n.paid, n.date), (true, '2026-11-01'));
    await t.pumpWidget(const SizedBox());
    await settle(t);
    await t.runAsync(db.close);
  });

  testWidgets('I2 selected unpaid invoices: Received, keeping each invoice date; undo', (t) async {
    final db = memDb();
    await addInvoice(t, db, '2026-09-01', 'Acme');
    await addInvoice(t, db, '2026-10-01', 'Beta Co');
    await pumpWithDb(t, const Scaffold(body: RecordsTab()), db);
    await settle(t);
    await t.longPress(find.text('Acme'));
    await settle(t);
    await t.tap(find.text('Beta Co'));
    await settle(t);
    await t.tap(find.text('Received'));
    await settle(t);
    await t.tap(find.text('On each invoice date'));
    await settle(t);
    var rows = (await t.runAsync(() => db.watchYear(2026).first))!;
    expect(rows.map((e) => (e.paid, e.date)).toSet(), {(true, '2026-09-01'), (true, '2026-10-01')});
    await t.tap(find.text('Undo'));
    await settle(t);
    rows = (await t.runAsync(() => db.watchYear(2026).first))!;
    expect(rows.every((e) => !e.paid), isTrue);
    await t.pumpWidget(const SizedBox());
    await settle(t);
    await t.runAsync(db.close);
  });

  testWidgets('T1 a trip driven again fills from its chip and saves', (t) async {
    final db = memDb();
    for (final d in ['2026-09-01', '2026-10-01']) {
      await t.runAsync(
        () => db.addTrip(
          TripsCompanion.insert(
            date: d,
            milesTenths: 124,
            purpose: const Value('Client visit'),
            route: const Value('Home to Acme'),
          ),
        ),
      );
    }
    await pumpWithDb(t, opener(() => const MileageScreen(2026)), db);
    await t.tap(find.text('open'));
    await settle(t);
    await t.tap(find.text('Add trip'));
    await settle(t);
    await t.tap(find.text('Client visit · 12.4 mi'));
    await t.pump();
    await t.tap(find.text('Save'));
    await settle(t);
    final trips = (await t.runAsync(() => db.watchTrips(2026).first))!;
    expect(trips.length, 3);
    expect(trips.first.date, '2026-11-01');
    expect((trips.first.milesTenths, trips.first.purpose, trips.first.route), (124, 'Client visit', 'Home to Acme'));
    await t.pumpWidget(const SizedBox());
    await settle(t);
    await t.runAsync(db.close);
  });

  testWidgets('M3 one business: no business row or chip bar anywhere', (t) async {
    final db = memDb();
    final app = await pumpWithDb(t, opener(() => const EntryScreen()), db);
    app.businesses = (await t.runAsync(db.allBusinesses))!;
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text('Business'), findsNothing);
    expect(app.newRecordBusiness, AppDatabase.mainBusinessId);
    await t.pumpWidget(const SizedBox());
    await settle(t);
    await t.runAsync(db.close);
  });

  testWidgets('U11 keypad stays after tapping chips, segments, slider and switch', (t) async {
    final db = memDb();
    await pumpWithDb(t, opener(() => const EntryScreen()), db);
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.tap(find.byType(ChoiceChip).first);
    await t.pumpAndSettle();
    await t.tap(find.byType(Slider));
    await t.pumpAndSettle();
    expect(find.text('5'), findsOneWidget, reason: 'non-text controls must not hide the keypad');
    await t.tap(find.text('Income'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.byType(SwitchListTile), 200, scrollable: find.byType(Scrollable).first);
    await t.tap(find.byType(SwitchListTile));
    await t.pumpAndSettle();
    expect(find.text('5'), findsOneWidget, reason: 'non-text controls must not hide the keypad');
    await t.runAsync(db.close);
  });

  testWidgets('U12 a disabled Save says what is missing', (t) async {
    final db = memDb();
    await pumpWithDb(t, opener(() => const EntryScreen()), db);
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.textContaining('Type an amount'), findsOneWidget);
    await t.tap(find.text('5'));
    await t.pump();
    final picked = find.byWidgetPredicate((w) => w is ChoiceChip && w.selected);
    if (picked.evaluate().isEmpty) expect(find.textContaining('Pick a category'), findsOneWidget);
    await t.runAsync(db.close);
  });

  testWidgets('FINDING U1: entry Save tapped twice (slow write) creates two records and pops twice', (t) async {
    final db = SlowDb();
    await pumpWithDb(t, opener(() => const EntryScreen()), db);
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.tap(find.text('5'));
    await t.tap(find.byType(ChoiceChip).first);
    await t.pump();
    final save = find.text('Save expense');
    await t.tap(save);
    await t.pump(const Duration(milliseconds: 80));
    await t.tap(save, warnIfMissed: false);
    await settle(t);
    await t.pump(const Duration(seconds: 5));
    final rows = await t.runAsync(() => db.watchYear(2026).first);
    t.takeException();
    expect(find.text('open'), findsOneWidget, reason: 'second pop must not remove the screen underneath');
    expect(rows!.length, 1, reason: 'double tap on Save must not create a duplicate');
    await t.runAsync(db.close);
  }, skip: !_confirm); // FINDING U1: EntryScreen._save has no in-flight guard: 2 records + 2 pops

  testWidgets('FINDING U2: tools sheet disposes TextEditingControllers while the sheet animates out', (t) async {
    final db = memDb();
    await pumpWithDb(t, opener(() => const PaymentLogScreen(2026)), db);
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.tap(find.text('Log payment'));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextField, 'Amount'), '450');
    await t.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(t);
    expect(t.takeException(), isNull, reason: 'TextEditingController used after being disposed (tools.dart _sheet)');
    await t.runAsync(db.close);
  }, skip: !_confirm); // FINDING U2: tools.dart disposes sheet controllers right after showModalBottomSheet returns

  testWidgets('FINDING U2b: payment sheet Save tapped twice (slow write) logs two payments', (t) async {
    final db = SlowDb();
    await pumpWithDb(t, opener(() => const PaymentLogScreen(2026)), db);
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.tap(find.text('Log payment'));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextField, 'Amount'), '450');
    final save = find.widgetWithText(FilledButton, 'Save');
    await t.tap(save);
    await t.pump(const Duration(milliseconds: 80));
    await t.tap(save, warnIfMissed: false);
    await settle(t);
    await t.pump(const Duration(seconds: 5));
    final rows = await t.runAsync(() => db.watchPayments(2026).first);
    t.takeException();
    expect(find.text('Payment log · 2026'), findsOneWidget, reason: 'second pop must not close the payment log');
    expect(rows!.length, 1, reason: 'double tap on Save must not log two payments');
    await t.runAsync(db.close);
  }, skip: !_confirm); // FINDING U2b: _sheet Save has no in-flight guard

  test('U3 undo delete keeps the receipt linked', () async {
    final db = memDb();
    final id = await db.addEntry(
      LedgerEntriesCompanion.insert(isIncome: false, date: '2026-03-01', amountCents: 500, category: 'software'),
    );
    final aid = await db.addAttachment(
      AttachmentsCompanion.insert(
        folder: 'receipt',
        year: 2026,
        entryId: Value(id),
        fileId: 'f',
        mime: 'image/jpeg',
        sizeBytes: 1,
      ),
    );
    final e = (await db.watchYear(2026).first).single;
    final linked = await db.deleteEntry(e.id);
    await db.restoreEntry(e, attachmentIds: linked);
    expect((await db.attachment(aid))!.entryId, id, reason: 'Undo should bring back the receipt link');
    await db.close();
  });

  testWidgets('FINDING U4: "Record deleted / Undo" snackbar survives auto-lock', (t) async {
    final db = memDb();
    await t.runAsync(
      () => db.addEntry(
        LedgerEntriesCompanion.insert(
          isIncome: false,
          date: '2026-10-01',
          amountCents: 500,
          category: 'software',
          party: const Value('Adobe'),
        ),
      ),
    );
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final c = DbController(dataDir: dir, testDb: db)..debugShowReady();
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          appControllerProvider.overrideWith((ref) => c),
          todayProvider.overrideWithValue(DateTime(2026, 11, 1, 9)),
          taxRulesProvider.overrideWith((ref, year) async => rules[year]!),
        ],
        child: const LedgerLockApp(),
      ),
    );
    await settle(t);
    await t.tap(find.text('Records'));
    await settle(t);
    await t.drag(find.text('Adobe'), const Offset(-500, 0));
    await settle(t);
    expect(find.text('Record deleted'), findsOneWidget);
    // Auto-lock fires.
    c.testDb = null;
    c.stage = Stage.locked;
    c.notifyListeners();
    await settle(t);
    await t.pump(const Duration(seconds: 10));
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.text('Record deleted'), findsNothing, reason: 'undo snackbar (persist: true) survives lock');
    await t.runAsync(db.close);
  }, skip: !_confirm);

  testWidgets('FINDING U5: due countdown off by one across DST (Mar 1 -> Apr 15 shows 44 days)', (t) async {
    await stress(
      t,
      const AppShell(),
      b: Brightness.light,
      width: 390,
      scale: 1,
      today: DateTime(2026, 3, 1, 9),
      entries: [_e(1, '2026-02-01', income: true, cat: 'services', cents: 500000)],
    );
    expect(find.textContaining('in 45 days'), findsWidgets, reason: 'DST spring-forward makes inDays 44');
  }, skip: !_confirm);

  testWidgets('FINDING U6: next-due pill says "in 1 days"', (t) async {
    await stress(
      t,
      const AppShell(),
      b: Brightness.light,
      width: 390,
      scale: 1,
      today: DateTime(2026, 4, 14, 9),
      entries: [_e(1, '2026-02-01', income: true, cat: 'services', cents: 500000)],
    );
    expect(find.text('in 1 days'), findsNothing);
  }, skip: !_confirm);

  test('U7 check-in "receipts" dismissal does not hide a new year\'s question with the same count', () {
    final q = checkInQuestions(
      today: DateTime(2026, 6, 20),
      entries: [for (var i = 1; i <= 3; i++) _e(i, '2026-06-1$i')],
      entriesWithReceipt: const {},
      payments: const [],
      formsLastYear: const [],
      rules: null,
      dismissed: const {'receipts:3'}, // dismissed back in 2025 for 3 different expenses
    );
    expect(q.where((x) => x.action == CheckInAction.receipts), isNotEmpty);
  });

  test('U8 check-in asks about Q4 (due Jan 15) in early January', () {
    // checkInProvider passes rules for today.year: in January that is the NEW year, whose next due is Apr 15.
    final today = DateTime(2026, 1, 8);
    final q = checkInQuestions(
      today: today,
      entries: const [],
      entriesWithReceipt: const {},
      payments: const [],
      formsLastYear: const [],
      rules: rules[today.year],
      previousRules: rules[today.year - 1],
    );
    expect(q.where((x) => x.action == CheckInAction.paymentLog), isNotEmpty, reason: 'Q4 2025 due Jan 15, 2026');
  });
  test('U9 CSV import truncation keeps payees well-formed UTF-16 (emoji)', () {
    final header = ['Date', 'Description', 'Amount'];
    final r = buildImport([
      ['01/05/2026', emojiName, '-12.00'],
    ], guessColumns(header));
    final payee = r.rows.single.payee;
    final lone = RegExp(r'[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]');
    expect(lone.hasMatch(payee), isFalse, reason: 'payee.substring(0, 80) splits a surrogate pair');
  });
}

class _LongList extends StatelessWidget {
  const _LongList();
  @override
  Widget build(BuildContext context) => ListView(
    physics: const ClampingScrollPhysics(),
    children: [for (var i = 0; i < 40; i++) ListTile(title: Text('row $i'))],
  );
}
