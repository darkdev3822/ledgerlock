// Vault header: one random data key, wrapped separately by each unlock method
// ("slots": password, recovery key, security questions, biometric secret).
// Any slot unlocks the data key; changing one re-wraps only that slot (SPEC §1).
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'crypto.dart';

class WrongPassword implements Exception {
  const WrongPassword();
  @override
  String toString() => 'WrongPassword';
}

/// Wrong recovery key, wrong answers or a stale biometric secret.
class RecoveryFailed implements Exception {
  const RecoveryFailed();
  @override
  String toString() => 'RecoveryFailed';
}

enum Slot { password, recovery, questions, biometric }

/// Offline recovery key: 30 Crockford base32 chars (150 bits), shown as 6 groups of 5.
class RecoveryKey {
  static const alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  static const length = 30;

  static String generate() {
    final r = Random.secure();
    return format(List.generate(length, (_) => alphabet[r.nextInt(32)]).join());
  }

  /// Uppercase, drop separators, fix look-alikes (O→0, I/L→1). Doesn't validate.
  static String normalize(String input) => input
      .toUpperCase()
      .replaceAll(RegExp(r'[\s\-_.]'), '')
      .replaceAll('O', '0')
      .replaceAll(RegExp('[IL]'), '1')
      .replaceAll('U', 'V');

  static bool isWellFormed(String input) {
    final n = normalize(input);
    return n.length == length && n.split('').every(alphabet.contains);
  }

  static String format(String raw) {
    final n = normalize(raw);
    return [for (var i = 0; i < n.length; i += 5) n.substring(i, min(i + 5, n.length))].join('-');
  }
}

/// Answers are compared case/space/punctuation-insensitively.
String normalizeAnswer(String a) =>
    a.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ').trim();

class Vault {
  static const _passwordAad = 'ledgerlock/v1/data-key'; // v1-compatible
  final File headerFile;

  /// KDF factories are injectable so tests can use cheap Argon2 parameters.
  final KdfParams Function() kdfFactory;
  final KdfParams Function() recoveryKdfFactory;
  final KdfParams Function() questionsKdfFactory;

  Vault(
    Directory dir, {
    KdfParams Function()? kdfFactory,
    KdfParams Function()? recoveryKdfFactory,
    KdfParams Function()? questionsKdfFactory,
  }) : headerFile = File('${dir.path}/vault.json'),
       kdfFactory = kdfFactory ?? KdfParams.generate,
       // The recovery key is 150 random bits, so a light KDF is plenty.
       recoveryKdfFactory = recoveryKdfFactory ?? (() => KdfParams.generate(memoryKiB: 8192, iterations: 1)),
       // Answers have low entropy: make each guess expensive.
       questionsKdfFactory =
           questionsKdfFactory ?? (() => KdfParams.generate(memoryKiB: 65536, iterations: 3));

  bool get exists => headerFile.existsSync();

  // ---------- header I/O ----------

  Future<Map<String, dynamic>> _readSlots() async {
    final j = jsonDecode(await headerFile.readAsString()) as Map<String, dynamic>;
    switch (j['v']) {
      case 1: // migrate: v1 had a single password slot
        return {
          Slot.password.name: {'kdf': j['kdf'], 'wrapped': j['wrappedKey']},
        };
      case 2:
        return Map<String, dynamic>.from(j['slots'] as Map);
      default:
        throw const FormatException('unsupported vault version');
    }
  }

  Future<void> _writeSlots(Map<String, dynamic> slots) async {
    final tmp = File('${headerFile.path}.tmp');
    // Atomic replace: a crash never leaves a half-written header.
    await tmp.writeAsString(jsonEncode({'v': 2, 'slots': slots}), flush: true);
    await tmp.rename(headerFile.path);
  }

  Future<Map<String, dynamic>> _wrap(
    Uint8List dataKey,
    Uint8List kek,
    Slot slot,
    KdfParams? kdf, [
    Map<String, dynamic> extra = const {},
  ]) async {
    final wrapped = await LedgerCrypto.encrypt(dataKey, kek, aad: _aad(slot));
    return {if (kdf != null) 'kdf': kdf.toJson(), 'wrapped': base64.encode(wrapped), ...extra};
  }

  List<int> _aad(Slot s) => utf8.encode(s == Slot.password ? _passwordAad : '$_passwordAad/${s.name}');

