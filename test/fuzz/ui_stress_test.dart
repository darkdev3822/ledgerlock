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
import 'package:ledgerlock/ui/onboarding_screens.dart';
import 'package:ledgerlock/ui/recovery_screens.dart';
import 'package:ledgerlock/ui/settings_screen.dart';
import 'package:ledgerlock/ui/shell/app_shell.dart';
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
      Trip(id: 1, date: '$y-08-04', milesTenths: 999999999, purpose: longName, route: arabicName),
      Trip(id: 2, date: '$y-05-12', milesTenths: 0, purpose: emojiName, route: ''),
    ]),
  ),
  forms1099Provider.overrideWith(
    (ref, y) => Stream.value([
      Form1099(id: 1, year: y, kind: '1099-K', payer: emojiName, amountCents: huge),
      Form1099(id: 2, year: y, kind: '1099-NEC', payer: longName, amountCents: 0),
      Form1099(id: 3, year: y, kind: '1099-MISC', payer: arabicName, amountCents: -1),
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
  }) async {
    t.view.physicalSize = Size(width, 844);
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
  const configs = [(390.0, 1.0), (390.0, 1.3), (320.0, 1.0), (320.0, 1.3), (390.0, 2.0), (320.0, 2.0)];

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
      for (final (w, s) in configs) {
        for (final data in [true, false]) {
          final finding = layoutFinding(name, w, s);
          final id =
              'layout $name ${b.name} w${w.round()} x$s ${data ? 'hostile' : 'empty'}${finding == null ? '' : ' $finding'}';
          testWidgets(id, skip: finding != null && !_confirm, (t) async {
            final err = await stress(
              t,
              widget,
              b: b,
              width: w,
              scale: s,
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
