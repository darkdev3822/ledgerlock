// Biometric reset: a random 32-byte secret lives in the platform keystore
// (Android Keystore / iOS Keychain), readable only after a fingerprint/face
// check. The secret wraps the data key in the vault's biometric slot.
// Android Keystore invalidates the key if new biometrics are enrolled.
import 'dart:convert';
import 'dart:typed_data';

import 'package:biometric_storage/biometric_storage.dart';

import 'crypto.dart';

/// Platform-neutral interface so the vault logic doesn't depend on a plugin.
abstract class BiometricSecretStore {
  Future<bool> isAvailable();
  Future<void> save(Uint8List secret);

  /// Null if the user cancelled; throws if the key was invalidated.
  Future<Uint8List?> read();
  Future<void> delete();

  static Uint8List newSecret() => LedgerCrypto.randomBytes(LedgerCrypto.keyLength);
}

class PlatformBiometricSecretStore implements BiometricSecretStore {
  static const _name = 'ledgerlock_recovery_v1';
  static const _prompt = PromptInfo(
    androidPromptInfo: AndroidPromptInfo(
      title: 'Confirm it\'s you',
      subtitle: 'Use your fingerprint or face to reset your LedgerLock password',
      negativeButton: 'Cancel',
      confirmationRequired: false,
    ),
    iosPromptInfo: IosPromptInfo(
      saveTitle: 'Turn on biometric reset',
      accessTitle: 'Reset your LedgerLock password',
    ),
  );

  static const _savePrompt = PromptInfo(
    androidPromptInfo: AndroidPromptInfo(
      title: 'Turn on fingerprint reset',
      subtitle: 'Confirm with your fingerprint or face',
      negativeButton: 'Cancel',
      confirmationRequired: false,
    ),
    iosPromptInfo: IosPromptInfo(
      saveTitle: 'Turn on biometric reset',
      accessTitle: 'Turn on biometric reset',
    ),
  );

  Future<BiometricStorageFile> _file() => BiometricStorage().getStorage(
    _name,
    options: StorageFileInitOptions(), // auth required on every read, biometric only
    promptInfo: _prompt,
  );

  @override
  Future<bool> isAvailable() async =>
      await BiometricStorage().canAuthenticate() == CanAuthenticateResponse.success;

  @override
  Future<void> save(Uint8List secret) async =>
      (await _file()).write(base64.encode(secret), promptInfo: _savePrompt);

  @override
  Future<Uint8List?> read() async {
    try {
      final v = await (await _file()).read();
      return v == null ? null : base64.decode(v);
    } on AuthException catch (e) {
      if (e.code == AuthExceptionCode.userCanceled || e.code == AuthExceptionCode.canceled) return null;
      rethrow;
    }
  }

  @override
  Future<void> delete() async => (await _file()).delete();
}
