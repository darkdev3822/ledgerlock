// Receipts, documents and thumbnails: each file AES-256-GCM encrypted with a
// fresh nonce. The file id is bound as AAD so files can't be swapped on disk.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'crypto.dart';

class EncryptedFileStore {
  static final _magic = ascii.encode('LLF1');
  final Directory dir;
  final Uint8List _key;

  EncryptedFileStore(this.dir, this._key) {
    dir.createSync(recursive: true);
  }

  File _file(String id) {
    if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(id)) throw ArgumentError('bad id');
    return File('${dir.path}/$id.llf');
  }

  List<int> _aad(String id) => utf8.encode('ledgerlock/v1/file/$id');

  /// Encrypts [bytes] and returns the new file id. Plaintext never touches disk.
  Future<String> put(Uint8List bytes) async {
    final id = LedgerCrypto.randomBytes(16).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final sealed = await LedgerCrypto.encrypt(bytes, _key, aad: _aad(id));
    final tmp = File('${_file(id).path}.tmp');
    await tmp.writeAsBytes([..._magic, ...sealed], flush: true);
    await tmp.rename(_file(id).path);
    return id;
  }

  /// Throws [DecryptionFailed] if the file was tampered with or moved.
  Future<Uint8List> get(String id) async {
    final raw = await _file(id).readAsBytes();
    if (raw.length < 4 || !_startsWithMagic(raw)) throw const DecryptionFailed();
    return LedgerCrypto.decrypt(Uint8List.sublistView(raw, 4), _key, aad: _aad(id));
  }

  Future<void> delete(String id) async {
    final f = _file(id);
    if (await f.exists()) await f.delete();
  }

  bool _startsWithMagic(Uint8List raw) {
    for (var i = 0; i < 4; i++) {
      if (raw[i] != _magic[i]) return false;
    }
    return true;
  }
}
