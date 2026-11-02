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
  bool _closed = false;

  EncryptedFileStore(this.dir, this._key) {
    dir.createSync(recursive: true);
  }

  /// Called by Session.lock() BEFORE the key is zeroed. Every later read/write throws, so an operation that was
  /// mid-flight when the app locked can never encrypt with a wiped (all-zero) key (SECURITY.md T18).
  void close() => _closed = true;
  bool get isClosed => _closed;

  void _checkOpen() {
    if (_closed || _key.every((b) => b == 0)) throw StateError('vault is locked');
  }

  File _file(String id) {
    if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(id)) throw ArgumentError('bad id');
    return File('${dir.path}/$id.llf');
  }

  List<int> _aad(String id) => utf8.encode('ledgerlock/v1/file/$id');

  /// Encrypts [bytes] and returns the new file id. Plaintext never touches disk.
  Future<String> put(Uint8List bytes) async {
    _checkOpen();
    final id = LedgerCrypto.randomBytes(16).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final sealed = await LedgerCrypto.encrypt(bytes, _key, aad: _aad(id));
    _checkOpen(); // the lock may have landed during the await
    final tmp = File('${_file(id).path}.tmp');
    await tmp.writeAsBytes([..._magic, ...sealed], flush: true);
    await tmp.rename(_file(id).path);
    return id;
  }

  /// Throws [DecryptionFailed] if the file was tampered with or moved.
  Future<Uint8List> get(String id) async {
    _checkOpen();
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
