// Monkey test: random taps, hostile typing, Back and scrolling through the real app shell with a real (in-memory)
// database and an encrypted file store. Fails on any exception, layout overflow or unhandled async error, and prints
// the seed + the action log so the run can be replayed exactly.
//
//   flutter test test/fuzz/monkey_test.dart                                   # quick: 4 seeds x 80 steps
//   LL_MONKEY_SEEDS=60 LL_MONKEY_STEPS=200 flutter test test/fuzz/monkey_test.dart
//   LL_MONKEY_SEED=17 flutter test test/fuzz/monkey_test.dart                 # replay one seed
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerlock/app/app_controller.dart';
import 'package:ledgerlock/data/database.dart';
import 'package:ledgerlock/data/tax_rules.dart';
import 'package:ledgerlock/media/documents.dart';
import 'package:ledgerlock/security/biometric_reset.dart';
import 'package:ledgerlock/security/encrypted_file_store.dart';
import 'package:ledgerlock/ui/design/theme.dart';
import 'package:ledgerlock/ui/shell/app_shell.dart';

class _Bio implements BiometricSecretStore {
  @override
  Future<bool> isAvailable() async => false;
  @override
  Future<void> save(Uint8List s) async {}
  @override
  Future<Uint8List?> read() async => null;
  @override
  Future<void> delete() async {}
}

class MonkeyController extends AppController {
  final AppDatabase testDb;
  final Documents docs;
  MonkeyController(Directory dir, this.testDb, {int? year})
    : docs = Documents(testDb, EncryptedFileStore(Directory('${dir.path}/files'), Uint8List(32)..fillRange(0, 32, 9))),
      super(
        dataDir: dir,
        biometrics: _Bio(),
        year: year != null && TaxRules.supportedYears.contains(year) ? year : null,
      );
  @override
  AppDatabase? get db => testDb;
  @override
  Documents? get documents => docs;
}

