// App-wide state: lock/unlock, onboarding stage, recovery methods and preferences.
// UI listens to this; platform specifics stay behind Vault / BiometricSecretStore.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../data/database.dart';
import '../data/ledger.dart';
import '../data/tax_rules.dart';
import '../media/documents.dart';
import '../backup/backup.dart';
import '../platform/backup_files.dart';
import '../platform/document_picker.dart';
import '../platform/secure_window.dart';
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

  /// Tax years the user marked as filed (SPEC §2.1 "2025 · Filed"). Read-mostly: edits warn, never block.
  Set<int> filedYears = {};

  /// Monthly budget per expense category (cents) and a yearly income goal (cents). SPEC §3. Encrypted DB only.
  Map<String, int> budgets = {};
  Map<int, int> incomeGoals = {};

  /// The user's own categories (SPEC §3), merged into every year's rules by taxRulesProvider.
  List<CustomCategory> customCategories = const [];

  /// Businesses (SPEC §3: each with its own Schedule C). Always holds the main business (id 1) once unlocked.
  List<Business> businesses = const [];

  /// Which business the screens show: a business id, or 0 = all of them together.
  int viewBusiness = 0;
  bool get multiBusiness => businesses.length > 1;

  /// The business filter in effect (0 = no filter). With one business there is nothing to filter.
  int get effectiveView => multiBusiness && businesses.any((b) => b.id == viewBusiness) ? viewBusiness : 0;

  /// Where a new record goes: the business on screen, or the main one while showing all.
  int get newRecordBusiness => effectiveView == 0 ? AppDatabase.mainBusinessId : effectiveView;
  String businessName(int id) =>
      businesses.where((b) => b.id == id).map((b) => b.name).firstOrNull ?? (id == 0 ? 'All businesses' : 'Business');

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

  /// When the last encrypted backup was saved (null = never). Drives the Home banner and recovery health.
  DateTime? lastBackup;

  /// Screenshots allowed while unlocked (default off: blocked, T22).
  bool allowScreenshots = false;
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
    // An app kill mid-restore leaves the old vault aside: put it back, or finish the new one (M9 review B3).
    try {
      await recoverInterruptedRestore(dataDir);
    } catch (_) {}
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

  Future<void> openWithDataKey(Uint8List dataKey) async {
    if (identical(dataKey, _recoveringKey)) _recoveringKey = null; // the session owns it now
    await _afterUnlock(await Session.fromDataKey(dataDir, dataKey, vault));
  }

  // ---------- password recovery (SECURITY.md T19) ----------
  /// Data key recovered by fingerprint / recovery key / answers, held while the user picks a new password. Owned here
  /// (not by a screen) so auto-lock can wipe it: before, the key sat in a route that no lock ever cleared.
  Uint8List? _recoveringKey;

  /// Bumped when a lock wipes a pending recovery, so the UI pops back to the lock screen.
  int recoveryEpoch = 0;

  void holdRecoveryKey(Uint8List dk) {
    if (!identical(dk, _recoveringKey)) LedgerCrypto.zero(_recoveringKey);
    _recoveringKey = dk;
  }

  /// The user backed out of choosing a new password: wipe the key.
  void releaseRecoveryKey() {
    LedgerCrypto.zero(_recoveringKey);
    _recoveringKey = null;
  }

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
      final g = int.tryParse(await db.getSetting('incomeGoal:$y') ?? '');
      if (g != null && g > 0) incomeGoals[y] = g;
    }
    quarterlyReminders = await db.getSetting('quarterlyReminders') == 'true';
    allowScreenshots = await db.getSetting('allowScreenshots') == 'true';
    lastBackup = DateTime.tryParse(await db.getSetting('lastBackup') ?? '');
    if (allowScreenshots) setSecureWindow(false);
    checkInFrequency = await db.getSetting('checkInFrequency') ?? 'off';
    onboarded = await db.getSetting('onboarded') == 'true';
    budgets = _decodeBudgets(await db.getSetting('budgets'));
    customCategories = CustomCategory.decodeList(await db.getSetting('customCategories'));
    businesses = await db.allBusinesses();
    viewBusiness = int.tryParse(await db.getSetting('viewBusiness') ?? '') ?? 0;
    filedYears = (await db.getSetting('filedYears') ?? '').split(',').map(int.tryParse).whereType<int>().toSet();
    businessTypes = (await db.getSetting('businessTypes') ?? '').split(',').where((t) => t.isNotEmpty).toSet();
    lastCheckIn = DateTime.tryParse(await db.getSetting('lastCheckIn') ?? '');
    dismissedCheckIns = (await db.getSetting('dismissedCheckIns') ?? '').split('\n').where((k) => k.isNotEmpty).toSet();
    slots = await vault.enabledSlots();
    // Repeating records due since the last unlock (catch-up capped per rule). Never blocks unlocking.
    try {
      recurringAdded = await db.runRecurring(DateTime.now());
    } catch (_) {
      recurringAdded = 0;
    }
    _session = s;
    rescheduleReminders();
    // Every vault must have a confirmed recovery key; resume setup if it was interrupted.
    if (!slots.contains(Slot.recovery)) {
      pendingCode = RecoveryKey.generate();
      stage = Stage.recoveryKey;
    } else {
      // An auto-lock or app kill mid-onboarding used to skip the rest of it (UI review A).
      stage = onboarded ? Stage.ready : Stage.businessType;
    }
    notifyListeners();
  }

  /// Locks the vault. Async so callers that replace files (restore) can wait for the database to close.
  Future<void> lock() async {
    final s = _session;
    if (_restoring) _restoreAborted = true; // auto-lock during a restore: don't reopen unlocked afterwards (B5)
    if (s == null) {
      if (_recoveringKey != null) {
        releaseRecoveryKey();
        recoveryEpoch++;
        notifyListeners();
      }
      return;
    }
    _session = null;
    _documents = null;
    pendingCode = null;
    age60OptIn = irsProblemOptIn = false;
    w2WagesCents = {}; // sensitive answers: reload from the encrypted DB on unlock
    homeOfficeSqft = {};
    businessTypes = {};
    filedYears = {};
    budgets = {};
    incomeGoals = {};
    customCategories = const [];
    businesses = const [];
    viewBusiness = 0;
    if (allowScreenshots) setSecureWindow(true); // locked: always secure
    allowScreenshots = false;
    stage = Stage.locked;
    notifyListeners();
    await s.lock();
    await wipeTemp();
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

  // ---------- encrypted backups (M9) ----------

  Directory get _backupOut => Directory('${dataDir.path}/.backup-out');
  File get _restoreIn => File('${dataDir.path}/.restore-in.llbackup');
  Directory get restoreStaging => Directory('${dataDir.path}/.restore-staging');

  /// Builds an encrypted backup and lets the user choose where to save it. Returns false if cancelled.
  Future<bool> backupNow() async {
    final s = _session;
    if (s == null) return false;
    final now = DateTime.now();
    final out = File('${_backupOut.path}/b.llbackup');
    if (_backupOut.existsSync()) _backupOut.deleteSync(recursive: true);
    _backupOut.createSync(recursive: true);
    try {
      await createBackup(dataDir: dataDir, session: s, dataKey: s.dataKey, out: out, now: now);
      final ok = await saveBackupWithPicker(out, 'LedgerLock-backup-${isoDay(now)}.llbackup');
      if (ok && _session == s) {
        lastBackup = now;
        await s.db.setSetting('lastBackup', now.toIso8601String());
        rescheduleReminders(); // move the monthly backup reminder
        notifyListeners();
      }
      return ok;
    } finally {
      if (_backupOut.existsSync()) _backupOut.deleteSync(recursive: true);
    }
  }

  /// Step 1 of restore: the user picks a backup file. Null if cancelled. Throws [BackupInvalid] for non-backups.
  Future<BackupFile?> pickBackup() async {
    if (_restoreIn.existsSync()) _restoreIn.deleteSync();
    if (!await pickBackupTo(_restoreIn)) return null;
    return BackupFile.open(_restoreIn);
  }

  /// Last step: [dk] came from the backup's own slots (password / recovery key / answers). Verifies every byte,
  /// then replaces the live vault (locking it first if open) and opens the restored one.
  bool _restoring = false, _restoreAborted = false;
  bool get restoring => _restoring;

  Future<void> finishRestore(BackupFile b, Uint8List dk) async {
    _restoring = true;
    _restoreAborted = false;
    DateTime made;
    var swapping = false;
    try {
      final staging = restoreStaging;
      for (final f in staging.existsSync() ? staging.listSync() : const <FileSystemEntity>[]) {
        if (!f.path.endsWith('vault.json')) f.deleteSync(recursive: true); // keep the staged header only
      }
      made = await b.extractVerified(staging, dk);
      if (_restoreAborted) throw const BackupInvalid('locked during restore');
      // Through the real lock path (stage, sensitive fields, snackbars), waiting for the DB to close (B5).
      if (_session != null) await lock();
      _restoreAborted = false; // our own lock above, not an auto-lock
      swapping = true;
      await installStaged(staging, dataDir);
    } catch (_) {
      LedgerCrypto.zero(dk);
      // Once the swap has started, staging is not ours to delete: startup recovery resolves it (B3).
      if (!swapping && restoreStaging.existsSync()) restoreStaging.deleteSync(recursive: true);
      if (swapping) await recoverInterruptedRestore(dataDir);
      _restoring = false;
      rethrow;
    } finally {
      if (_restoreIn.existsSync()) _restoreIn.deleteSync();
    }
    _restoring = false;
    await openWithDataKey(dk);
    // The snapshot inside a backup predates its own "last backup" stamp: count the backup we just restored from.
    final last = lastBackup;
    if (last == null || made.isAfter(last)) {
      lastBackup = made;
      await db?.setSetting('lastBackup', made.toIso8601String());
      notifyListeners();
    }
  }

  void cancelRestore() {
    if (_restoring) return; // never pull staging out from under a running restore (M9 review B2)
    if (restoreStaging.existsSync()) restoreStaging.deleteSync(recursive: true);
    if (_restoreIn.existsSync()) _restoreIn.deleteSync();
  }

  Future<void> setAllowScreenshots(bool v) async {
    allowScreenshots = v;
    await db?.setSetting('allowScreenshots', '$v');
    await setSecureWindow(!v);
    notifyListeners();
  }

  static Map<String, int> _decodeBudgets(String? json) {
    try {
      final m = jsonDecode(json ?? '{}') as Map<String, dynamic>;
      return {
        for (final e in m.entries)
          if (e.value is int && (e.value as int) > 0) e.key: e.value as int,
      };
    } catch (_) {
      return {};
    }
  }

  /// [cents] <= 0 removes the budget.
  Future<void> setBudget(String category, int cents) async {
    budgets = {...budgets}..remove(category);
    if (cents > 0) budgets[category] = cents;
    await db?.setSetting('budgets', jsonEncode(budgets));
    notifyListeners();
  }

  Future<void> setIncomeGoal(int year, int cents) async {
    incomeGoals = {...incomeGoals}..remove(year);
    if (cents > 0) incomeGoals[year] = cents;
    await db?.setSetting('incomeGoal:$year', cents > 0 ? '$cents' : '');
    notifyListeners();
  }

  /// Adds a category counted as [baseId]. Returns false for an empty or duplicate name.
  Future<bool> addCustomCategory(String name, String baseId) async {
    final n = safeTake(name.trim().replaceAll(RegExp(r'\s+'), ' '), 40);
    if (n.isEmpty || customCategories.any((c) => c.name.toLowerCase() == n.toLowerCase())) return false;
    final id = 'custom_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
    customCategories = [...customCategories, CustomCategory(id, n, baseId)];
    await db?.setSetting('customCategories', CustomCategory.encodeList(customCategories));
    notifyListeners();
    return true;
  }

  /// Deletes a custom category. Its records, repeats and rules move to the built-in category it counted as, so
  /// no record is left without a category; its budget is dropped.
  Future<void> deleteCustomCategory(CustomCategory c) async {
    await db?.reassignCategory(c.id, c.baseId);
    customCategories = customCategories.where((x) => x.id != c.id).toList();
    await db?.setSetting('customCategories', CustomCategory.encodeList(customCategories));
    if (budgets.containsKey(c.id)) await setBudget(c.id, 0);
    notifyListeners();
  }

  /// Adds a business. Returns its id, or null for an empty or duplicate name.
  Future<int?> addBusiness(String name) async {
    final n = safeTake(name.trim().replaceAll(RegExp(r'\s+'), ' '), 40);
    final d = db;
    if (d == null || n.isEmpty || businesses.any((b) => b.name.toLowerCase() == n.toLowerCase())) return null;
    final id = await d.addBusiness(n);
    businesses = await d.allBusinesses();
    notifyListeners();
    return id;
  }

  /// Renames a business. Returns false for an empty or duplicate name.
  Future<bool> renameBusiness(int id, String name) async {
    final n = safeTake(name.trim().replaceAll(RegExp(r'\s+'), ' '), 40);
    final d = db;
    if (d == null || n.isEmpty || businesses.any((b) => b.id != id && b.name.toLowerCase() == n.toLowerCase())) {
      return false;
    }
    await d.renameBusiness(id, n);
    businesses = await d.allBusinesses();
    notifyListeners();
    return true;
  }

  /// Removes a business; its records, trips, 1099s and repeats move to the main business (never deleted).
  Future<void> deleteBusiness(int id) async {
    final d = db;
    if (d == null || id == AppDatabase.mainBusinessId) return;
    await d.deleteBusiness(id);
    businesses = await d.allBusinesses();
    if (viewBusiness == id) await setViewBusiness(0);
    notifyListeners();
  }

  Future<void> setViewBusiness(int id) async {
    viewBusiness = id;
    await db?.setSetting('viewBusiness', '$id');
    notifyListeners();
  }

  Future<void> setFiled(int year, bool filed) async {
    filedYears = {...filedYears}..remove(year);
    if (filed) filedYears.add(year);
    await db?.setSetting('filedYears', (filedYears.toList()..sort()).join(','));
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

  /// Records added by repeating records at the last unlock; shown once by the shell.
  int recurringAdded = 0;
  int takeRecurringAdded() {
    final n = recurringAdded;
    recurringAdded = 0;
    return n;
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
        backupReminder: true,
        lastBackup: lastBackup,
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

/// "Today", overridable so goldens are stable. Recomputed on every unlock/lock (db changes), so an app left
/// open overnight does not keep yesterday's date.
final todayProvider = Provider<DateTime>((ref) {
  ref.watch(appControllerProvider.select((a) => a.db));
  return DateTime.now();
});

final taxRulesProvider = FutureProvider.family<TaxRules, int>((ref, year) async {
  final custom = ref.watch(appControllerProvider.select((a) => a.customCategories));
  return (await TaxRules.load(year)).withCustom(custom);
});

/// Every business's entries for a tax year (empty while locked). Self-employment tax and set-aside use these.
final allEntriesProvider = StreamProvider.family<List<LedgerEntry>, int>((ref, year) {
  final db = ref.watch(appControllerProvider.select((a) => a.db));
  return db == null ? Stream.value(const []) : db.watchYear(year);
});

/// The business filter screens use (0 = all).
final viewBusinessProvider = Provider<int>((ref) => ref.watch(appControllerProvider.select((a) => a.effectiveView)));

/// Live ledger entries for a tax year, for the business on screen.
final entriesProvider = StreamProvider.family<List<LedgerEntry>, int>((ref, year) {
  final db = ref.watch(appControllerProvider.select((a) => a.db));
  final v = ref.watch(viewBusinessProvider);
  if (db == null) return Stream.value(const []);
  return v == 0 ? db.watchYear(year) : db.watchYear(year).map((l) => [...l.where((e) => e.businessId == v)]);
});

/// Dashboard numbers for a tax year. With several businesses and one on screen, the Schedule C lines, profit and
/// chart are that business's, while self-employment tax and set-aside are figured on all of them together (one
/// Schedule SE covers every Schedule C). The home office counts toward the main business.
final summaryProvider = Provider.family<LedgerSummary, int>((ref, year) {
  final rules = ref.watch(taxRulesProvider(year)).value;
  final all = ref.watch(allEntriesProvider(year)).value ?? const [];
  final allTrips = ref.watch(allTripsProvider(year)).value ?? const [];
  final v = ref.watch(viewBusinessProvider);
  final pct = ref.watch(appControllerProvider.select((a) => a.setAsidePct));
  final w2 = ref.watch(appControllerProvider.select((a) => a.w2WagesCents[year] ?? 0));
  final sqft = ref.watch(appControllerProvider.select((a) => a.homeOfficeSqft[year] ?? 0));
  if (rules == null) return LedgerSummary.empty;
  return businessSummary(
    rules,
    all,
    allTrips,
    view: v,
    setAsidePct: pct,
    w2WagesCents: w2,
    homeOfficeCents: homeOfficeCents(sqft, rules) ?? 0,
  );
});

/// Every business together (Schedule SE view): what self-employment tax is figured on.
final combinedSummaryProvider = Provider.family<LedgerSummary, int>((ref, year) {
  final rules = ref.watch(taxRulesProvider(year)).value;
  if (rules == null) return LedgerSummary.empty;
  return businessSummary(
    rules,
    ref.watch(allEntriesProvider(year)).value ?? const [],
    ref.watch(allTripsProvider(year)).value ?? const [],
    setAsidePct: ref.watch(appControllerProvider.select((a) => a.setAsidePct)),
    w2WagesCents: ref.watch(appControllerProvider.select((a) => a.w2WagesCents[year] ?? 0)),
    homeOfficeCents:
        homeOfficeCents(ref.watch(appControllerProvider.select((a) => a.homeOfficeSqft[year] ?? 0)), rules) ?? 0,
  );
});

/// [summaryProvider]'s maths, separate so it can be tested. [view] 0 = every business.
LedgerSummary businessSummary(
  TaxRules rules,
  List<LedgerEntry> entries,
  List<Trip> trips, {
  int view = 0,
  double? setAsidePct,
  int w2WagesCents = 0,
  int homeOfficeCents = 0,
}) {
  LedgerSummary of(int v) => summarize(
    entries.where((e) => v == 0 || e.businessId == v).map((e) => e.data),
    rules,
    setAsidePct: setAsidePct,
    w2WagesCents: w2WagesCents,
    mileageCents: mileageDeductionCents(
      trips.where((t) => v == 0 || t.businessId == v).map((t) => (t.date, t.milesTenths)),
      rules,
    ),
    homeOfficeCents: v == 0 || v == AppDatabase.mainBusinessId ? homeOfficeCents : 0,
  );
  final combined = of(0);
  if (view == 0) return combined;
  final one = of(view);
  return LedgerSummary(
    lines: one.lines,
    grossCents: one.grossCents,
    expensesCents: one.expensesCents,
    netCents: one.netCents,
    seTaxCents: combined.seTaxCents,
    setAsideCents: combined.setAsideCents,
    setAsidePct: combined.setAsidePct,
    monthly: one.monthly,
  );
}

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

final allTripsProvider = StreamProvider.family<List<Trip>, int>((ref, year) {
  final db = ref.watch(appControllerProvider.select((a) => a.db));
  return db == null ? Stream.value(const []) : db.watchTrips(year);
});

final tripsProvider = StreamProvider.family<List<Trip>, int>((ref, year) {
  final db = ref.watch(appControllerProvider.select((a) => a.db));
  final v = ref.watch(viewBusinessProvider);
  if (db == null) return Stream.value(const []);
  return v == 0 ? db.watchTrips(year) : db.watchTrips(year).map((l) => [...l.where((t) => t.businessId == v)]);
});

final recurringProvider = StreamProvider<List<Recurring>>((ref) {
  final db = ref.watch(appControllerProvider.select((a) => a.db));
  final v = ref.watch(viewBusinessProvider);
  if (db == null) return Stream.value(const []);
  return v == 0 ? db.watchRecurring() : db.watchRecurring().map((l) => [...l.where((r) => r.businessId == v)]);
});

final categoryRulesProvider = StreamProvider<List<CategoryRule>>((ref) {
  final db = ref.watch(appControllerProvider.select((a) => a.db));
  return db == null ? Stream.value(const []) : db.watchRules();
});

final forms1099Provider = StreamProvider.family<List<Form1099>, int>((ref, year) {
  final db = ref.watch(appControllerProvider.select((a) => a.db));
  final v = ref.watch(viewBusinessProvider);
  if (db == null) return Stream.value(const []);
  return v == 0 ? db.watchForms1099(year) : db.watchForms1099(year).map((l) => [...l.where((f) => f.businessId == v)]);
});
