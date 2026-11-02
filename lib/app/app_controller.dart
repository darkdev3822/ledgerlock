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
import '../media/documents.dart';
import '../platform/document_picker.dart';
import '../security/auto_lock.dart';
import '../security/biometric_reset.dart';
import '../security/crypto.dart';
import '../security/session.dart';
import '../security/vault.dart';
import '../platform/reminders.dart';
import '../tax/checkin.dart';
import '../tax/guidance.dart';

enum Stage { locked, recoveryKey, biometricOffer, businessType, firstSteps, ready }

class AppController extends ChangeNotifier {
  final Directory dataDir;
  final Vault vault;
  final BiometricSecretStore biometrics;
  final DocumentPicker picker;

  /// Platform temp/cache dir: wiped on start and lock so no stray plaintext survives.
  final Directory? tempDir;
  late final AutoLock autoLock = AutoLock(onLock: lock);

  Session? _session;
  Stage stage = Stage.locked;

  /// Onboarding finished (business type + first steps seen). Stored in the encrypted DB.
  bool onboarded = true;

  /// Chosen business types (lib/data/business_types.dart): only reorders categories.
  Set<String> businessTypes = {};

  /// What the user picked on "You're all set" ('scan' | 'add'); AppShell takes it once.
  String? firstAction;
  String? pendingCode;
  Set<Slot> slots = {};
  bool biometricsAvailable = false;
  ThemeMode themeMode = ThemeMode.system;
  int autoLockMinutes = 1;
  int selectedYear;

  /// Percent of profit to set aside for taxes; null = the year's default.
  double? setAsidePct;

  /// Opt-ins for resource matching (SPEC §2.12). We never infer age or problems; the user says so.
  bool age60OptIn = false, irsProblemOptIn = false;

  /// Optional W-2 Social Security wages per tax year (cents), for the SE tax wage-base cap.
  Map<int, int> w2WagesCents = {};

  /// Home office square feet per tax year (simplified method), 0 = none.
  Map<int, int> homeOfficeSqft = {};

  /// Reminders (SPEC §2.6, §2.13). Stored in the encrypted DB; only generic notification text leaves it.
  bool quarterlyReminders = false;
  String checkInFrequency = 'off';
  DateTime? lastCheckIn;
  Set<String> dismissedCheckIns = {};

  AppController({
    required this.dataDir,
    required this.biometrics,
    DocumentPicker? picker,
    this.tempDir,
    Vault? vault,
    int? year,
  }) : vault = vault ?? Vault(dataDir),
       picker = picker ?? ChannelDocumentPicker(),
       selectedYear = year ?? _defaultYear();

  static int _defaultYear() {
    final y = DateTime.now().year;
    return TaxRules.supportedYears.contains(y) ? y : TaxRules.supportedYears.first;
  }

  bool get unlocked => _session != null;

  /// The open encrypted database, or null while locked.
  AppDatabase? get db => _session?.db;

  /// Receipts and vault documents, or null while locked.
  Documents? get documents {
    final s = _session;
    return s == null ? null : (_documents ??= Documents(s.db, s.files));
  }

