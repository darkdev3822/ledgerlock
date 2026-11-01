// Golden screenshots of the design system (M2). Regenerate with:
//   flutter test test/goldens_test.dart --update-goldens
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerlock/app/app_controller.dart';
import 'package:ledgerlock/data/database.dart';
import 'package:ledgerlock/data/tax_rules.dart';
import 'package:ledgerlock/security/biometric_reset.dart';
import 'package:ledgerlock/security/vault.dart';
import 'package:ledgerlock/ui/design/theme.dart';
import 'package:ledgerlock/ui/ledger/entry_screen.dart';
import 'package:ledgerlock/ui/lock_screens.dart';
import 'package:ledgerlock/ui/recovery_screens.dart';
import 'package:ledgerlock/ui/settings_screen.dart';
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
  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
}

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
        platform: r['platform'] as String? ?? '',
        notes: '',
        createdAt: DateTime(2026),
      ),
  ]..sort((a, b) => b.date.compareTo(a.date));
}

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
  }) async {
    t.view.physicalSize = const Size(390, 844); // logical phone size at 1x: small PNGs
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final controller = app ?? AppController(dataDir: dir, biometrics: FakeBiometrics(), year: 2026)
      ..biometricsAvailable = true;
    if (app == null) controller.debugShowReady(slots: {Slot.password, Slot.recovery, Slot.biometric});
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          appControllerProvider.overrideWith((ref) => controller),
          todayProvider.overrideWithValue(DateTime(2026, 11, 1)),
          taxRulesProvider.overrideWith((ref, year) async => rules[year]!),
          entriesProvider.overrideWith(
            (ref, year) =>
                Stream.value(data ? fixtureEntries().where((e) => e.date.startsWith('$year')).toList() : []),
          ),
        ],
        child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildTheme(b), home: home),
      ),
    );
    await t.pumpAndSettle();
    // Stream overrides deliver on a real event-loop turn.
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await t.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/${name}_${b.name}.png'));
  }

  for (final b in Brightness.values) {
    testWidgets('home ${b.name}', (t) => shoot(t, 'home', const AppShell(), b, data: true));
    testWidgets('entry_expense ${b.name}', (t) => shoot(t, 'entry_expense', const EntryScreen(), b));
    testWidgets(
      'entry_income ${b.name}',
      (t) => shoot(t, 'entry_income', const EntryScreen(startIncome: true), b),
    );
    testWidgets('home_empty ${b.name}', (t) => shoot(t, 'home_empty', const AppShell(), b));
    testWidgets(
      'records_filled ${b.name}',
      (t) => shoot(t, 'records_filled', const AppShell(initialTab: 1), b, data: true),
    );
    testWidgets(
      'taxes_filled ${b.name}',
      (t) => shoot(t, 'taxes_filled', const AppShell(initialTab: 3), b, data: true),
    );
    testWidgets('records ${b.name}', (t) => shoot(t, 'records', const AppShell(initialTab: 1), b));
    testWidgets('vault ${b.name}', (t) => shoot(t, 'vault', const AppShell(initialTab: 2), b));
    testWidgets('taxes ${b.name}', (t) => shoot(t, 'taxes', const AppShell(initialTab: 3), b));
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
