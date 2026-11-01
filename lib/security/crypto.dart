// LedgerLock crypto wrapper: the only file that touches crypto primitives.
// Argon2id (password -> key-encryption key), AES-256-GCM (wrap / encrypt),
// HKDF-SHA256 (data key -> purpose-specific subkeys).
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class DecryptionFailed implements Exception {
  const DecryptionFailed();
  @override
  String toString() => 'DecryptionFailed';
}

/// Argon2id parameters, stored next to the wrapped key so they can be retuned.
class KdfParams {
  final int memoryKiB;
  final int iterations;
  final int parallelism;
  final Uint8List salt;

  const KdfParams({
    required this.memoryKiB,
    required this.iterations,
    required this.parallelism,
    required this.salt,
  });

  /// OWASP minimum for Argon2id (19 MiB, t=2, p=1); retune on devices (SPEC §1: ~0.5 s).
  factory KdfParams.generate({int memoryKiB = 19456, int iterations = 2, int parallelism = 1}) => KdfParams(
    memoryKiB: memoryKiB,
    iterations: iterations,
    parallelism: parallelism,
    salt: LedgerCrypto.randomBytes(16),
  );

  Map<String, Object> toJson() => {
    'alg': 'argon2id',
    'm': memoryKiB,
    't': iterations,
    'p': parallelism,
    'salt': base64.encode(salt),
  };

  /// Accepted ranges: a tampered header must not be able to demand gigabytes of RAM or
  /// hours of CPU (DoS on every unlock), see SECURITY.md T4.
  static const maxMemoryKiB = 262144, maxIterations = 10, maxParallelism = 4;

  factory KdfParams.fromJson(Map<String, dynamic> j) {
    if (j['alg'] != 'argon2id') throw const FormatException('unknown kdf');
    final m = j['m'], t = j['t'], p = j['p'], salt = j['salt'];
    if (m is! int || t is! int || p is! int || salt is! String) throw const FormatException('bad kdf params');
    if (m < 64 || m > maxMemoryKiB || t < 1 || t > maxIterations || p < 1 || p > maxParallelism) {
      throw const FormatException('kdf params out of range');
    }
    final saltBytes = base64.decode(salt);
    if (saltBytes.length < 16 || saltBytes.length > 64) throw const FormatException('bad salt');
    return KdfParams(
      memoryKiB: j['m'] as int,
      iterations: j['t'] as int,
      parallelism: j['p'] as int,
      salt: base64.decode(j['salt'] as String),
    );
  }
}

class LedgerCrypto {
  LedgerCrypto._();

  static const keyLength = 32;
  static const nonceLength = 12;
  static const macLength = 16;
  static final _aes = AesGcm.with256bits();
  static final _rng = Random.secure();

  static Uint8List randomBytes(int n) => Uint8List.fromList(List<int>.generate(n, (_) => _rng.nextInt(256)));

  /// Argon2id, run in a background isolate so the UI stays responsive.
  static Future<Uint8List> deriveKey(String password, KdfParams p) =>
      deriveKeyBytes(utf8.encode(password), p);

  static Future<Uint8List> deriveKeyBytes(List<int> secret, KdfParams p) {
    final pw = Uint8List.fromList(secret);
    final salt = p.salt;
    final m = p.memoryKiB, t = p.iterations, par = p.parallelism;
    return Isolate.run(() async {
      final kdf = Argon2id(memory: m, iterations: t, parallelism: par, hashLength: keyLength);
      final key = await kdf.deriveKey(secretKey: SecretKey(pw), nonce: salt);
      return Uint8List.fromList(await key.extractBytes());
    });
  }

  /// HKDF-SHA256 subkey for one purpose (e.g. 'db', 'files'), so keys are never reused.
  static Future<Uint8List> subkey(Uint8List masterKey, String purpose) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: keyLength);
    final k = await hkdf.deriveKey(
      secretKey: SecretKey(masterKey),
      info: utf8.encode('ledgerlock/v1/$purpose'),
      nonce: const <int>[],
    );
    return Uint8List.fromList(await k.extractBytes());
  }

  /// AES-256-GCM. Output: nonce(12) || ciphertext || mac(16). [aad] binds context.
  static Future<Uint8List> encrypt(Uint8List plaintext, Uint8List key, {List<int> aad = const []}) async {
    final box = await _aes.encrypt(
      plaintext,
      secretKey: SecretKey(key),
      nonce: randomBytes(nonceLength),
      aad: aad,
    );
    return box.concatenation();
  }

  static Future<Uint8List> decrypt(Uint8List sealed, Uint8List key, {List<int> aad = const []}) async {
    if (sealed.length < nonceLength + macLength) throw const DecryptionFailed();
    try {
      final box = SecretBox.fromConcatenation(
        sealed,
        nonceLength: nonceLength,
        macLength: macLength,
        copy: true,
      );
      return Uint8List.fromList(await _aes.decrypt(box, secretKey: SecretKey(key), aad: aad));
    } on SecretBoxAuthenticationError {
      throw const DecryptionFailed();
    }
  }

  /// Best-effort wipe (Dart can't guarantee no copies, but we drop what we hold).
  static void zero(Uint8List? b) => b?.fillRange(0, b.length, 0);
}
