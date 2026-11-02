// Hostile review of M9 encrypted backups (SECURITY.md T25): crafted .llbackup files, header tampering, slot
// swaps, KDF downgrades, restore races and crash leftovers. Passing tests are regression guards; confirmed
// findings are kept as `skip: 'FINDING Bx: ...'` tests that assert the SAFE behaviour.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerlock/app/app_controller.dart';
import 'package:ledgerlock/backup/backup.dart';
import 'package:ledgerlock/data/database.dart';
import 'package:ledgerlock/media/documents.dart';
import 'package:ledgerlock/security/biometric_reset.dart';
import 'package:ledgerlock/security/crypto.dart';
import 'package:ledgerlock/security/session.dart';
import 'package:ledgerlock/security/vault.dart';

KdfParams fastKdf() => KdfParams.generate(memoryKiB: 256, iterations: 1);
Vault fastVault(Directory d) =>
    Vault(d, kdfFactory: fastKdf, recoveryKdfFactory: fastKdf, questionsKdfFactory: fastKdf);

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

// ---------- raw format helpers ----------

class Parsed {
  Map<String, dynamic> header;
  List<(String, Uint8List)> entries;
  Parsed(this.header, this.entries);
}

Parsed parse(Uint8List b) {
  final bd = ByteData.sublistView(b);
  final hl = bd.getUint32(5);
  final header = jsonDecode(utf8.decode(b.sublist(9, 9 + hl))) as Map<String, dynamic>;
  var p = 9 + hl;
  final entries = <(String, Uint8List)>[];
  while (p < b.length) {
    final nl = bd.getUint16(p);
    p += 2;
    final name = utf8.decode(b.sublist(p, p + nl));
    p += nl;
    final dl = bd.getUint64(p);
    p += 8;
    entries.add((name, b.sublist(p, p + dl)));
    p += dl;
  }
  return Parsed(header, entries);
}

Uint8List u16(int v) => (ByteData(2)..setUint16(0, v)).buffer.asUint8List();
Uint8List u32(int v) => (ByteData(4)..setUint32(0, v)).buffer.asUint8List();
Uint8List u64(int v) => (ByteData(8)..setUint64(0, v)).buffer.asUint8List();

Uint8List entryBytes(String name, List<int> data, {int? sizeField, int? nameLenField}) {
  final n = utf8.encode(name);
  return Uint8List.fromList([...u16(nameLenField ?? n.length), ...n, ...u64(sizeField ?? data.length), ...data]);
}

Uint8List build(Map<String, dynamic> header, List<(String, Uint8List)> entries, {List<int> trailing = const []}) {
  final h = utf8.encode(jsonEncode(header));
  return Uint8List.fromList([
    ...ascii.encode('LLBK'),
    1,
    ...u32(h.length),
    ...h,
    for (final (n, d) in entries) ...entryBytes(n, d),
    ...trailing,
  ]);
}

Uint8List rawWithHeader(List<int> headerBytes, [List<int> body = const []]) =>
    Uint8List.fromList([...ascii.encode('LLBK'), 1, ...u32(headerBytes.length), ...headerBytes, ...body]);

/// Seals a manifest the way createBackup does (attacks by someone who holds the data key).
Future<String> sealManifest(Uint8List dk, Object manifest) async {
  final key = await LedgerCrypto.subkey(dk, 'backup');
  final s = await LedgerCrypto.encrypt(
    utf8.encode(jsonEncode(manifest)),
    key,
    aad: utf8.encode('ledgerlock/v1/backup-manifest'),
  );
  return base64Encode(s);
}

