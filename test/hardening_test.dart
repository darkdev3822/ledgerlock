// Regression tests for SECURITY.md findings T1-T4.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:ledgerlock/media/receipt_image.dart';
import 'package:ledgerlock/security/attempt_guard.dart';
import 'package:ledgerlock/security/crypto.dart';
import 'package:ledgerlock/security/vault.dart';

KdfParams fastKdf() => KdfParams.generate(memoryKiB: 256, iterations: 1);

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('ll_hard'));
  tearDown(() => dir.deleteSync(recursive: true));

  group('T1 guess throttling', () {
    test('lockout escalates after 5 misses, survives restarts, resets on success', () async {
      var now = DateTime(2026, 11, 1, 12);
      AttemptGuard g() => AttemptGuard(dir, now: () => now);
      Vault v() => Vault(dir, kdfFactory: fastKdf, guard: g());
      await v().create('right');
      for (var i = 0; i < 4; i++) {
        await expectLater(v().unlock('wrong'), throwsA(isA<WrongPassword>()));
      }
      expect(g().remaining(), Duration.zero, reason: '4 misses: no lockout yet');
      await expectLater(v().unlock('wrong'), throwsA(isA<WrongPassword>()));
      // 5th miss -> 30 s lockout, even for the right password and across new instances.
      await expectLater(v().unlock('right'), throwsA(isA<TooManyAttempts>()));
      now = now.add(const Duration(seconds: 31));
      await expectLater(v().unlock('wrong'), throwsA(isA<WrongPassword>()));
      expect(g().remaining(), const Duration(minutes: 1), reason: '6th miss -> 1 min');
      now = now.add(const Duration(minutes: 1, seconds: 1));
      expect(await v().unlock('right'), hasLength(32));
      expect(g().failures, 0);
    });

    test('moving the clock backwards does not shorten a lockout', () {
      var now = DateTime(2026, 11, 1, 12);
      final g = AttemptGuard(dir, now: () => now);
      for (var i = 0; i < 9; i++) {
        g.recordFailure();
      }
      now = now.subtract(const Duration(days: 1));
      expect(g.remaining(), const Duration(hours: 1));
    });

    test('recovery key and answers share the limit; biometric does not count', () async {
      final v = Vault(dir, kdfFactory: fastKdf, recoveryKdfFactory: fastKdf, questionsKdfFactory: fastKdf);
      final dk = await v.create('pw');
      await v.setBiometricSecret(dk, LedgerCrypto.randomBytes(32));
      await v.setRecoveryKey(dk, RecoveryKey.generate());
      for (var i = 0; i < 10; i++) {
        await expectLater(
          v.recoverWithBiometricSecret(LedgerCrypto.randomBytes(32)),
          throwsA(isA<RecoveryFailed>()),
        );
      }
      expect(v.guard.failures, 0);
      for (var i = 0; i < 5; i++) {
        await expectLater(v.recoverWithKey(RecoveryKey.generate()), throwsA(isA<RecoveryFailed>()));
      }
      await expectLater(v.unlock('pw'), throwsA(isA<TooManyAttempts>()));
    });
  });

  group('T4 tampered vault header', () {
    test('absurd Argon2 parameters are rejected instead of exhausting memory', () async {
      final v = Vault(dir, kdfFactory: fastKdf);
      await v.create('pw');
      final j = jsonDecode(v.headerFile.readAsStringSync()) as Map<String, dynamic>;
      (j['slots']['password']['kdf'] as Map)['m'] = 4 * 1024 * 1024; // 4 GiB
      v.headerFile.writeAsStringSync(jsonEncode(j));
      final sw = Stopwatch()..start();
      await expectLater(v.unlock('pw'), throwsFormatException);
      expect(sw.elapsedMilliseconds, lessThan(1000));
      for (final bad in [
        {'alg': 'argon2id', 'm': 19456, 't': 1000, 'p': 1, 'salt': base64.encode(Uint8List(16))},
        {'alg': 'argon2id', 'm': 19456, 't': 2, 'p': 64, 'salt': base64.encode(Uint8List(16))},
        {'alg': 'argon2id', 'm': 19456, 't': 2, 'p': 1, 'salt': base64.encode(Uint8List(4))},
        {'alg': 'argon2id', 'm': '19456', 't': 2, 'p': 1, 'salt': base64.encode(Uint8List(16))},
        {'alg': 'scrypt', 'm': 19456, 't': 2, 'p': 1, 'salt': base64.encode(Uint8List(16))},
      ]) {
        expect(() => KdfParams.fromJson(bad), throwsFormatException, reason: '$bad');
      }
    });
  });

  group('T2 malicious images', () {
    test('a decompression bomb is refused quickly without allocating', () {
      final bomb = File('test/fixtures/bomb.png').readAsBytesSync();
      final sw = Stopwatch()..start();
      expect(safeDecode(bomb), isNull);
      expect(thumbnailFor(bomb), isNull);
      expect(sw.elapsedMilliseconds, lessThan(500));
    });

    test('garbage and truncated files return null instead of throwing', () {
      final good = img.encodeJpg(img.Image(width: 40, height: 30));
      expect(safeDecode(good)!.width, 40);
      expect(safeDecode(Uint8List.fromList(List.generate(500, (i) => i % 251))), isNull);
      expect(safeDecode(Uint8List.sublistView(good, 0, good.length ~/ 3)), anyOf(isNull, isA<img.Image>()));
      expect(safeDecode(Uint8List(0)), isNull);
    });
  });
}
