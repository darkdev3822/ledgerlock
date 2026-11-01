import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerlock/data/database.dart';
import 'package:ledgerlock/security/auto_lock.dart';
import 'package:ledgerlock/security/crypto.dart';
import 'package:ledgerlock/security/encrypted_file_store.dart';
import 'package:ledgerlock/security/session.dart';
import 'package:ledgerlock/security/vault.dart';

// Cheap Argon2 for tests; production defaults are checked separately.
KdfParams fastKdf() => KdfParams.generate(memoryKiB: 256, iterations: 1);

bool containsBytes(List<int> hay, List<int> needle) {
  outer:
  for (var i = 0; i <= hay.length - needle.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (hay[i + j] != needle[j]) continue outer;
    }
    return true;
  }
  return false;
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('ll_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  group('LedgerCrypto', () {
    test('AES-GCM round trip, random nonce, tamper and AAD detection', () async {
      final key = LedgerCrypto.randomBytes(32);
      final msg = Uint8List.fromList(utf8.encode('secret receipt'));
      final a = await LedgerCrypto.encrypt(msg, key, aad: [1]);
      final b = await LedgerCrypto.encrypt(msg, key, aad: [1]);
      expect(a, isNot(equals(b)), reason: 'nonce must be random');
      expect(await LedgerCrypto.decrypt(a, key, aad: [1]), msg);
      expect(() => LedgerCrypto.decrypt(a, key, aad: [2]), throwsA(isA<DecryptionFailed>()));
      final t = Uint8List.fromList(a)..[20] ^= 1;
      expect(() => LedgerCrypto.decrypt(t, key, aad: [1]), throwsA(isA<DecryptionFailed>()));
      expect(
        () => LedgerCrypto.decrypt(a, LedgerCrypto.randomBytes(32), aad: [1]),
        throwsA(isA<DecryptionFailed>()),
      );
    });

    test('Argon2id is deterministic per salt and differs across salts', () async {
      final p = fastKdf();
      final k1 = await LedgerCrypto.deriveKey('pw', p);
      expect(k1, await LedgerCrypto.deriveKey('pw', p));
      expect(k1, isNot(equals(await LedgerCrypto.deriveKey('pw2', p))));
      expect(k1, isNot(equals(await LedgerCrypto.deriveKey('pw', fastKdf()))));
      expect(k1.length, 32);
    });

    test('Argon2id known answer matches reference C impl (argon2-cffi)', () async {
      // Cross-checked against libargon2 (argon2-cffi). A change here would lock users out.
      final p = KdfParams(memoryKiB: 256, iterations: 1, parallelism: 1, salt: Uint8List(16));
      final k = await LedgerCrypto.deriveKey('password', p);
      final hex = k.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      expect(hex, 'd2ced44bd83f1af09e2f68f7f5ae07825781c3921196a8cf3fb50ab53f877d78');
    });

    test('subkeys differ by purpose', () async {
      final m = LedgerCrypto.randomBytes(32);
      expect(await LedgerCrypto.subkey(m, 'db'), isNot(equals(await LedgerCrypto.subkey(m, 'files'))));
    });

    test('production Argon2id defaults: timing on this host', () async {
      final sw = Stopwatch()..start();
      await LedgerCrypto.deriveKey('correct horse battery', KdfParams.generate());
      // ignore: avoid_print
      print('Argon2id default params took ${sw.elapsedMilliseconds} ms (host, JIT)');
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('Vault', () {
    test('create, unlock, wrong password, change password', () async {
      final v = Vault(dir, kdfFactory: fastKdf);
      final dk = Uint8List.fromList(await v.create('hunter2!'));
      expect(await v.unlock('hunter2!'), dk);
      expect(() => v.unlock('nope'), throwsA(isA<WrongPassword>()));
      await v.changePassword('hunter2!', 'new pass');
      expect(await v.unlock('new pass'), dk, reason: 'data key unchanged');
      expect(() => v.unlock('hunter2!'), throwsA(isA<WrongPassword>()));
      expect(containsBytes(v.headerFile.readAsBytesSync(), dk), isFalse);
      expect(() => v.create('x'), throwsStateError);
    });
  });

  group('EncryptedFileStore', () {
    test('no plaintext on disk; tamper and swap detected', () async {
      final store = EncryptedFileStore(Directory('${dir.path}/files'), LedgerCrypto.randomBytes(32));
      final photo = Uint8List.fromList(utf8.encode('JPEG-RECEIPT-STAPLES-\$42.17' * 50));
      final id = await store.put(photo);
      final id2 = await store.put(Uint8List.fromList([1, 2, 3]));
      expect(await store.get(id), photo);
      for (final f in store.dir.listSync().whereType<File>()) {
        expect(containsBytes(f.readAsBytesSync(), utf8.encode('STAPLES')), isFalse);
      }
      // Swap the two files on disk: AAD binding must reject it.
      File('${store.dir.path}/$id2.llf')
          .writeAsBytesSync(File('${store.dir.path}/$id.llf').readAsBytesSync());
      expect(() => store.get(id2), throwsA(isA<DecryptionFailed>()));
      expect(() => store.get('../etc'), throwsArgumentError);
      await store.delete(id);
      expect(File('${store.dir.path}/$id.llf').existsSync(), isFalse);
    });
  });

  group('SQLCipher database', () {
    test('encrypted at rest; unreadable with wrong key or no key', () async {
      final file = File('${dir.path}/t.db');
      final key = LedgerCrypto.randomBytes(32);
      var db = AppDatabase.open(file, key);
      await db.setSetting('marker', 'PLAINTEXT-MARKER-4242');
      expect(await db.getSetting('marker'), 'PLAINTEXT-MARKER-4242');
      await db.close();

      final raw = file.readAsBytesSync();
      expect(containsBytes(raw, ascii.encode('SQLite format 3')), isFalse);
      expect(containsBytes(raw, ascii.encode('PLAINTEXT-MARKER')), isFalse);

      db = AppDatabase.open(file, LedgerCrypto.randomBytes(32));
      await expectLater(db.getSetting('marker'), throwsA(anything));
      await db.close();

      db = AppDatabase.open(file, key);
      expect(await db.getSetting('marker'), 'PLAINTEXT-MARKER-4242');
      await db.close();
    });
  });

  group('Session', () {
    test('first open creates, reopen unlocks, wrong password rejected', () async {
      var s = await Session.open(dir, 'pw-1', vault: Vault(dir, kdfFactory: fastKdf));
      await s.db.setSetting('autoLockMinutes', '5');
      final id = await s.files.put(Uint8List.fromList([9, 9, 9]));
      await s.lock();

      await expectLater(
        Session.open(dir, 'wrong', vault: Vault(dir, kdfFactory: fastKdf)),
        throwsA(isA<WrongPassword>()),
      );

      s = await Session.open(dir, 'pw-1', vault: Vault(dir, kdfFactory: fastKdf));
      expect(await s.db.getSetting('autoLockMinutes'), '5');
      expect(await s.files.get(id), [9, 9, 9]);
      await s.lock();
    });
  });

  group('AutoLock', () {
    test('locks only after timeout in background; cover shown while away', () {
      var now = DateTime(2026, 1, 1);
      var locks = 0;
      final a = AutoLock(onLock: () => locks++, now: () => now);
      a.didChangeAppLifecycleState(AppLifecycleState.inactive);
      expect(a.coverVisible.value, isTrue);
      a.didChangeAppLifecycleState(AppLifecycleState.paused);
      now = now.add(const Duration(seconds: 30));
      a.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(locks, 0);
      expect(a.coverVisible.value, isFalse);

      a.didChangeAppLifecycleState(AppLifecycleState.paused);
      now = now.add(const Duration(minutes: 1));
      a.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(locks, 1);
    });
  });
}