  Documents? _documents;
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
    await wipeTemp();
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
    age60OptIn = await db.getSetting('age60OptIn') == 'true';
    irsProblemOptIn = await db.getSetting('irsProblemOptIn') == 'true';
    w2WagesCents = {};
    homeOfficeSqft = {};
    for (final y in TaxRules.supportedYears) {
      final v = int.tryParse(await db.getSetting('w2Wages:$y') ?? '');
      if (v != null) w2WagesCents[y] = v;
      final h = int.tryParse(await db.getSetting('homeOfficeSqft:$y') ?? '');
      if (h != null) homeOfficeSqft[y] = h;
    }
    quarterlyReminders = await db.getSetting('quarterlyReminders') == 'true';
    checkInFrequency = await db.getSetting('checkInFrequency') ?? 'off';
    onboarded = await db.getSetting('onboarded') == 'true';
    businessTypes = (await db.getSetting('businessTypes') ?? '').split(',').where((t) => t.isNotEmpty).toSet();
    lastCheckIn = DateTime.tryParse(await db.getSetting('lastCheckIn') ?? '');
    dismissedCheckIns = (await db.getSetting('dismissedCheckIns') ?? '').split('\n').where((k) => k.isNotEmpty).toSet();
    slots = await vault.enabledSlots();
    _session = s;
    rescheduleReminders();
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
    _documents = null;
    pendingCode = null;
    age60OptIn = irsProblemOptIn = false;
    w2WagesCents = {}; // sensitive answers: reload from the encrypted DB on unlock
    homeOfficeSqft = {};
    businessTypes = {};
    stage = Stage.locked;
    notifyListeners();
    s.lock();
    wipeTemp();
  }

  /// Deletes everything in the temp/cache dir (plugins may leave files there).
  Future<void> wipeTemp() async {
    final d = tempDir;
    if (d == null || !await d.exists()) return;
    await for (final e in d.list()) {
      try {
        await e.delete(recursive: true);
      } catch (_) {}
    }
  }

  // ---------- onboarding ----------

  Future<void> confirmRecoveryKey() async {
    await vault.setRecoveryKey(_session!.dataKey, pendingCode!);
    pendingCode = null;
    slots = await vault.enabledSlots();
    stage = biometricsAvailable && !slots.contains(Slot.biometric) ? Stage.biometricOffer : _afterSecurity;
    notifyListeners();
  }

  Stage get _afterSecurity => onboarded ? Stage.ready : Stage.businessType;

  void finishBiometricOffer() {
    stage = _afterSecurity;
    notifyListeners();
  }

  Future<void> setBusinessTypes(Set<String> types) async {
    businessTypes = {...types};
    await db?.setSetting('businessTypes', types.join(','));
    notifyListeners();
  }

  /// Onboarding step: business type chosen (or skipped).
  Future<void> finishBusinessType(Set<String> types) async {
    await setBusinessTypes(types);
    stage = Stage.firstSteps;
    notifyListeners();
  }

  /// Last onboarding step. [action]: 'scan', 'add' or null (look around).
  Future<void> finishOnboarding(String? action) async {
    onboarded = true;
    firstAction = action;
    await db?.setSetting('onboarded', 'true');
    stage = Stage.ready;
    notifyListeners();
  }

  String? takeFirstAction() {
    final a = firstAction;
    firstAction = null;
    return a;
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

  Future<void> setOptIns({bool? age60, bool? irsProblem}) async {
    age60OptIn = age60 ?? age60OptIn;
    irsProblemOptIn = irsProblem ?? irsProblemOptIn;
    notifyListeners();
    await _session?.db.setSetting('age60OptIn', '$age60OptIn');
    await _session?.db.setSetting('irsProblemOptIn', '$irsProblemOptIn');
  }

  Future<void> setW2Wages(int year, int cents) async {
    w2WagesCents = {...w2WagesCents, year: cents};
    notifyListeners();
    await _session?.db.setSetting('w2Wages:$year', '$cents');
  }

  Future<void> setHomeOfficeSqft(int year, int sqft) async {
    homeOfficeSqft = {...homeOfficeSqft, year: sqft};
    notifyListeners();
    await _session?.db.setSetting('homeOfficeSqft:$year', '$sqft');
  }

  /// Turns quarterly reminders on/off. Asks for notification permission first; returns false if refused.
  Future<bool> setQuarterlyReminders(bool on) async {
    if (on && !await requestNotificationPermission()) return false;
    quarterlyReminders = on;
    notifyListeners();
    await _session?.db.setSetting('quarterlyReminders', '$on');
    await rescheduleReminders();
    return true;
  }

  Future<bool> setCheckInFrequency(String f) async {
    if (f != 'off' && !await requestNotificationPermission()) return false;
    checkInFrequency = f;
    notifyListeners();
    await _session?.db.setSetting('checkInFrequency', f);
    await rescheduleReminders();
    return true;
  }

  /// Called when a check-in is finished: next one is [checkInFrequency] days from now.
  Future<void> finishCheckIn(DateTime now) async {
    lastCheckIn = now;
    notifyListeners();
    await _session?.db.setSetting('lastCheckIn', now.toIso8601String());
    await rescheduleReminders();
  }

  Future<void> dismissCheckIn(String key) async {
    // Keep the list bounded: keys are per period, old ones stop mattering.
    dismissedCheckIns = {...dismissedCheckIns.skip(dismissedCheckIns.length > 200 ? 100 : 0), key};
    notifyListeners();
    await _session?.db.setSetting('dismissedCheckIns', dismissedCheckIns.join('\n'));
  }

  /// Rebuilds the notification schedule from settings and the bundled rules (future items only).
  Future<void> rescheduleReminders() async {
    final days = checkInFrequencies[checkInFrequency] ?? 0;
    if (!quarterlyReminders && days == 0) {
      await scheduleReminders(const []);
      return;
    }
    final rules = [for (final y in TaxRules.supportedYears) await TaxRules.load(y)];
    await scheduleReminders(
      planReminders(
        now: DateTime.now(),
        rules: rules,
        quarterly: quarterlyReminders,
        checkInDays: days,
        lastCheckIn: lastCheckIn,
      ),
    );
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
  final w2 = ref.watch(appControllerProvider.select((a) => a.w2WagesCents[year] ?? 0));
  final trips = ref.watch(tripsProvider(year)).value ?? const [];
  final sqft = ref.watch(appControllerProvider.select((a) => a.homeOfficeSqft[year] ?? 0));
  if (rules == null) return LedgerSummary.empty;
  return summarize(
    entries.map((e) => e.data),
    rules,
    setAsidePct: pct,
    w2WagesCents: w2,
    mileageCents: mileageDeductionCents(trips.map((t) => (t.date, t.milesTenths)), rules),
    homeOfficeCents: homeOfficeCents(sqft, rules) ?? 0,
  );
});

/// Bundled free-help list (SPEC §2.12). Overridable in tests.
final resourcesProvider = FutureProvider<List<Resource>>((ref) => Resource.load());

/// Whether the year's vault holds an IRS letter.
final hasIrsLetterProvider = StreamProvider.family<bool, int>((ref, year) {
  final db = ref.watch(appControllerProvider.select((a) => a.db));
  if (db == null) return Stream.value(false);
  return db.watchAttachments(year, folder: 'letter').map((l) => l.isNotEmpty);
});

final paymentsProvider = StreamProvider.family<List<TaxPayment>, int>((ref, year) {
  final db = ref.watch(appControllerProvider.select((a) => a.db));
  return db == null ? Stream.value(const []) : db.watchPayments(year);
});

final tripsProvider = StreamProvider.family<List<Trip>, int>((ref, year) {
  final db = ref.watch(appControllerProvider.select((a) => a.db));
  return db == null ? Stream.value(const []) : db.watchTrips(year);
});

final categoryRulesProvider = StreamProvider<List<CategoryRule>>((ref) {
  final db = ref.watch(appControllerProvider.select((a) => a.db));
  return db == null ? Stream.value(const []) : db.watchRules();
});

final forms1099Provider = StreamProvider.family<List<Form1099>, int>((ref, year) {
  final db = ref.watch(appControllerProvider.select((a) => a.db));
  return db == null ? Stream.value(const []) : db.watchForms1099(year);
});
