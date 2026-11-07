// M9 encrypted backups: round trip to a fresh install, integrity, and hostile files (SECURITY.md T25).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerlock/backup/backup.dart';
import 'package:ledgerlock/data/database.dart';
import 'package:ledgerlock/media/documents.dart';
import 'package:ledgerlock/security/crypto.dart';
import 'package:ledgerlock/security/session.dart';
import 'package:ledgerlock/security/vault.dart';

KdfParams fastKdf() => KdfParams.generate(memoryKiB: 256, iterations: 1);
Vault fastVault(Directory d) =>
    Vault(d, kdfFactory: fastKdf, recoveryKdfFactory: fastKdf, questionsKdfFactory: fastKdf);

void main() {
  late Directory root, phoneA, phoneB;
  setUp(() {
    root = Directory.systemTemp.createTempSync('ll_backup');
    phoneA = Directory('${root.path}/a')..createSync();
    phoneB = Directory('${root.path}/b')..createSync();
  });
  tearDown(() => root.deleteSync(recursive: true));

  /// Phone A: a vault with a record, a receipt file, a recovery key and a (device-bound) fingerprint slot.
  Future<(File, String)> makeBackup() async {
    final s = await Session.open(phoneA, 'pw-A', vault: fastVault(phoneA));
    final code = RecoveryKey.generate();
    await s.vault.setRecoveryKey(s.dataKey, code);
    await s.vault.setBiometricSecret(s.dataKey, LedgerCrypto.randomBytes(32));
    final id = await s.db.addEntry(
      LedgerEntriesCompanion.insert(
        isIncome: true,
        date: '2026-03-01',
        amountCents: 123456,
        category: 'services',
        party: const Value('Zqx Client'),
      ),
    );
    await Documents(s.db, s.files).importFile(
      name: 'w2.pdf',
      mime: 'application/pdf',
      bytes: Uint8List.fromList('W-2 SSN 123-45-6789'.codeUnits),
      folder: 'tax_form',
      year: 2026,
      entryId: id,
    );
    final out = File('${root.path}/my.llbackup');
    final r = await createBackup(dataDir: phoneA, session: s, dataKey: s.dataKey, out: out);
    expect(r.files, 1);
    await s.lock();
    return (out, code);
  }

  test('round trip to a fresh install with the password; data and receipts come back', () async {
    final (file, _) = await makeBackup();
    final raw = file.readAsBytesSync();
    // Nothing readable inside: not the payee, not the W-2 text, not a plain SQLite header.
    final asText = String.fromCharCodes(raw);
    expect(asText.contains('Zqx Client'), isFalse);
    expect(asText.contains('123-45-6789'), isFalse);
    expect(asText.contains('SQLite format 3'), isFalse, reason: 'VACUUM INTO snapshot stays encrypted');

    final b = await BackupFile.open(file);
    expect(b.slots, containsAll([Slot.password, Slot.recovery]));
    expect(b.slots.contains(Slot.biometric), isFalse, reason: 'fingerprint slot is tied to the old phone');

    final staging = Directory('${phoneB.path}/.restore-staging');
    final v = await b.stageVault(staging);
    final dk = await v.unlock('pw-A');
    await b.extractVerified(staging, dk);
    await installStaged(staging, phoneB);

    final s = await Session.fromDataKey(phoneB, dk, Vault(phoneB));
    final rows = await s.db.watchYear(2026).first;
    expect(rows.single.party, 'Zqx Client');
    expect(rows.single.amountCents, 123456);
    final att = await s.db.watchAttachments(2026).first;
    expect(String.fromCharCodes(await s.files.get(att.single.fileId)), 'W-2 SSN 123-45-6789');
    expect(att.single.entryId, rows.single.id);
    await s.lock();
    expect(Directory('${phoneB.path}/.restore-staging').existsSync(), isFalse);
  });

  // Rewrites the plain header JSON of a backup file (length-prefixed after "LLBK" + version byte).
  void editHeader(File f, void Function(Map<String, dynamic>) edit) {
    final b = f.readAsBytesSync();
    final len = ByteData.sublistView(b, 5, 9).getUint32(0);
    final j = jsonDecode(utf8.decode(b.sublist(9, 9 + len))) as Map<String, dynamic>;
    edit(j);
    final h = utf8.encode(jsonEncode(j));
    final l = ByteData(4)..setUint32(0, h.length);
    f.writeAsBytesSync([...b.sublist(0, 5), ...l.buffer.asUint8List(), ...h, ...b.sublist(9 + len)]);
  }

  test('backups record the schema; a newer one is refused up front, an older one (no field) still opens', () async {
    final (file, _) = await makeBackup();
    editHeader(file, (j) => expect(j['schema'], vaultSchemaVersion));
    final old = File('${root.path}/old.llbackup')..writeAsBytesSync(file.readAsBytesSync());
    editHeader(old, (j) => j.remove('schema'));
    final staging = Directory('${phoneB.path}/st');
    final b = await BackupFile.open(old);
    await b.extractVerified(staging, await (await b.stageVault(staging)).unlock('pw-A'));
    editHeader(file, (j) => j['schema'] = vaultSchemaVersion + 1);
    await expectLater(BackupFile.open(file), throwsA(isA<BackupInvalid>().having((e) => e.why, 'why', newerBackup)));
  });

  test('restore with the recovery key works too', () async {
    final (file, code) = await makeBackup();
    final b = await BackupFile.open(file);
    final staging = Directory('${phoneB.path}/st');
    final dk = await (await b.stageVault(staging)).recoverWithKey(code);
    await b.extractVerified(staging, dk);
  });

  test('wrong password, flipped byte, truncation and non-backups are rejected before touching live data', () async {
    final (file, _) = await makeBackup();
    final b = await BackupFile.open(file);
    final staging = Directory('${phoneB.path}/st');
    await expectLater((await b.stageVault(staging)).unlock('nope'), throwsA(isA<WrongPassword>()));

    final dk = await (await b.stageVault(staging)).unlock('pw-A');
    final bytes = file.readAsBytesSync();

    final flipped = Uint8List.fromList(bytes)..[bytes.length - 3] ^= 0x01;
    final f2 = File('${root.path}/flipped.llbackup')..writeAsBytesSync(flipped);
    await expectLater(
      (await BackupFile.open(f2)).extractVerified(Directory('${phoneB.path}/s2'), dk),
      throwsA(isA<BackupInvalid>()),
    );

    final f3 = File('${root.path}/cut.llbackup')..writeAsBytesSync(bytes.sublist(0, bytes.length - 10));
    await expectLater(
      (await BackupFile.open(f3)).extractVerified(Directory('${phoneB.path}/s3'), dk),
      throwsA(isA<BackupInvalid>()),
    );

    final f4 = File('${root.path}/x.llbackup')
      ..writeAsBytesSync(Uint8List.fromList('hello world, not a backup'.codeUnits));
    await expectLater(BackupFile.open(f4), throwsA(isA<BackupInvalid>()));

    // Header claiming a 4 GB header is refused without allocating it.
    final f5 = File('${root.path}/huge.llbackup')..writeAsBytesSync([...'LLBK'.codeUnits, 1, 0xFF, 0xFF, 0xFF, 0xFF]);
    await expectLater(BackupFile.open(f5), throwsA(isA<BackupInvalid>()));

    expect(phoneB.listSync().where((e) => !e.path.contains('/s')), isEmpty, reason: 'live dir untouched');
    LedgerCrypto.zero(dk);
  });
}