  Future<Uint8List> _unwrapWithSecret(Slot slot, List<int> secret, Exception onFail) async {
    final slots = await _readSlots();
    final s = slots[slot.name] as Map<String, dynamic>?;
    if (s == null) throw onFail;
    final kek = s['kdf'] == null
        ? Uint8List.fromList(secret)
        : await LedgerCrypto.deriveKeyBytes(secret, KdfParams.fromJson(s['kdf'] as Map<String, dynamic>));
    try {
      return await LedgerCrypto.decrypt(base64.decode(s['wrapped'] as String), kek, aad: _aad(slot));
    } on DecryptionFailed {
      throw onFail;
    } finally {
      LedgerCrypto.zero(kek);
    }
  }

  Future<void> _setSlot(
    Slot slot,
    Uint8List dataKey,
    List<int> secret,
    KdfParams? kdf, [
    Map<String, dynamic> extra = const {},
  ]) async {
    final slots = exists ? await _readSlots() : <String, dynamic>{};
    final kek = kdf == null ? Uint8List.fromList(secret) : await LedgerCrypto.deriveKeyBytes(secret, kdf);
    try {
      slots[slot.name] = await _wrap(dataKey, kek, slot, kdf, extra);
    } finally {
      LedgerCrypto.zero(kek);
    }
    await _writeSlots(slots);
  }

  // ---------- status ----------

  Future<Set<Slot>> enabledSlots() async =>
      exists ? (await _readSlots()).keys.map(Slot.values.byName).toSet() : <Slot>{};

  Future<List<String>> securityQuestions() async {
    final q = (await _readSlots())[Slot.questions.name] as Map<String, dynamic>?;
    return q == null ? const [] : List<String>.from(q['questions'] as List);
  }

  // ---------- setup ----------

  /// First launch: random data key wrapped by [password]. Returns the data key.
  Future<Uint8List> create(String password) async {
    if (exists) throw StateError('vault already exists');
    final dataKey = LedgerCrypto.randomBytes(LedgerCrypto.keyLength);
    await _setSlot(Slot.password, dataKey, utf8.encode(password), kdfFactory());
    return dataKey;
  }

  /// New master password (from an unlocked session or after recovery).
  Future<void> setPassword(Uint8List dataKey, String password) =>
      _setSlot(Slot.password, dataKey, utf8.encode(password), kdfFactory());

  /// Stores [code] (from [RecoveryKey.generate]) as the recovery key, replacing any old one.
  /// Call only after the user confirmed they wrote it down.
  Future<void> setRecoveryKey(Uint8List dataKey, String code) async {
    if (!RecoveryKey.isWellFormed(code)) throw ArgumentError('malformed recovery key');
    await _setSlot(Slot.recovery, dataKey, utf8.encode(RecoveryKey.normalize(code)), recoveryKdfFactory());
  }

  /// Exactly 3 questions; all answers are needed to recover.
  Future<void> setSecurityQuestions(Uint8List dataKey, List<String> questions, List<String> answers) async {
    if (questions.length != 3 || answers.length != 3) throw ArgumentError('need 3 questions and answers');
    if (answers.any((a) => normalizeAnswer(a).length < 2)) throw ArgumentError('answer too short');
    await _setSlot(Slot.questions, dataKey, _answersSecret(answers), questionsKdfFactory(), {
      'questions': questions,
    });
  }

  /// [secret] is a random 32-byte key kept in the biometric-gated platform keystore.
  Future<void> setBiometricSecret(Uint8List dataKey, Uint8List secret) =>
      _setSlot(Slot.biometric, dataKey, secret, null);

  Future<void> removeSlot(Slot slot) async {
    if (slot == Slot.password) throw ArgumentError('the password slot is required');
    final slots = await _readSlots()
      ..remove(slot.name);
    await _writeSlots(slots);
  }

  List<int> _answersSecret(List<String> answers) => utf8.encode(answers.map(normalizeAnswer).join('\u0000'));

  // ---------- unlock / recover ----------

  Future<Uint8List> unlock(String password) =>
      _unwrapWithSecret(Slot.password, utf8.encode(password), const WrongPassword());

  Future<Uint8List> recoverWithKey(String code) {
    if (!RecoveryKey.isWellFormed(code)) throw const RecoveryFailed();
    return _unwrapWithSecret(Slot.recovery, utf8.encode(RecoveryKey.normalize(code)), const RecoveryFailed());
  }

  Future<Uint8List> recoverWithAnswers(List<String> answers) =>
      _unwrapWithSecret(Slot.questions, _answersSecret(answers), const RecoveryFailed());

  Future<Uint8List> recoverWithBiometricSecret(Uint8List secret) =>
      _unwrapWithSecret(Slot.biometric, secret, const RecoveryFailed());

  Future<void> changePassword(String oldPassword, String newPassword) async {
    final dataKey = await unlock(oldPassword);
    try {
      await setPassword(dataKey, newPassword);
    } finally {
      LedgerCrypto.zero(dataKey);
    }
  }
}