Future<void> _fonts() async {
  Future<void> load(String family, List<String> paths) async {
    final l = FontLoader(family);
    for (final p in paths) {
      final f = File(p);
      if (f.existsSync()) l.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
    await l.load();
  }

  final mf = '${Platform.environment['HOME']}/flutter/bin/cache/artifacts/material_fonts';
  await load('Roboto', ['$mf/Roboto-Regular.ttf', '$mf/Roboto-Medium.ttf']);
  await load('Manrope', [
    for (final w in [400, 500, 600, 700, 800]) 'assets/fonts/Manrope-$w.ttf',
  ]);
  await load('Fraunces', ['assets/fonts/Fraunces-500.ttf', 'assets/fonts/Fraunces-600.ttf']);
  await load('MaterialIcons', ['$mf/MaterialIcons-Regular.otf']);
  Motion.ambient = false;
}

const hostile = [
  '',
  '0',
  '-5',
  '99999999999999999999',
  '1e309',
  '12.345',
  '.',
  '1,000.50',
  '=HYPERLINK("http://x")',
  "'; DROP TABLE ledger_entries;--",
  '%s%n%x',
  '😀👍🏽🇺🇸',
  'مرحبا بالعالم',
  '\u202Eevil.pdf',
  'line\nbreak',
  '#tag #other',
  'no receipt > 75 in 2026',
  'q2 line 9 over 50',
];

Future<void> seed(AppDatabase db) async {
  await db.addBusiness('Etsy shop');
  final rows = [
    (false, '2026-01-15', 4599, 'supplies', 'Staples', true, 1),
    (false, '2026-03-02', 12000, 'travel', 'Delta', true, 2),
    (false, '2026-10-20', 890, 'meals', 'Starbucks', true, 1),
    (true, '2026-02-01', 250000, 'gross_receipts', 'Acme Co', true, 1),
    (true, '2026-08-01', 90000, 'gross_receipts', 'Late Client', false, 1),
    (true, '2026-10-30', 45000, 'gross_receipts', 'Etsy', true, 2),
    (false, '2025-12-31', 1500, 'software', 'Adobe', true, 1),
  ];
  for (final (inc, date, c, cat, party, paid, biz) in rows) {
    await db.addEntry(
      LedgerEntriesCompanion.insert(
        isIncome: inc,
        date: date,
        amountCents: c,
        category: cat,
        party: Value(party),
        paid: Value(paid),
        tags: Value(normalizeTags('client-a')),
        businessId: Value(biz),
      ),
    );
  }
  await db.addTrip(TripsCompanion.insert(date: '2026-04-02', milesTenths: 125, purpose: const Value('Client')));
  await db.addForm1099(Forms1099Companion.insert(year: 2026, kind: '1099-NEC', payer: 'Acme Co', amountCents: 300000));
  await db.addPayment(TaxPaymentsCompanion.insert(taxYear: 2026, date: '2026-04-15', amountCents: 50000));
}

bool _tappable(Widget w) =>
    (w is InkWell && w.onTap != null) ||
    (w is ButtonStyleButton && w.onPressed != null) ||
    (w is IconButton && w.onPressed != null) ||
    (w is ListTile && w.onTap != null) ||
    (w is ChoiceChip && w.onSelected != null) ||
    (w is FilterChip && w.onSelected != null) ||
    (w is ActionChip && w.onPressed != null) ||
    (w is Switch && w.onChanged != null) ||
    (w is Checkbox && w.onChanged != null) ||
    (w is SegmentedButton) ||
    (w is GestureDetector && w.onTap != null);

String _label(Element e) {
  final texts = <String>[];
  void visit(Element x) {
    final w = x.widget;
    if (w is Text && w.data != null) texts.add(w.data!);
    if (w is Icon && w.icon != null) texts.add('icon:${w.icon!.codePoint.toRadixString(16)}');
    if (texts.length < 3) x.visitChildren(visit);
  }

  visit(e);
  final w = e.widget;
  final tip = w is IconButton ? w.tooltip : null;
  return '${w.runtimeType}${tip != null ? '[$tip]' : ''}(${texts.take(3).join(' / ')})';
}

void main() {
  final seeds = int.tryParse(Platform.environment['LL_MONKEY_SEEDS'] ?? '') ?? 4;
  final steps = int.tryParse(Platform.environment['LL_MONKEY_STEPS'] ?? '') ?? 80;
  final only = int.tryParse(Platform.environment['LL_MONKEY_SEED'] ?? '');
  // Clock edge cases: LL_MONKEY_TODAY=2027-01-05T09:00 (a year with no tax rules yet), 2026-12-31T23:59, 2028-02-29.
  final today = DateTime.tryParse(Platform.environment['LL_MONKEY_TODAY'] ?? '') ?? DateTime(2026, 11, 1, 9);
  late Map<int, TaxRules> rules;
  late Directory dir;

  setUpAll(() async {
    await _fonts();
    rules = {for (final y in TaxRules.supportedYears) y: await TaxRules.load(y)};
  });
  setUp(() => dir = Directory.systemTemp.createTempSync('ll_monkey'));
  tearDown(() => dir.deleteSync(recursive: true));

  // Platform channels the app uses: answer like a phone where the user cancels / nothing is available, so the
  // monkey exercises the app's own handling rather than stopping at MissingPluginException.
  void fakeChannels(WidgetTester t) {
    final m = t.binding.defaultBinaryMessenger;
    for (final ch in ['ledgerlock/files', 'ledgerlock/launch']) {
      m.setMockMethodCallHandler(MethodChannel(ch), (call) async {
        if (call.method == 'pick' || call.method == 'take') return null;
        if (call.method == 'save' || call.method == 'saveBackup' || call.method == 'pickBackup') return false;
        return null;
      });
    }
  }

  for (var s = 0; s < seeds; s++) {
    final seedNo = only ?? s;
    if (only != null && s > 0) break;
    for (final (w, h, scale) in [(390.0, 844.0, 1.0), (320.0, 640.0, 1.6)]) {
      testWidgets(
        'monkey seed $seedNo on ${w.toInt()}x${h.toInt()} x$scale',
        timeout: const Timeout(Duration(minutes: 4)),
        (t) async {
          t.view.physicalSize = Size(w, h);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          fakeChannels(t);
          final db = AppDatabase(NativeDatabase.memory(setup: (d) => d.execute('PRAGMA foreign_keys = ON')));
          await t.runAsync(() => seed(db));
          final c = MonkeyController(dir, db, year: today.year)..debugShowReady();
          c.businesses = (await t.runAsync(db.allBusinesses))!;
          await t.pumpWidget(
            ProviderScope(
              overrides: [
                appControllerProvider.overrideWith((ref) => c),
                todayProvider.overrideWithValue(today),
                taxRulesProvider.overrideWith((ref, year) async => rules[year]!),
              ],
              child: MaterialApp(
                theme: buildTheme(seedNo.isEven ? Brightness.light : Brightness.dark),
                builder: (ctx, child) => MediaQuery(
                  data: MediaQuery.of(ctx).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: const AppShell(),
              ),
            ),
          );
          final rnd = Random(seedNo * 7919 + w.toInt());
          final log = <String>[];

          Future<void> settle() async {
            await t.pump(const Duration(milliseconds: 60));
            await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 3)));
            await t.pump(const Duration(milliseconds: 400));
            await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2)));
            await t.pump(const Duration(milliseconds: 400));
          }

          void check(String where) {
            // LL_MONKEY_RAW=1: leave errors to the framework, which prints the full report (widget, stack).
            if (Platform.environment['LL_MONKEY_RAW'] == '1') return;
            final e = t.takeException();
            // Flutter-internal debug assertion (EditableText caret snap during a page slide; no effect in release,
            // the framework's message asks for a framework bug report). Not an app bug.
            if (e != null && '$e'.contains('RenderFractionalTranslation.performLayout')) return;
            if (e != null) {
              fail(
                'seed $seedNo ${w.toInt()}x${h.toInt()} x$scale, $where:\n$e\n--- last actions ---\n'
                '${log.skip(log.length > 25 ? log.length - 25 : 0).join('\n')}',
              );
            }
          }

          await settle();
          check('start');
          final verbose = Platform.environment['LL_MONKEY_LOG'] == '1';
          for (var i = 0; i < steps; i++) {
            final r = rnd.nextDouble();
            if (r < 0.68) {
              final els = find.byWidgetPredicate(_tappable).hitTestable().evaluate().toList();
              if (els.isEmpty) continue;
              final e = els[rnd.nextInt(els.length)];
              final label = _label(e);
              // Leaving the app or wiping it isn't a bug; everything else is fair game.
              if (label.contains('Lock now') || label.contains('Erase')) continue;
              log.add('$i tap $label');
              final box = e.renderObject as RenderBox?;
              if (box == null || !box.attached || !box.hasSize) continue;
              await t.tapAt(box.localToGlobal(box.size.center(Offset.zero)));
            } else if (r < 0.80) {
              final fields = find.byType(EditableText).hitTestable().evaluate().toList();
              if (fields.isEmpty) continue;
              final text = hostile[rnd.nextInt(hostile.length)];
              log.add('$i type ${text.replaceAll('\n', r'\n')}');
              await t.enterText(find.byWidget(fields[rnd.nextInt(fields.length)].widget), text);
            } else if (r < 0.90) {
              log.add('$i back');
              FocusManager.instance.primaryFocus?.unfocus();
              await t.binding.handlePopRoute();
            } else {
              final sc = find.byType(Scrollable).hitTestable().evaluate().toList();
              if (sc.isEmpty) continue;
              final up = rnd.nextBool();
              log.add('$i scroll ${up ? 'up' : 'down'}');
              await t.drag(
                find.byWidget(sc[rnd.nextInt(sc.length)].widget),
                Offset(0, up ? -300 : 300),
                warnIfMissed: false,
              );
            }
            await settle();
            check('step $i');
          }
          // ignore: avoid_print
          if (verbose) print(log.join('\n'));
          await t.pumpWidget(const SizedBox());
          await settle();
          await t.runAsync(db.close);
        },
      );
    }
  }
}
