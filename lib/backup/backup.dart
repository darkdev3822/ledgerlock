// Encrypted backups (SPEC §1, M9). A `.llbackup` file is a sealed bundle of data that is ALREADY encrypted:
// the SQLCipher database snapshot, every encrypted receipt/document file (.llf), and the vault header with the
// password / recovery-key / security-question slots. Nothing is decrypted to make a backup, and restoring needs
// exactly the secrets that open the vault. The fingerprint slot is left out (it is tied to the old phone's
// hardware keystore).
//
// Integrity: a manifest (name, size, SHA-256 of every entry) is sealed with AES-GCM under a key derived from the
// data key. Restore verifies every byte against it before touching live data, so a tampered, truncated or
// mixed-up file is rejected instead of half-restored.
//
// Layout: "LLBK" | version(1) | headerLen(u32 BE) | header JSON | entries...
//         entry = nameLen(u16 BE) | name | dataLen(u64 BE) | data
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../data/database.dart' show vaultSchemaVersion;
import '../security/attempt_guard.dart';
import '../security/crypto.dart';
import '../security/session.dart';
import '../security/vault.dart';

const backupMagic = 'LLBK';
const backupVersion = 1;

/// [BackupInvalid.why] for a backup made by a newer app version than this one.
const newerBackup = 'made by a newer version of LedgerLock';
const _maxHeaderBytes = 256 * 1024;
const _maxEntries = 200000;
const _maxEntryBytes = 4 * 1024 * 1024 * 1024; // 4 GB (database or one file)
final _entryName = RegExp(r'^(ledger\.db|files/[0-9a-f]{32}\.llf)$');

/// JSON with object keys sorted at every level, for comparing two maps for equality.
String _canonical(Object? v) {
  Object? sort(Object? x) => x is Map
      ? {for (final k in (x.keys.map((k) => '$k').toList()..sort())) k: sort(x[k])}
      : x is List
      ? [for (final e in x) sort(e)]
      : x;
  return jsonEncode(sort(v));
}

class BackupInvalid implements Exception {
  final String why;
  const BackupInvalid(this.why);
  @override
  String toString() => 'BackupInvalid($why)';
}

Future<Uint8List> _backupKey(Uint8List dataKey) => LedgerCrypto.subkey(dataKey, 'backup');
const _manifestAad = 'ledgerlock/v1/backup-manifest';

Future<String> _sha256File(File f) async {
  final sink = Sha256().newHashSink();
  await for (final chunk in f.openRead()) {
    sink.add(chunk);
  }
  sink.close();
  return base64Encode((await sink.hash()).bytes);
}