Future<String> sha(List<int> d) async => base64Encode((await Sha256().hash(d)).bytes);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root, phoneA, phoneB;
  setUp(() {
    root = Directory.systemTemp.createTempSync('ll_bkfuzz');
    phoneA = Directory('${root.path}/a')..createSync();
    phoneB = Directory('${root.path}/b')..createSync();
  });
  tearDown(() => root.deleteSync(recursive: true));

  Future<(File, String, Uint8List)> makeBackup({
    Directory? dir,
    String pw = 'pw-A',
    String party = 'Zqx Client',
    int bigFileBytes = 0,
    bool questions = false,
  }) async {
    final d = dir ?? phoneA;
    final s = await Session.open(d, pw, vault: fastVault(d));
    final code = RecoveryKey.generate();
    await s.vault.setRecoveryKey(s.dataKey, code);
    if (questions) {
      await s.vault.setSecurityQuestions(s.dataKey, ['q1?', 'q2?', 'q3?'], ['aaa', 'bbb', 'ccc']);
    }
    final id = await s.db.addEntry(
      LedgerEntriesCompanion.insert(
        isIncome: true,
        date: '2026-03-01',
        amountCents: 123456,
        category: 'services',
        party: Value(party),
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
    if (bigFileBytes > 0) {
      File('${d.path}/files/${'ab' * 16}.llf').writeAsBytesSync(LedgerCrypto.randomBytes(bigFileBytes));
    }
    final out = File(
      '${root.path}/${d.uri.pathSegments.where((x) => x.isNotEmpty).last}-${DateTime.now().microsecondsSinceEpoch}.llbackup',
    );
    await createBackup(dataDir: d, session: s, dataKey: s.dataKey, out: out);
    final dk = Uint8List.fromList(s.dataKey);
    await s.lock();
    return (out, code, dk);
  }

  /// A live vault on phone B with its own record, to see whether a failed restore loses it.
  Future<void> makeLive(Directory d) async {
    final s = await Session.open(d, 'pw-live', vault: fastVault(d));
    await s.vault.setRecoveryKey(s.dataKey, RecoveryKey.generate());
    await s.db.addEntry(
      LedgerEntriesCompanion.insert(
        isIncome: true,
        date: '2026-04-01',
        amountCents: 777,
        category: 'services',
        party: const Value('LIVE DATA'),
      ),
    );
    await s.lock();
  }

  Future<String?> liveParty(Directory d, String pw) async {
    final Session s;
    try {
      s = await Session.open(d, pw, vault: fastVault(d));
    } catch (e) {
      return 'cannot open live vault: $e';
    }
    try {
      return (await s.db.watchYear(2026).first).single.party;
    } finally {
      await s.lock();
    }
  }

  Future<void> expectInvalidOnExtract(File f, Uint8List dk) async {
    final b = await BackupFile.open(f);
    await expectLater(b.extractVerified(Directory('${phoneB.path}/st'), dk), throwsA(isA<BackupInvalid>()));
  }

  File write(String n, List<int> bytes) => File('${root.path}/$n')..writeAsBytesSync(bytes);

  // ======================= header parsing (no secret needed) =======================

  group('header', () {
    test('wrong JSON types, missing fields, bad base64, nesting, non-UTF8 -> BackupInvalid', () async {
      final (f, _, _) = await makeBackup();
      final p = parse(f.readAsBytesSync());
      final good = p.header;
      final cases = <Object?>[
        {...good, 'vault': 'x'},
        {
          ...good,
          'vault': {'v': 2, 'slots': []},
        },
        {
          ...good,
          'vault': {'v': 1, 'slots': {}},
        },
        {...good, 'vault': null},
        {...good, 'manifest': 'not base64!!'},
        {...good, 'manifest': 5},
        {...good}..remove('manifest'),
        {...good, 'created': 12345},
        [1, 2, 3],
        'string',
        null,
      ];
      for (final c in cases) {
        final h = utf8.encode(jsonEncode(c));
        await expectLater(
          BackupFile.open(write('h.llbackup', rawWithHeader(h))),
          throwsA(isA<BackupInvalid>()),
          reason: '$c',
        );
      }
      // Deep nesting within the 256 KB cap, invalid UTF-8, and a zero-length header.
      final deep = utf8.encode('${'[' * 100000}${']' * 100000}');
      await expectLater(BackupFile.open(write('d.llbackup', rawWithHeader(deep))), throwsA(isA<BackupInvalid>()));
      await expectLater(
        BackupFile.open(write('u.llbackup', rawWithHeader([0xff, 0xfe, 0x80]))),
        throwsA(isA<BackupInvalid>()),
      );
      await expectLater(BackupFile.open(write('z.llbackup', rawWithHeader([]))), throwsA(isA<BackupInvalid>()));
      // Wrong version byte.
      final v2 = f.readAsBytesSync()..[4] = 2;
      await expectLater(BackupFile.open(write('v.llbackup', v2)), throwsA(isA<BackupInvalid>()));
      // Missing "created" only falls back to epoch (display-only), still opens.
      final noDate = {...good}..remove('created');
      expect((await BackupFile.open(write("n.llbackup", build(noDate, p.entries)))).created.millisecondsSinceEpoch, 0);
    });

    test('KDF downgrade / DoS params in the backup header are range-checked on the restore path', () async {
      final (f, _, _) = await makeBackup();
      final p = parse(f.readAsBytesSync());
      for (final kdf in [
        {'alg': 'argon2id', 'm': 8, 't': 1, 'p': 1},
        {'alg': 'argon2id', 'm': 1 << 30, 't': 1, 'p': 1},
        {'alg': 'argon2id', 'm': 1024, 't': 100000, 'p': 1},
        {'alg': 'pbkdf2'},
      ]) {
        final h = jsonDecode(jsonEncode(p.header)) as Map<String, dynamic>;
        final pw = h['vault']['slots']['password'] as Map<String, dynamic>;
        pw['kdf'] = {...(pw['kdf'] as Map), ...kdf};
        final b = await BackupFile.open(write('k.llbackup', build(h, p.entries)));
        final v = await b.stageVault(Directory('${phoneB.path}/st'));
        await expectLater(v.unlock('pw-A'), throwsA(anything), reason: '$kdf');
      }
      // Lowering legal params just breaks the unwrap (params are bound to the derived key).
      final h = jsonDecode(jsonEncode(p.header)) as Map<String, dynamic>;
      (h['vault']['slots']['password']['kdf'] as Map)['m'] = 64;
      final b = await BackupFile.open(write('k2.llbackup', build(h, p.entries)));
      await expectLater(
        (await b.stageVault(Directory('${phoneB.path}/st2'))).unlock('pw-A'),
        throwsA(isA<WrongPassword>()),
      );
    });
  });

  // ======================= body parsing (with the right key) =======================

  group('body', () {
    test('duplicates, reordering, extra/missing entries, nameLen 0, lying sizes, trailing bytes', () async {
      final (f, _, dk) = await makeBackup();
      final p = parse(f.readAsBytesSync());
      final h = p.header;
      final e = p.entries;
      expect(e.length, 2);

      // Reordered entries are fine (each is verified by name).
      final b = await BackupFile.open(write('r.llbackup', build(h, e.reversed.toList())));
      await b.extractVerified(Directory('${phoneB.path}/ok'), dk);

      await expectInvalidOnExtract(write('dup.llbackup', build(h, [...e, e.first])), dk);
      await expectInvalidOnExtract(write('miss.llbackup', build(h, [e.first])), dk);
      await expectInvalidOnExtract(
        write('extra.llbackup', build(h, [...e, ('files/${'0' * 32}.llf', Uint8List(3))])),
        dk,
      );
      await expectInvalidOnExtract(write('tr1.llbackup', build(h, e, trailing: [0])), dk);
      await expectInvalidOnExtract(write('tr2.llbackup', build(h, e, trailing: [0, 0])), dk);
      await expectInvalidOnExtract(write('tr3.llbackup', build(h, e, trailing: List.filled(100, 0x41))), dk);

      final hb = utf8.encode(jsonEncode(h));
      Uint8List withBody(List<int> body) => rawWithHeader(hb, body);
      // nameLen 0, nameLen past EOF, size u64 max (negative in Dart), size just over 4 GB, size larger than file.
      await expectInvalidOnExtract(write('n0.llbackup', withBody(entryBytes('', []))), dk);
      await expectInvalidOnExtract(write('nl.llbackup', withBody([...u16(60000), 1, 2])), dk);
      for (final sz in [-1, 0x7fffffffffffffff, (4 << 30) + 1, e.first.$2.length + 1, e.first.$2.length - 1]) {
        await expectInvalidOnExtract(
          write('sz.llbackup', withBody(entryBytes(e.first.$1, e.first.$2, sizeField: sz))),
          dk,
        );
      }
      // Traversal / lookalike names.
      for (final n in [
        '../ledger.db',
        'files/../../vault.json',
        'files/${'A' * 32}.llf',
        'ledger.db\n',
        'ledger.db\u0000',
        'vault.json',
        'files/${'0' * 32}.llf/x',
      ]) {
        await expectInvalidOnExtract(write('nm.llbackup', withBody(entryBytes(n, [1]))), dk);
      }
      expect(Directory('${phoneB.path}/vault.json').existsSync(), isFalse);
      expect(File('${root.path}/vault.json').existsSync(), isFalse);
    });

    test('manifest crafted by a key holder: duplicates and traversal names are still contained', () async {
      final (f, _, dk) = await makeBackup();
      final p = parse(f.readAsBytesSync());
      final e = p.entries.first;
      final ent = {'name': e.$1, 'size': e.$2.length, 'sha256': await sha(e.$2)};
      // Manifest lists the same entry twice: map collapses it, body has it once -> accepted (harmless).
      final h1 = {
        ...p.header,
        'manifest': await sealManifest(dk, {
          'created': '2026-11-02T00:00:00.000',
          'entries': [ent, ent],
          'vault': p.header['vault'],
        }),
      };
      await (await BackupFile.open(write('m1.llbackup', build(h1, [e]))))
          .extractVerified(Directory('${phoneB.path}/m1'), dk);
      // Manifest with a traversal name: body name still has to pass the whitelist.
      final bad = {
        'name': '../../evil',
        'size': 1,
        'sha256': await sha([1]),
      };
      final h2 = {
        ...p.header,
        'manifest': await sealManifest(dk, {
          'created': '2026-11-02T00:00:00.000',
          'entries': [bad],
          'vault': p.header['vault'],
        }),
      };
      await expectInvalidOnExtract(
        write('m2.llbackup', rawWithHeader(utf8.encode(jsonEncode(h2)), entryBytes('../../evil', [1]))),
        dk,
      );
      expect(File('${root.path}/evil').existsSync(), isFalse);
    });

    test('slot swap: header (slots + manifest) of backup A with body of backup B is rejected', () async {
      final (fa, _, dka) = await makeBackup(party: 'A');
      final (fb, _, _) = await makeBackup(dir: phoneB, party: 'B');
      final a = parse(fa.readAsBytesSync()), bb = parse(fb.readAsBytesSync());
      await expectInvalidOnExtract(write('swap1.llbackup', build(a.header, bb.entries)), dka);
      // Slots of A + manifest of B: the A key can't open B's manifest.
      final mixed = {...a.header, 'manifest': bb.header['manifest']};
      await expectInvalidOnExtract(write('swap2.llbackup', build(mixed, bb.entries)), dka);
    });
  });

  // ======================= header vault is not authenticated =======================

  test('tampered header slots (unknown slot name) must not replace and brick the live vault', () async {
    final (f, _, _) = await makeBackup();
    final p = parse(f.readAsBytesSync());
    (p.header['vault']['slots'] as Map)['zzz'] = {'wrapped': 'AAAA'};
    final tampered = write('t.llbackup', build(p.header, p.entries));
    await makeLive(phoneB);

    final app = AppController(dataDir: phoneB, biometrics: _NoBiometrics(), vault: fastVault(phoneB));
    Object? err;
    try {
      // Rejected at open since the M9 fix (unknown slot names); otherwise caught by the sealed-header check.
      final b = await BackupFile.open(tampered);
      final dk = await (await b.stageVault(app.restoreStaging)).unlock('pw-A'); // password slot is genuine
      await app.finishRestore(b, dk);
    } catch (e) {
      err = e;
    }
    // Today: openWithDataKey -> enabledSlots() -> Slot.values.byName('zzz') throws ArgumentError AFTER the swap,
    // and every later unlock hits the same throw: the restored vault is bricked and the old one is deleted.
    expect(err, isNot(isA<ArgumentError>()), reason: 'restored vault.json has an unknown slot');
    await expectLater(fastVault(phoneB).enabledSlots(), completes, reason: 'every unlock calls enabledSlots');
    // Safe behaviour: either restore is refused before swapping, or the restored vault opens normally.
    if (err != null) {
      expect(await liveParty(phoneB, 'pw-live'), 'LIVE DATA', reason: 'UI says "Nothing was changed"');
    } else {
      expect(await fastVault(phoneB).enabledSlots(), isNotEmpty);
    }
  });

  test('tampered security-question prompts / dropped recovery slot in header are detected', () async {
    final (f, _, dk) = await makeBackup(questions: true);
    final p = parse(f.readAsBytesSync());
    final slots = p.header['vault']['slots'] as Map;
    (slots['questions'] as Map)['questions'] = ['Type your password here', 'q2?', 'q3?'];
    slots.remove('recovery');
    final b = await BackupFile.open(write('q.llbackup', build(p.header, p.entries)));
    final staging = Directory('${phoneB.path}/.restore-staging');
    await b.stageVault(staging);
    await expectLater(b.extractVerified(staging, dk), throwsA(isA<BackupInvalid>()));
  });

  // ======================= restore races and crash leftovers =======================

  test('leaving the restore screen while "Checking every file" must not destroy the live vault', () async {
    final (f, _, _) = await makeBackup(bigFileBytes: 24 << 20);
    await makeLive(phoneB);
    final app = AppController(dataDir: phoneB, biometrics: _NoBiometrics(), vault: fastVault(phoneB));
    final restoreIn = f.copySync('${phoneB.path}/.restore-in.llbackup');
    final b = await BackupFile.open(restoreIn);
    final dk = await (await b.stageVault(app.restoreStaging)).unlock('pw-A');
    final fut = app.finishRestore(b, dk);
    // User presses Back while busy: PopScope -> cancelRestore().
    while (!Directory('${app.restoreStaging.path}/files').existsSync() &&
        !File('${app.restoreStaging.path}/ledger.db').existsSync()) {
      await Future<void>.delayed(const Duration(microseconds: 50));
    }
    app.cancelRestore();
    try {
      await fut;
    } catch (_) {}
    expect(File('${phoneB.path}/vault.json').existsSync(), isTrue, reason: 'a vault header must remain');
    expect(File('${phoneB.path}/ledger.db').existsSync(), isTrue);
  });

  test('installStaged refuses a staging dir without vault.json / ledger.db (never deletes the only copy)', () async {
    await makeLive(phoneB);
    final staging = Directory('${phoneB.path}/.restore-staging')..createSync();
    try {
      await installStaged(staging, phoneB);
    } catch (_) {}
    expect(await liveParty(phoneB, 'pw-live'), 'LIVE DATA');
  });

  test('kill during installStaged: old vault in .restore-old is recovered, not deleted by the next restore', () async {
    await makeLive(phoneB);
    // State after a kill right after the first loop of installStaged (live files moved aside).
    final old = Directory('${phoneB.path}/.restore-old')..createSync();
    for (final n in ['vault.json', 'ledger.db', 'files']) {
      final t = FileSystemEntity.typeSync('${phoneB.path}/$n');
      if (t == FileSystemEntityType.directory) Directory('${phoneB.path}/$n').renameSync('${old.path}/$n');
      if (t == FileSystemEntityType.file) File('${phoneB.path}/$n').renameSync('${old.path}/$n');
    }
    final app = AppController(dataDir: phoneB, biometrics: _NoBiometrics(), vault: fastVault(phoneB));
    await app.init();
    // Safe: launch notices the interrupted swap and puts the old vault back (or finishes the new one).
    expect(app.vaultExists, isTrue, reason: 'otherwise the welcome/onboarding screen is shown');
  });

  // ======================= rollback / old secrets =======================

  test(
    'an old backup + an old (changed) password must not yield the CURRENT data key',
    skip: 'ACCEPTED B4 (SECURITY A1): mitigated by a fresh-backup prompt on password change; key rotation planned',
    () async {
      final (oldBackup, _, _) = await makeBackup(pw: 'old-leaked-pw');
      final s = await Session.open(phoneA, 'old-leaked-pw', vault: fastVault(phoneA));
      await s.vault.setPassword(s.dataKey, 'new-strong-pw');
      final current = Uint8List.fromList(s.dataKey);
      await s.lock();
      final b = await BackupFile.open(oldBackup);
      final dk = await (await b.stageVault(Directory('${root.path}/st'))).unlock('old-leaked-pw');
      expect(dk, isNot(equals(current)), reason: 'old secret opens the current phone DB and all newer backups');
    },
  );

  // ======================= guards that held =======================

  test('throwaway restore guard never touches the live attempts file; locks out on the staging copy', () async {
    final (f, _, _) = await makeBackup();
    await makeLive(phoneB);
    final live = File('${phoneB.path}/attempts.json');
    final before = live.existsSync() ? live.readAsStringSync() : null;
    final b = await BackupFile.open(f);
    final staging = Directory('${phoneB.path}/.restore-staging');
    for (var i = 0; i < 12; i++) {
      try {
        await (await b.stageVault(staging)).unlock('nope$i');
      } catch (_) {}
    }
    expect(live.existsSync() ? live.readAsStringSync() : null, before);
    expect(File('${staging.path}/attempts.json').existsSync(), isTrue);
  });

  test('failed verify wipes the key and staging, keeps live data; success leaves no leftovers', () async {
    final (f, _, _) = await makeBackup();
    await makeLive(phoneB);
    final app = AppController(dataDir: phoneB, biometrics: _NoBiometrics(), vault: fastVault(phoneB));
    final bytes = f.readAsBytesSync()..[f.lengthSync() - 5] ^= 1;
    final restoreIn = File('${phoneB.path}/.restore-in.llbackup')..writeAsBytesSync(bytes);
    final b = await BackupFile.open(restoreIn);
    final dk = await (await b.stageVault(app.restoreStaging)).unlock('pw-A');
    await expectLater(app.finishRestore(b, dk), throwsA(isA<BackupInvalid>()));
    expect(dk.every((x) => x == 0), isTrue);
    expect(app.restoreStaging.existsSync(), isFalse);
    expect(restoreIn.existsSync(), isFalse);
    expect(await liveParty(phoneB, 'pw-live'), 'LIVE DATA');

    // Real restore: replaces live data, opens it, no leftovers in the data dir.
    final restoreIn2 = f.copySync('${phoneB.path}/.restore-in.llbackup');
    final b2 = await BackupFile.open(restoreIn2);
    final dk2 = await (await b2.stageVault(app.restoreStaging)).unlock('pw-A');
    await app.finishRestore(b2, dk2);
    expect(app.unlocked, isTrue);
    expect((await app.db!.watchYear(2026).first).single.party, 'Zqx Client');
    final names = phoneB.listSync().map((e) => e.uri.pathSegments.where((s) => s.isNotEmpty).last).toSet();
    expect(names.intersection({'.restore-old', '.restore-staging', '.restore-in.llbackup', '.backup-work'}), isEmpty);
    app.lock();
  });

  test('createBackup cleans .backup-work on failure and refuses a zero key', () async {
    final s = await Session.open(phoneA, 'pw', vault: fastVault(phoneA));
    final bad = File('${root.path}/no/such/dir/out.llbackup');
    await expectLater(createBackup(dataDir: phoneA, session: s, dataKey: s.dataKey, out: bad), throwsA(anything));
    expect(Directory('${phoneA.path}/.backup-work').existsSync(), isFalse);
    await expectLater(
      createBackup(dataDir: phoneA, session: s, dataKey: Uint8List(32), out: File('${root.path}/z')),
      throwsStateError,
    );
    await s.lock();
  });
}
