// Vault header: holds the random data key wrapped by the password-derived key.
// Changing the password re-wraps the key; data is never re-encrypted (SPEC §1).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'crypto.dart';

class WrongPassword implements Exception {
  const WrongPassword();
  @override
  String toString() => 'WrongPassword';
}

class Vault {
  static const _aad = 'ledgerlock/v1/data-key';
  final File headerFile;

  /// [kdfFactory] lets tests use cheap Argon2 parameters.
  final KdfParams Function() kdfFactory;

  Vault(Directory dir, {KdfParams Function()? kdfFactory})
      : headerFile = File('${dir.path}/vault.json'),
        kdfFactory = kdfFactory ?? KdfParams.generate;

  bool get exists => headerFile.existsSync();

  /// First launch: create a random data key and wrap it with [password].
  Future<Uint8List> create(String password) async {
    if (exists) throw StateError('vault already exists');
    final dataKey = LedgerCrypto.randomBytes(LedgerCrypto.keyLength);
    await _writeWrapped(dataKey, password);
    return dataKey;
  }

  /// Returns the data key, or throws [WrongPassword].
  Future<Uint8List> unlock(String password) async {
    final j = jsonDecode(await headerFile.readAsString()) as Map<String, dynamic>;
    if (j['v'] != 1) throw const FormatException('unsupported vault version');
    final params = KdfParams.fromJson(j['kdf'] as Map<String, dynamic>);
    final kek = await LedgerCrypto.deriveKey(password, params);
    try {
      return await LedgerCrypto.decrypt(base64.decode(j['wrappedKey'] as String), kek,
          aad: utf8.encode(_aad));
    } on DecryptionFailed {
      throw const WrongPassword();
    } finally {
      LedgerCrypto.zero(kek);
    }
  }

  Future<void> changePassword(String oldPassword, String newPassword) async {
    final dataKey = await unlock(oldPassword);
    try {
      await _writeWrapped(dataKey, newPassword);
    } finally {
      LedgerCrypto.zero(dataKey);
    }
  }

  Future<void> _writeWrapped(Uint8List dataKey, String password) async {
    final params = kdfFactory();
    final kek = await LedgerCrypto.deriveKey(password, params);
    try {
      final wrapped = await LedgerCrypto.encrypt(dataKey, kek, aad: utf8.encode(_aad));
      final json = jsonEncode({'v': 1, 'kdf': params.toJson(), 'wrappedKey': base64.encode(wrapped)});
      // Atomic replace so a crash never leaves a half-written header (= lost data).
      final tmp = File('${headerFile.path}.tmp');
      await tmp.writeAsString(json, flush: true);
      await tmp.rename(headerFile.path);
    } finally {
      LedgerCrypto.zero(kek);
    }
  }
}
