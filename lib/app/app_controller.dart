// App-wide state: lock/unlock, onboarding stage, recovery methods and preferences.
// UI listens to this; platform specifics stay behind Vault / BiometricSecretStore.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../data/database.dart';
import '../data/ledger.dart';
import '../data/tax_rules.dart';
import '../security/auto_lock.dart';
import '../security/biometric_reset.dart';
import '../security/crypto.dart';
import '../security/session.dart';
import '../security/vault.dart';

enum Stage { locked, recoveryKey, biometricOffer, ready }

class AppController extends ChangeNotifier {
  final Directory dataDir;
  final Vault vault;
  final BiometricSecretStore biometrics;
  late final AutoLock autoLock = AutoLock(onLock: lock);

  Session? _session;
  Stage stage = Stage.locked;
  String? pendingCode;
  Set<Slot> slots = {};
  bool biometricsAvailable = false;
  ThemeMode themeMode = ThemeMode.system;
  int autoLockMinutes = 1;
  int selectedYear;

  /// Percent of profit to set aside for taxes; null = the year's default.
  double? setAsidePct;

  AppController({required this.dataDir, required this.biometrics, Vault? vault, int? year})
    : vault = vault ?? Vault(dataDir),
      selectedYear = year ?? _defaultYear();

  static int _defaultYear() {
    final y = DateTime.now().year;
    return TaxRules.supportedYears.contains(y) ? y : TaxRules.supportedYears.first;
  }

  bool get unlocked => _session != null;

  /// The open encrypted database, or null while locked.
  AppDatabase? get db => _session?.db;
  bool get vaultExists => vault.exists;

  /// For golden/widget tests: show the unlocked shell without a real session.
  @visibleForTesting
  void debugShowReady({Set<Slot> slots = const {Slot.password, Slot.recovery}}) {
    this.slots = slots;
    stage = Stage.ready;
    notifyListeners();
  }

  Future<void> init() async {
    autoLock.attach();
    try {
      biometricsAvailable = await biometrics.isAvailable();
    } catch (_) {
      biometricsAvailable = false;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    autoLock.detach();
    _session?.lock();
    super.dispose();
  }

  // ---------- unlock ----------

  Future<void> openWithPassword(String password) async =>
      _afterUnlock(await Session.open(dataDir, password, vault: vault));

  Future<void> openWithDataKey(Uint8List dataKey) async =>
      _afterUnlock(await Session.fromDataKey(dataDir, dataKey, vault));

  Future<void> _afterUnlock(Session s) async {
    final db = s.db;
    autoLockMinutes = int.tryParse(await db.getSetting('autoLockMinutes') ?? '') ?? 1;
    autoLock.timeout = Duration(minutes: autoLockMinutes);
    themeMode = ThemeMode.values.asNameMap()[await db.getSetting('themeMode')] ?? ThemeMode.system;
    final y = int.tryParse(await db.getSetting('selectedYear') ?? '');
    if (y != null && TaxRules.supportedYears.contains(y)) selectedYear = y;
    setAsidePct = double.tryParse(await db.getSetting('setAsidePct') ?? '');
    slots = await vault.enabledSlots();
    _session = s;
    // Every vault must have a confirmed recovery key; resume setup if it was interrupted.
    if (!slots.contains(Slot.recovery)) {
      pendingCode = RecoveryKey.generate();
      stage = Stage.recoveryKey;
    } else {
      stage = Stage.ready;
    }
    notifyListeners();
  }

  void lock() {
    final s = _session;
    if (s == null) return;
    _session = null;
    pendingCode = null;
    stage = Stage.locked;
    notifyListeners();
    s.lock();
  }

  // ---------- onboarding ----------

  Future<void> confirmRecoveryKey() async {
    await vault.setRecoveryKey(_session!.dataKey, pendingCode!);
    pendingCode = null;
    slots = await vault.enabledSlots();
    stage = biometricsAvailable && !slots.contains(Slot.biometric) ? Stage.biometricOffer : Stage.ready;
    notifyListeners();
  }

  void finishBiometricOffer() {
    stage = Stage.ready;
    notifyListeners();
  }

  // ---------- recovery methods ----------

  /// Returns false if the user cancelled or the keystore refused.
  Future<bool> enableBiometric() async {
    final secret = BiometricSecretStore.newSecret();
    try {
      await biometrics.save(secret);
      await vault.setBiometricSecret(_session!.dataKey, secret);
      return true;
    } catch (_) {
      return false;
    } finally {
      LedgerCrypto.zero(secret);
      slots = await vault.enabledSlots();
      notifyListeners();
    }
  }

  Future<void> disableBiometric() async {
    await vault.removeSlot(Slot.biometric);
    try {
      await biometrics.delete();
    } catch (_) {}
    slots = await vault.enabledSlots();
    notifyListeners();
  }

  Future<void> replaceRecoveryKey(String code) async {
    await vault.setRecoveryKey(_session!.dataKey, code);
    slots = await vault.enabledSlots();
    notifyListeners();
  }

  Future<void> setSecurityQuestions(List<String> q, List<String> a) async {
    await vault.setSecurityQuestions(_session!.dataKey, q, a);
    slots = await vault.enabledSlots();
    notifyListeners();
  }

  Future<void> removeSecurityQuestions() async {
    await vault.removeSlot(Slot.questions);
    slots = await vault.enabledSlots();
    notifyListeners();
  }

  /// Throws [WrongPassword] if [current] is wrong.
  Future<void> changePassword(String current, String next) async {
    final check = await vault.unlock(current);
    LedgerCrypto.zero(check);
    await vault.setPassword(_session!.dataKey, next);
  }

  // ---------- preferences ----------

  Future<void> setAutoLockMinutes(int m) async {
    autoLockMinutes = m;
    autoLock.timeout = Duration(minutes: m);
    notifyListeners();
    await _session?.db.setSetting('autoLockMinutes', '$m');
  }

  Future<void> setThemeMode(ThemeMode m) async {
    themeMode = m;
    notifyListeners();
    await _session?.db.setSetting('themeMode', m.name);
  }

  Future<void> setSetAsidePct(double pct) async {
    setAsidePct = pct;
    notifyListeners();
    await _session?.db.setSetting('setAsidePct', '$pct');
  }

  Future<void> setYear(int y) async {
    selectedYear = y;
    notifyListeners();
    await _session?.db.setSetting('selectedYear', '$y');
  }
}

/// Overridden in main() and in tests.
final appControllerProvider = ChangeNotifierProvider<AppController>((ref) => throw UnimplementedError());

/// "Today", overridable so goldens are stable.
final todayProvider = Provider<DateTime>((ref) => DateTime.now());

final taxRulesProvider = FutureProvider.family<TaxRules, int>((ref, year) => TaxRules.load(year));

/// Live ledger entries for a tax year (empty while locked).
final entriesProvider = StreamProvider.family<List<LedgerEntry>, int>((ref, year) {
  final db = ref.watch(appControllerProvider.select((a) => a.db));
  return db == null ? Stream.value(const []) : db.watchYear(year);
});

/// Dashboard numbers for a tax year.
final summaryProvider = Provider.family<LedgerSummary, int>((ref, year) {
  final rules = ref.watch(taxRulesProvider(year)).value;
  final entries = ref.watch(entriesProvider(year)).value ?? const [];
  final pct = ref.watch(appControllerProvider.select((a) => a.setAsidePct));
  if (rules == null) return LedgerSummary.empty;
  return summarize(entries.map((e) => e.data), rules, setAsidePct: pct);
});
