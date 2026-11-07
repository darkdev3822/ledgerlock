// Junk in stored settings (an old version's format, a restored backup, a half-written value) must never stop the
// vault from opening or a screen from drawing. Every setting key the app reads gets each junk value; then a real
// unlock (password -> SQLCipher -> settings parse) and every tab + Settings are drawn.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerlock/app/app_controller.dart';
import 'package:ledgerlock/data/tax_rules.dart';
import 'package:ledgerlock/security/biometric_reset.dart';
import 'package:ledgerlock/security/crypto.dart';
import 'package:ledgerlock/security/vault.dart';
import 'package:ledgerlock/ui/design/theme.dart';
import 'package:ledgerlock/ui/settings_screen.dart';
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

KdfParams fastKdf() => KdfParams.generate(memoryKiB: 256, iterations: 1);

const keys = [
  'age60OptIn',
  'allowScreenshots',
  'autoLockMinutes',
  'budgets',
  'businessTypes',
  'checkInFrequency',
  'customCategories',
  'dismissedCheckIns',
  'filedYears',
  'irsProblemOptIn',
  'lastBackup',
  'lastCheckIn',
  'onboarded',
  'quarterlyReminders',
  'recentSearches',
  'savedSearches',
  'selectedYear',
  'setAsidePct',
  'themeMode',
  'viewBusiness',
  'homeOfficeSqft:2026',
  'incomeGoal:2026',
  'w2Wages:2026',
  'homeOfficeSqft:2025',
  'incomeGoal:2025',
  'w2Wages:2025',
  'attention:no_receipt:2026', 'lessonsDone', 'lessonsDismissed',
];

const junk = <String>[
  '',
  'null',
  '-1',
  'NaN',
  '1e309',
  '99999999999999999999',
  '{',
  '[1,2',
  '{"a":"b"}',
  '[{"x":1},null,"y"]',
  '{"supplies":-5,"meals":"x","": 1e308}',
  '[{"id":"","name":null,"base":"nope"}]',
  'true',
  '\u0000￿',
  '9999-99-99T99:99',
];

void main() {
  late Map<int, TaxRules> rules;
  setUpAll(() async => rules = {for (final y in TaxRules.supportedYears) y: await TaxRules.load(y)});

  for (final (i, j) in junk.indexed) {
    testWidgets('settings junk #$i ${j.length > 20 ? '${j.substring(0, 20)}…' : j}', (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final dir = Directory.systemTemp.createTempSync('ll_junk');
      addTearDown(() => dir.deleteSync(recursive: true));
      final app = AppController(
        dataDir: dir,
        biometrics: _Bio(),
        vault: Vault(dir, kdfFactory: fastKdf, recoveryKdfFactory: fastKdf, questionsKdfFactory: fastKdf),
      );
      await t.runAsync(() async {
        await app.openWithPassword('pw-junk-test-1');
        for (final k in keys) {
          await app.db!.setSetting(k, j);
        }
        await app.lock();
        await app.openWithPassword('pw-junk-test-1'); // parses every setting
      });
      expect(app.unlocked, isTrue);
      app.debugShowReady();
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            appControllerProvider.overrideWith((ref) => app),
            todayProvider.overrideWithValue(DateTime(2026, 11, 1, 9)),
            taxRulesProvider.overrideWith((ref, year) async => rules[year]!),
          ],
          child: MaterialApp(theme: buildTheme(Brightness.light), home: const AppShell()),
        ),
      );
      Future<void> settle() async {
        for (var k = 0; k < 4; k++) {
          await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
          await t.pump(const Duration(milliseconds: 200));
        }
      }

      await settle();
      expect(t.takeException(), isNull, reason: 'Home');
      for (final tab in ['Records', 'Vault', 'Taxes', 'Home']) {
        await t.tap(find.text(tab).last);
        await settle();
        expect(t.takeException(), isNull, reason: tab);
      }
      await t.tap(find.byTooltip('Settings'));
      await settle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      for (var k = 0; k < 6; k++) {
        await t.drag(find.byType(Scrollable).last, const Offset(0, -500));
        await settle();
        expect(t.takeException(), isNull, reason: 'Settings scrolled $k');
      }
      await t.runAsync(app.lock);
      await t.pumpWidget(const SizedBox());
    });
  }
}