/// Writes a backup of [dataDir] (vault.json, ledger.db, files/) to [out]. [session] must be open: the database
/// snapshot is taken with VACUUM INTO (consistent and still encrypted with the same key).
Future<({int files, int bytes})> createBackup({
  required Directory dataDir,
  required Session session,
  required Uint8List dataKey,
  required File out,
  DateTime? now,
}) async {
  if (dataKey.every((b) => b == 0)) throw StateError('vault is locked'); // never seal with a wiped key (cf. T18)
  final work = Directory('${dataDir.path}/.backup-work');
  if (work.existsSync()) work.deleteSync(recursive: true);
  work.createSync(recursive: true);
  try {
    final snap = File('${work.path}/ledger.db');
    final escaped = snap.path.replaceAll("'", "''");
    await session.db.customStatement("VACUUM INTO '$escaped'");

    final entries = <(String, File)>[('ledger.db', snap)];
    final filesDir = Directory('${dataDir.path}/files');
    if (filesDir.existsSync()) {
      for (final f in filesDir.listSync().whereType<File>()) {
        final name = 'files/${f.uri.pathSegments.last}';
        if (_entryName.hasMatch(name)) entries.add((name, f));
      }
    }
    entries.sort((a, b) => a.$1.compareTo(b.$1));

    final manifest = <Map<String, Object>>[
      for (final (name, f) in entries) {'name': name, 'size': f.lengthSync(), 'sha256': await _sha256File(f)},
    ];
    // Vault header without the device-bound fingerprint slot. Sealed INSIDE the manifest too, so restore installs
    // only an authenticated header (M9 review B1: the plain header copy is just for unlocking).
    final vaultJson = jsonDecode(await File('${dataDir.path}/vault.json').readAsString()) as Map<String, dynamic>;
    final slots = Map<String, dynamic>.from((vaultJson['slots'] as Map?) ?? const {})..remove(Slot.biometric.name);
    if (dataKey.every((b) => b == 0)) throw StateError('vault is locked');
    final key = await _backupKey(dataKey);
    final sealed = await LedgerCrypto.encrypt(
      utf8.encode(
        jsonEncode({
          'created': (now ?? DateTime.now()).toIso8601String(),
          'schema': vaultSchemaVersion,
          'entries': manifest,
          'vault': {'v': 2, 'slots': slots},
        }),
      ),
      key,
      aad: utf8.encode(_manifestAad),
    );
    LedgerCrypto.zero(key);

    final header = utf8.encode(
      jsonEncode({
        'v': backupVersion,
        'created': (now ?? DateTime.now()).toIso8601String(),
        'schema': vaultSchemaVersion,
        'vault': {'v': 2, 'slots': slots},
        'manifest': base64Encode(sealed),
      }),
    );

    final sink = out.openWrite();
    var total = 0;
    void u(int bytes, int v) {
      final b = ByteData(bytes);
      if (bytes == 2) b.setUint16(0, v);
      if (bytes == 4) b.setUint32(0, v);
      if (bytes == 8) b.setUint64(0, v);
      sink.add(b.buffer.asUint8List());
    }

    sink.add(ascii.encode(backupMagic));
    sink.add([backupVersion]);
    u(4, header.length);
    sink.add(header);
    for (final (name, f) in entries) {
      final n = utf8.encode(name);
      u(2, n.length);
      sink.add(n);
      u(8, f.lengthSync());
      await sink.addStream(f.openRead());
      total += f.lengthSync();
    }
    await sink.flush();
    await sink.close();
    return (files: entries.length - 1, bytes: total);
  } finally {
    if (work.existsSync()) work.deleteSync(recursive: true);
  }
}

/// Reads a backup's header (no secrets needed). Throws [BackupInvalid] for anything that isn't a LedgerLock
/// backup.
class BackupFile {
  final File file;
  final DateTime created;
  final Map<String, dynamic> vault;
  final Uint8List sealedManifest;
  final int bodyOffset;
  BackupFile._(this.file, this.created, this.vault, this.sealedManifest, this.bodyOffset);

  Set<Slot> get slots => {
    for (final s in Slot.values)
      if ((vault['slots'] as Map).containsKey(s.name)) s,
  };

