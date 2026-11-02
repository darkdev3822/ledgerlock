// SECURITY.md T18 (found by the M9.5 crypto review): an import still running when the app auto-locked used to
// encrypt with the wiped (all-zero) file key and leave a decryptable orphan file on disk.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerlock/app/app_controller.dart';
import 'package:ledgerlock/security/biometric_reset.dart';
import 'package:ledgerlock/media/documents.dart';
import 'package:ledgerlock/security/attempt_guard.dart';
import 'package:ledgerlock/security/crypto.dart';
import 'package:ledgerlock/security/encrypted_file_store.dart';
import 'package:ledgerlock/security/session.dart';
import 'package:ledgerlock/security/vault.dart';

class _NoBiometrics implements BiometricSecretStore {
  @override
  Future<bool> isAvailable() async => false;
  @override
  Future<void> save(Uint8List s) async {}
  @override
  Future<Uint8List?> read() async => null;
  @override
  Future<void> delete() async {}
}

KdfParams fastKdf() => KdfParams.generate(memoryKiB: 256, iterations: 1);

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('ll_lock_race'));
  tearDown(() => dir.deleteSync(recursive: true));

  List<File> llf() => Directory('${dir.path}/files').listSync().whereType<File>().toList();

  test('import after lock fails and leaves no file; nothing is ever sealed with a zero key', () async {
    final s = await Session.open(dir, 'pw-1', vault: Vault(dir, kdfFactory: fastKdf));
    final docs = Documents(s.db, s.files); // captured before the "picker", like the UI does
    await s.lock();
    final secret = Uint8List.fromList('SSN 123-45-6789 W-2'.codeUnits);
    await expectLater(
      docs.importFile(name: 'w2.pdf', mime: 'application/pdf', bytes: secret, folder: 'tax_form', year: 2026),
      throwsA(anything),
    );
    expect(llf(), isEmpty, reason: 'no orphan file after a failed import');
    // Belt and braces: a store whose key is all zero refuses to write even if nobody closed it.
    final zeroStore = EncryptedFileStore(Directory('${dir.path}/z'), Uint8List(32));
    await expectLater(zeroStore.put(secret), throwsStateError);
  });

  test('lock landing between the file write and the DB insert removes the written file', () async {
    final s = await Session.open(dir, 'pw-1', vault: Vault(dir, kdfFactory: fastKdf));
    final docs = Documents(s.db, s.files);
    await s.db.close(); // DB gone but store open: the insert fails after files were written
    await expectLater(
      docs.importFile(
        name: 'a.pdf',
        mime: 'application/pdf',
        bytes: Uint8List.fromList([1, 2, 3]),
        folder: 'other',
        year: 2026,
      ),
      throwsA(anything),
    );
    expect(llf(), isEmpty);
  });

  test('T19: a recovered key waiting for a new password is wiped by lock, and the UI is told to go back', () {
    final app = AppController(dataDir: dir, biometrics: _NoBiometrics());
    final dk = Uint8List.fromList(List.filled(32, 7));
    app.holdRecoveryKey(dk);
    final epoch = app.recoveryEpoch;
    app.lock(); // what auto-lock calls on timeout
    expect(dk.every((b) => b == 0), isTrue, reason: 'key bytes wiped');
    expect(app.recoveryEpoch, epoch + 1);
    // Backing out also wipes.
    final dk2 = Uint8List.fromList(List.filled(32, 9));
    app.holdRecoveryKey(dk2);
    app.releaseRecoveryKey();
    expect(dk2.every((b) => b == 0), isTrue);
  });

  test('T20: moving the wall clock forward does not shorten a lockout; a reboot restarts it', () {
    var wall = DateTime(2026, 11, 2, 10);
    Duration? up = const Duration(hours: 5);
    final g = AttemptGuard(dir, now: () => wall, uptime: () => up);
    for (var i = 0; i < 9; i++) {
      g.recordFailure();
    }
    expect(g.remaining(), const Duration(hours: 1));
    wall = wall.add(const Duration(days: 3)); // attacker sets the clock forward
    expect(g.remaining(), const Duration(hours: 1), reason: 'boot clock has not moved');
    up = up! + const Duration(minutes: 20);
    expect(g.remaining(), const Duration(minutes: 40));
    up = const Duration(seconds: 30); // reboot
    expect(g.remaining(), const Duration(hours: 1), reason: 'restarts in full after reboot');
    up = const Duration(minutes: 61);
    expect(g.remaining(), Duration.zero);
  });

  test('T23: answers match across composed/decomposed accents, case and punctuation', () {
    expect(normalizeAnswer('José'), 'jose');
    expect(normalizeAnswer('Jose\u0301'), 'jose');
    expect(normalizeAnswer('  MÜNCHEN!! '), 'munchen');
    expect(normalizeAnswer("O'Brien-Smith"), 'o brien smith');
  });
}
