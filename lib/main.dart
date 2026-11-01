import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'security/auto_lock.dart';
import 'security/biometric_reset.dart';
import 'security/crypto.dart';
import 'security/session.dart';
import 'security/vault.dart';
import 'ui/lock_screens.dart';
import 'ui/recovery_screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getApplicationSupportDirectory();
  runApp(LedgerLockApp(dataDir: dir, biometrics: PlatformBiometricSecretStore()));
}

enum _Stage { recoveryKey, biometricOffer, ready }

class LedgerLockApp extends StatefulWidget {
  final Directory dataDir;
  final BiometricSecretStore biometrics;
  final Vault? vault;
  const LedgerLockApp({super.key, required this.dataDir, required this.biometrics, this.vault});

  @override
  State<LedgerLockApp> createState() => _LedgerLockAppState();
}

class _LedgerLockAppState extends State<LedgerLockApp> {
  late final Vault _vault = widget.vault ?? Vault(widget.dataDir);
  late final AutoLock _autoLock = AutoLock(onLock: _lock);
  final _nav = GlobalKey<NavigatorState>();
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  Session? _session;
  _Stage _stage = _Stage.ready;
  String? _pendingCode;
  Set<Slot> _slots = {};
  bool _bioAvailable = false;

  @override
  void initState() {
    super.initState();
    _autoLock.attach();
    widget.biometrics.isAvailable().then(
      (v) => mounted ? setState(() => _bioAvailable = v) : null,
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _autoLock.detach();
    _session?.lock();
    super.dispose();
  }

  Future<void> _openWithPassword(String password) async =>
      _afterUnlock(await Session.open(widget.dataDir, password, vault: _vault));

  Future<void> _openWithDataKey(Uint8List dataKey) async =>
      _afterUnlock(await Session.fromDataKey(widget.dataDir, dataKey, _vault));

  Future<void> _afterUnlock(Session s) async {
    final mins = int.tryParse(await s.db.getSetting('autoLockMinutes') ?? '');
    if (mins != null) _autoLock.timeout = Duration(minutes: mins);
    final slots = await _vault.enabledSlots();
    _nav.currentState?.popUntil((r) => r.isFirst);
    setState(() {
      _session = s;
      _slots = slots;
      // Every vault must have a confirmed recovery key; resume setup if it was interrupted.
      if (!slots.contains(Slot.recovery)) {
        _pendingCode = RecoveryKey.generate();
        _stage = _Stage.recoveryKey;
      } else {
        _stage = _Stage.ready;
      }
    });
  }

  Future<void> _refreshSlots() async {
    final slots = await _vault.enabledSlots();
    if (mounted) setState(() => _slots = slots);
  }

  void _lock() {
    final s = _session;
    if (s == null) return;
    _nav.currentState?.popUntil((r) => r.isFirst);
    setState(() {
      _session = null;
      _pendingCode = null;
    });
    s.lock();
  }

  Future<void> _confirmRecoveryKey() async {
    await _vault.setRecoveryKey(_session!.dataKey, _pendingCode!);
    await _refreshSlots();
    setState(() {
      _pendingCode = null;
      _stage = _bioAvailable && !_slots.contains(Slot.biometric) ? _Stage.biometricOffer : _Stage.ready;
    });
  }

  Future<void> _enableBiometric() async {
    final secret = BiometricSecretStore.newSecret();
    try {
      await widget.biometrics.save(secret);
      await _vault.setBiometricSecret(_session!.dataKey, secret);
    } catch (_) {
      _messenger.currentState?.showSnackBar(
        const SnackBar(content: Text('Fingerprint reset wasn\'t turned on. You can try again later.')),
      );
    } finally {
      LedgerCrypto.zero(secret);
    }
    await _refreshSlots();
    setState(() => _stage = _Stage.ready);
  }

  Future<void> _toggleBiometric() async {
    if (_slots.contains(Slot.biometric)) {
      await _vault.removeSlot(Slot.biometric);
      try {
        await widget.biometrics.delete();
      } catch (_) {}
      await _refreshSlots();
    } else {
      await _enableBiometric();
    }
  }

  void _newRecoveryKey() {
    final code = RecoveryKey.generate();
    _nav.currentState!.push(
      MaterialPageRoute(
        builder: (_) => RecoveryKeyScreen(
          code: code,
          isRegeneration: true,
          onConfirmed: () async {
            await _vault.setRecoveryKey(_session!.dataKey, code);
            await _refreshSlots();
            _nav.currentState?.pop();
          },
        ),
      ),
    );
  }

  void _securityQuestions() {
    _nav.currentState!.push(
      MaterialPageRoute(
        builder: (_) => SecurityQuestionsSetupScreen(
          onSave: (q, a) async {
            await _vault.setSecurityQuestions(_session!.dataKey, q, a);
            await _refreshSlots();
          },
        ),
      ),
    );
  }

  void _forgot() {
    _nav.currentState!.push(
      MaterialPageRoute(
        builder: (_) =>
            ForgotPasswordScreen(vault: _vault, biometrics: widget.biometrics, onRecovered: _openWithDataKey),
      ),
    );
  }

  Widget _home() {
    if (_session == null) {
      return _vault.exists
          ? UnlockScreen(onSubmit: _openWithPassword, onForgot: _forgot)
          : SetupScreen(onSubmit: _openWithPassword);
    }
    return switch (_stage) {
      _Stage.recoveryKey => RecoveryKeyScreen(code: _pendingCode!, onConfirmed: _confirmRecoveryKey),
      _Stage.biometricOffer => BiometricOfferScreen(
        onEnable: _enableBiometric,
        onSkip: () => setState(() => _stage = _Stage.ready),
      ),
      _Stage.ready => UnlockedPlaceholder(
        onLock: _lock,
        recoveryPanel: RecoveryPanel(
          slots: _slots,
          biometricsAvailable: _bioAvailable,
          onRegenerateKey: _newRecoveryKey,
          onToggleBiometric: _toggleBiometric,
          onQuestions: _securityQuestions,
        ),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LedgerLock',
      navigatorKey: _nav,
      scaffoldMessengerKey: _messenger,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF1F6F5C), useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF1F6F5C),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: _home(),
      builder: (context, child) => ValueListenableBuilder<bool>(
        valueListenable: _autoLock.coverVisible,
        builder: (context, cover, _) => Stack(
          children: [
            child!,
            if (cover)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: ColoredBox(
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
                    child: const Center(child: Icon(Icons.lock_outline, size: 56)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
