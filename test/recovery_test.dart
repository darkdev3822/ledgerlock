import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerlock/security/crypto.dart';
import 'package:ledgerlock/security/session.dart';
import 'package:ledgerlock/security/vault.dart';
import 'package:ledgerlock/ui/recovery_screens.dart';

KdfParams fastKdf() => KdfParams.generate(memoryKiB: 256, iterations: 1);
Vault fastVault(Directory d) =>
    Vault(d, kdfFactory: fastKdf, recoveryKdfFactory: fastKdf, questionsKdfFactory: fastKdf);

const qs = ['Q one?', 'Q two?', 'Q three?'];

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('ll_rec'));
  tearDown(() => dir.deleteSync(recursive: true));

  group('RecoveryKey', () {
    test('format, normalisation and look-alikes', () {
      final k = RecoveryKey.generate();
      expect(RegExp(r'^([0-9A-HJKMNP-TV-Z]{5}-){5}[0-9A-HJKMNP-TV-Z]{5}$').hasMatch(k), isTrue, reason: k);
      expect(RecoveryKey.isWellFormed(k.toLowerCase().replaceAll('-', ' ')), isTrue);
      expect(RecoveryKey.normalize('o0 iI-l1'), '001111');
      expect(RecoveryKey.isWellFormed('ABC'), isFalse);
      expect({for (var i = 0; i < 50; i++) RecoveryKey.generate()}.length, 50);
    });

    test('answers normalise case, spaces and punctuation', () {
      expect(normalizeAnswer('  Mr. Whiskers!! '), normalizeAnswer('mr whiskers'));
      expect(normalizeAnswer('São Paulo'), 'são paulo');
    });
  });

  group('Vault slots', () {
    test('every method unlocks the same data key, and wrong secrets fail', () async {
      final v = fastVault(dir);
      final dk = Uint8List.fromList(await v.create('pw'));
      final code = RecoveryKey.generate();
      await v.setRecoveryKey(dk, code);
      await v.setSecurityQuestions(dk, qs, ['Rex', 'Elm Street', 'Volvo']);
      final bio = LedgerCrypto.randomBytes(32);
      await v.setBiometricSecret(dk, bio);

      expect(await v.enabledSlots(), Slot.values.toSet());
      expect(await v.securityQuestions(), qs);
      expect(await v.recoverWithKey(code.toLowerCase().replaceAll('-', ' ')), dk);
      expect(await v.recoverWithAnswers(['rex', ' elm street! ', 'VOLVO']), dk);
      expect(await v.recoverWithBiometricSecret(bio), dk);

      expect(() => v.recoverWithKey(RecoveryKey.generate()), throwsA(isA<RecoveryFailed>()));
      expect(() => v.recoverWithKey('short'), throwsA(isA<RecoveryFailed>()));
      expect(() => v.recoverWithAnswers(['rex', 'elm street', 'saab']), throwsA(isA<RecoveryFailed>()));
      expect(() => v.recoverWithBiometricSecret(LedgerCrypto.randomBytes(32)), throwsA(isA<RecoveryFailed>()));
    });

    test('forgot password: recover, set new password, old one stops working, data intact', () async {
      var s = await Session.open(dir, 'old-pw', vault: fastVault(dir));
      final code = RecoveryKey.generate();
      await s.vault.setRecoveryKey(s.dataKey, code);
      await s.db.setSetting('marker', 'kept');
      await s.lock();

      final v = fastVault(dir);
      final dk = await v.recoverWithKey(code);
      await v.setPassword(dk, 'new-pw');
      s = await Session.fromDataKey(dir, dk, v);
      expect(await s.db.getSetting('marker'), 'kept');
      await s.lock();

      expect(() => v.unlock('old-pw'), throwsA(isA<WrongPassword>()));
      final again = await Session.open(dir, 'new-pw', vault: fastVault(dir));
      expect(await again.db.getSetting('marker'), 'kept');
      expect(await fastVault(dir).recoverWithKey(code), isNotEmpty, reason: 'recovery key still valid');
      await again.lock();
    });

    test('new recovery key replaces the old one; removing a slot; password slot is required', () async {
      final v = fastVault(dir);
      final dk = await v.create('pw');
      final a = RecoveryKey.generate(), b = RecoveryKey.generate();
      await v.setRecoveryKey(dk, a);
      await v.setRecoveryKey(dk, b);
      expect(() => v.recoverWithKey(a), throwsA(isA<RecoveryFailed>()));
      expect(await v.recoverWithKey(b), dk);
      await v.setBiometricSecret(dk, LedgerCrypto.randomBytes(32));
      await v.removeSlot(Slot.biometric);
      expect(await v.enabledSlots(), {Slot.password, Slot.recovery});
      expect(() => v.removeSlot(Slot.password), throwsArgumentError);
      expect(() => v.setSecurityQuestions(dk, qs, ['a', 'bb', 'cc']), throwsArgumentError);
    });

    test('v1 header (M1 format) still unlocks and migrates to v2 on next write', () async {
      final params = fastKdf();
      final dk = LedgerCrypto.randomBytes(32);
      final kek = await LedgerCrypto.deriveKey('pw', params);
      final wrapped = await LedgerCrypto.encrypt(dk, kek, aad: utf8.encode('ledgerlock/v1/data-key'));
      File('${dir.path}/vault.json')
          .writeAsStringSync(jsonEncode({'v': 1, 'kdf': params.toJson(), 'wrappedKey': base64.encode(wrapped)}));

      final v = fastVault(dir);
      expect(await v.unlock('pw'), dk);
      await v.setRecoveryKey(dk, RecoveryKey.generate());
      final j = jsonDecode(File('${dir.path}/vault.json').readAsStringSync());
      expect(j['v'], 2);
      expect(await v.unlock('pw'), dk);
    });

    test('header never contains the data key, the code, or the answers', () async {
      final v = fastVault(dir);
      final dk = await v.create('pw');
      final code = RecoveryKey.generate();
      await v.setRecoveryKey(dk, code);
      await v.setSecurityQuestions(dk, qs, ['Rex', 'Elm', 'Volvo']);
      final h = File('${dir.path}/vault.json').readAsStringSync();
      expect(h.contains(base64.encode(dk)), isFalse);
      expect(h.contains(RecoveryKey.normalize(code)), isFalse);
      expect(h.toLowerCase().contains('volvo'), isFalse);
    });
  });

  testWidgets('recovery key screen requires typing the last two groups', (t) async {
    var confirmed = false;
    const code = 'AAAAA-BBBBB-CCCCC-DDDDD-EEEEE-FFFFF';
    t.view.physicalSize = const Size(1080, 2400); // phone-sized
    t.view.devicePixelRatio = 2.625;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        home: RecoveryKeyScreen(code: code, onConfirmed: () => confirmed = true),
      ),
    );
    expect(find.text('FFFFF'), findsOneWidget);
    await t.tap(find.text('I\'ve written it down'));
    await t.pump();
    await t.enterText(find.byKey(const Key('rkCheck')), 'EEEEE-FFFFX');
    await t.tap(find.text('Confirm'));
    await t.pump();
    expect(confirmed, isFalse);
    expect(find.textContaining('doesn\'t match'), findsOneWidget);
    await t.enterText(find.byKey(const Key('rkCheck')), 'eeeee fffff');
    await t.tap(find.text('Confirm'));
    await t.pump();
    expect(confirmed, isTrue);
  });
}