  static Future<BackupFile> open(File file) async {
    final raf = await file.open();
    try {
      final head = await raf.read(9);
      if (head.length < 9 || ascii.decode(head.sublist(0, 4), allowInvalid: true) != backupMagic) {
        throw const BackupInvalid('not a LedgerLock backup');
      }
      if (head[4] != backupVersion) throw const BackupInvalid(newerBackup);
      final len = ByteData.sublistView(head, 5, 9).getUint32(0);
      if (len <= 0 || len > _maxHeaderBytes) throw const BackupInvalid('damaged header');
      final bytes = await raf.read(len);
      if (bytes.length != len) throw const BackupInvalid('damaged header');
      final j = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final vault = Map<String, dynamic>.from(j['vault'] as Map);
      if (vault['v'] != 2 || vault['slots'] is! Map) throw const BackupInvalid('damaged header');
      final known = {for (final x in Slot.values) x.name};
      if (!(vault['slots'] as Map).keys.every(known.contains)) throw const BackupInvalid('damaged header');
      // Older backups have no schema field (all <= 11). Refuse a newer one before any secret is asked for.
      if ((j['schema'] as int? ?? 0) > vaultSchemaVersion) throw const BackupInvalid(newerBackup);
      return BackupFile._(
        file,
        DateTime.tryParse(j['created'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
        vault,
        base64Decode(j['manifest'] as String),
        9 + len,
      );
    } on BackupInvalid {
      rethrow;
    } catch (_) {
      throw const BackupInvalid('damaged header');
    } finally {
      await raf.close();
    }
  }

  /// A throwaway Vault over this backup's header, for checking a password / recovery key / answers. Uses its own
  /// attempt guard in [staging] so failed guesses at a backup don't lock the live vault.
  Future<Vault> stageVault(Directory staging) async {
    staging.createSync(recursive: true);
    await File('${staging.path}/vault.json').writeAsString(jsonEncode(vault), flush: true);
    return Vault(staging, guard: AttemptGuard(staging, uptime: () => null));
  }

  /// Unpacks every entry into [staging], verifying names, sizes and SHA-256 against the sealed manifest. Nothing
  /// outside [staging] is touched. Throws [BackupInvalid] on any mismatch (wrong secret, tampering, truncation).
  /// Returns the backup's creation time from the authenticated manifest (the header copy is display-only).
  Future<DateTime> extractVerified(Directory staging, Uint8List dataKey) async {
    final key = await _backupKey(dataKey);
    List<dynamic> expected;
    DateTime made;
    Map<String, dynamic> sealedVault;
    int schema;
    try {
      final m = jsonDecode(
        utf8.decode(await LedgerCrypto.decrypt(sealedManifest, key, aad: utf8.encode(_manifestAad))),
      );
      expected = (m as Map)['entries'] as List;
      made = DateTime.parse(m['created'] as String); // authenticated, unlike the header's display copy
      sealedVault = Map<String, dynamic>.from(m['vault'] as Map);
      schema = m['schema'] as int? ?? 0;
    } catch (_) {
      throw const BackupInvalid('this backup does not match that secret, or was changed');
    } finally {
      LedgerCrypto.zero(key);
    }
    // Authenticated copy of the header check: an edited header can't sneak a newer vault past an older app.
    if (schema > vaultSchemaVersion) throw const BackupInvalid(newerBackup);
    if (expected.length > _maxEntries) throw const BackupInvalid('too many entries');
    final want = {for (final e in expected) (e as Map)['name'] as String: e};
    final seen = <String>{};
    final raf = await file.open();
    try {
      await raf.setPosition(bodyOffset);
      final end = await raf.length();
      while (await raf.position() < end) {
        final nl = await raf.read(2);
        if (nl.length != 2) throw const BackupInvalid('truncated');
        final nameLen = ByteData.sublistView(nl).getUint16(0);
        final name = utf8.decode(await raf.read(nameLen), allowMalformed: true);
        if (!_entryName.hasMatch(name) || !want.containsKey(name) || !seen.add(name)) {
          throw const BackupInvalid('unexpected entry');
        }
        final dl = await raf.read(8);
        if (dl.length != 8) throw const BackupInvalid('truncated');
        final size = ByteData.sublistView(dl).getUint64(0);
        if (size < 0 || size > _maxEntryBytes || size != (want[name]!['size'] as int)) {
          throw const BackupInvalid('size mismatch');
        }
        final target = File('${staging.path}/$name');
        target.parent.createSync(recursive: true);
        final out = target.openWrite();
        final hash = Sha256().newHashSink();
        var left = size;
        while (left > 0) {
          final chunk = await raf.read(left > 1 << 20 ? 1 << 20 : left);
          if (chunk.isEmpty) {
            await out.close();
            throw const BackupInvalid('truncated');
          }
          out.add(chunk);
          hash.add(chunk);
          left -= chunk.length;
        }
        await out.close();
        hash.close();
        if (base64Encode((await hash.hash()).bytes) != want[name]!['sha256']) {
          throw const BackupInvalid('content changed');
        }
      }
    } finally {
      await raf.close();
    }
    if (seen.length != want.length) throw const BackupInvalid('missing entries');
    // Install only the authenticated header (replaces the unauthenticated copy used for unlocking).
    final known = {for (final x in Slot.values) x.name};
    final ss = sealedVault['slots'];
    if (sealedVault['v'] != 2 || ss is! Map || !ss.keys.every(known.contains)) {
      throw const BackupInvalid('damaged header');
    }
    // The plain header copy (used to unlock) must match the sealed one: any difference means the file was edited.
    if (_canonical(vault) != _canonical(sealedVault)) throw const BackupInvalid('header changed');
    await File('${staging.path}/vault.json').writeAsString(jsonEncode(sealedVault), flush: true);
    return made;
  }
}

/// Replaces the live vault in [dataDir] with the verified one in [staging]. Only vault.json, ledger.db and files/
/// are swapped; the old ones are kept aside until the new ones are in place, then deleted.
Future<void> installStaged(Directory staging, Directory dataDir) async {
  // Never touch live data unless the staged vault is complete (M9 review B2: an emptied staging dir used to
  // replace, and then delete, the live vault).
  if (!File('${staging.path}/vault.json').existsSync() || !File('${staging.path}/ledger.db').existsSync()) {
    throw const BackupInvalid('incomplete restore');
  }
  // A previous swap that was interrupted must be resolved first, never deleted (B3).
  await recoverInterruptedRestore(dataDir);
  final old = Directory('${dataDir.path}/.restore-old');
  old.createSync(recursive: true);
  for (final n in const ['vault.json', 'ledger.db', 'files']) {
    final p = '${dataDir.path}/$n';
    switch (FileSystemEntity.typeSync(p)) {
      case FileSystemEntityType.directory:
        await Directory(p).rename('${old.path}/$n');
      case FileSystemEntityType.file:
        await File(p).rename('${old.path}/$n');
      default:
    }
  }
  // vault.json goes in LAST: its presence means the new vault is complete (recoverInterruptedRestore relies on it).
  for (final n in const ['ledger.db', 'files', 'vault.json']) {
    final p = '${staging.path}/$n';
    if (FileSystemEntity.isDirectorySync(p)) {
      await Directory(p).rename('${dataDir.path}/$n');
    } else if (File(p).existsSync()) {
      await File(p).rename('${dataDir.path}/$n');
    } else if (n == 'files') {
      Directory('${dataDir.path}/files').createSync();
    }
  }
  final attempts = File('${dataDir.path}/attempts.json'); // fresh attempt counter for the restored vault
  if (attempts.existsSync()) attempts.deleteSync();
  old.deleteSync(recursive: true);
  if (staging.existsSync()) staging.deleteSync(recursive: true);
}

/// Called at startup and before any restore. If a swap was interrupted (app killed), finish it or roll it back:
/// a live vault.json means the new vault was fully installed (it goes in last); otherwise the old vault is put
/// back. The user's data is never deleted here.
Future<void> recoverInterruptedRestore(Directory dataDir) async {
  final old = Directory('${dataDir.path}/.restore-old');
  if (!old.existsSync()) return;
  if (File('${dataDir.path}/vault.json').existsSync()) {
    old.deleteSync(recursive: true); // new vault complete; the old copy is the leftover
    return;
  }
  for (final n in const ['ledger.db', 'files', 'vault.json']) {
    final from = '${old.path}/$n', to = '${dataDir.path}/$n';
    final t = FileSystemEntity.typeSync(from);
    if (t == FileSystemEntityType.notFound) continue;
    switch (FileSystemEntity.typeSync(to)) {
      // Remove the half-installed new copy first.
      case FileSystemEntityType.directory:
        Directory(to).deleteSync(recursive: true);
      case FileSystemEntityType.file:
        File(to).deleteSync();
      default:
    }
    if (t == FileSystemEntityType.directory) {
      await Directory(from).rename(to);
    } else {
      await File(from).rename(to);
    }
  }
  old.deleteSync(recursive: true);
}
