import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app_controller.dart';
import 'security/biometric_reset.dart';
import 'ui/design/theme.dart';
import 'ui/lock_screens.dart';
import 'ui/onboarding_screens.dart';
import 'ui/recovery_screens.dart';
import 'ui/shell/app_shell.dart';

/// Licences for bundled non-Dart components, shown with the package licences in Settings > Open-source licences.
void _registerLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (pkgs, file) in const [
      (['Manrope font'], 'OFL-Manrope.txt'),
      (['Fraunces font'], 'OFL-Fraunces.txt'),
      (['Tesseract OCR', 'Tesseract4Android', 'tessdata_fast (eng)'], 'tesseract-apache-2.0.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks(pkgs, await rootBundle.loadString('assets/licenses/$file'));
    }
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final Directory dir = await getApplicationSupportDirectory();
  final app = AppController(
    dataDir: dir,
    biometrics: PlatformBiometricSecretStore(),
    tempDir: await getTemporaryDirectory(),
  );
  await app.init();
  _registerLicenses();
  runApp(ProviderScope(overrides: [appControllerProvider.overrideWith((ref) => app)], child: const LedgerLockApp()));
}

class LedgerLockApp extends ConsumerStatefulWidget {
  const LedgerLockApp({super.key});
  @override
  ConsumerState<LedgerLockApp> createState() => _LedgerLockAppState();
}

class _LedgerLockAppState extends ConsumerState<LedgerLockApp> {
  final _nav = GlobalKey<NavigatorState>();
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  Stage? _lastStage;
  int _lastRecoveryEpoch = 0; // a lock during password recovery wiped the key: back to the lock screen
  bool _welcomed = false; // first run: privacy promise before choosing a password

  void _forgot(AppController app) => _nav.currentState!.push(
    MaterialPageRoute(
      builder: (_) => ForgotPasswordScreen(
        vault: app.vault,
        biometrics: app.biometrics,
        onRecovered: app.openWithDataKey,
        onHold: app.holdRecoveryKey,
        onRelease: app.releaseRecoveryKey,
      ),
    ),
  );

  Widget _home(AppController app) => switch (app.stage) {
    Stage.locked =>
      app.vaultExists
          ? UnlockScreen(onSubmit: app.openWithPassword, onForgot: () => _forgot(app))
          : _welcomed
          ? SetupScreen(onSubmit: app.openWithPassword)
          : WelcomeScreen(onStart: () => setState(() => _welcomed = true)),
    Stage.recoveryKey => RecoveryKeyScreen(code: app.pendingCode!, onConfirmed: app.confirmRecoveryKey),
    Stage.biometricOffer => BiometricOfferScreen(
      onEnable: () async {
        await app.enableBiometric();
        app.finishBiometricOffer();
      },
      onSkip: app.finishBiometricOffer,
    ),
    Stage.businessType => BusinessTypeScreen(initial: app.businessTypes, onDone: app.finishBusinessType),
    Stage.firstSteps => FirstStepsScreen(onDone: app.finishOnboarding),
    Stage.ready => const AppShell(),
  };

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appControllerProvider);
    // Any stage change (lock, unlock, onboarding step) clears pushed screens.
    if ((_lastStage != null && _lastStage != app.stage) || _lastRecoveryEpoch != app.recoveryEpoch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _nav.currentState?.popUntil((r) => r.isFirst);
        _messenger.currentState?.clearSnackBars(); // no Undo bar may outlive a lock (UI review U4)
      });
    }
    _lastStage = app.stage;
    _lastRecoveryEpoch = app.recoveryEpoch;
    return MaterialApp(
      title: 'LedgerLock',
      navigatorKey: _nav,
      scaffoldMessengerKey: _messenger,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: app.themeMode,
      home: _home(app),
      builder: (context, child) => ValueListenableBuilder<bool>(
        valueListenable: app.autoLock.coverVisible,
        builder: (context, cover, _) => Stack(
          children: [
            child!,
            if (cover)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: ColoredBox(
                    color: context.ll.background.withValues(alpha: 0.6),
                    child: Center(child: Icon(Icons.lock_rounded, size: 56, color: context.ll.accent)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
