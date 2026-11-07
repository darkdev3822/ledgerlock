// Launch actions from outside the app (SECURITY.md T44): home-screen shortcuts, the Quick Settings tile and files
// shared from other apps ("Share > LedgerLock"). Android keeps one pending action in memory (LaunchInbox.kt); this
// side takes it when the app is ready. Nothing here touches disk: a shared file only enters the (encrypted) vault
// after the user picks what to do with it.
import 'dart:convert';

import 'package:flutter/services.dart';

sealed class LaunchAction {
  const LaunchAction();
}

/// A shortcut or the tile: one of [ShortcutAction.kinds].
class ShortcutAction extends LaunchAction {
  static const kinds = {'expense', 'income', 'scan', 'trip'};
  final String kind;
  const ShortcutAction(this.kind);
}

/// A file shared from another app, checked by its content (not the sender's claimed type).
class SharedFile extends LaunchAction {
  final String name, mime;
  final Uint8List bytes;
  const SharedFile(this.name, this.mime, this.bytes);
  bool get isImage => mime.startsWith('image/');
}

/// A share that can't be used; [why] is shown to the user.
class ShareFailed extends LaunchAction {
  final String why;
  const ShareFailed(this.why);
}

const maxSharedBytes = 30 * 1024 * 1024;

/// What the file really is, from its first bytes; null if it isn't a receipt type the app keeps.
String? sniffReceiptMime(Uint8List b) {
  bool at(int o, List<int> m) {
    if (b.length < o + m.length) return false;
    for (var i = 0; i < m.length; i++) {
      if (b[o + i] != m[i]) return false;
    }
    return true;
  }

  if (at(0, const [0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (at(0, const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) return 'image/png';
  if (at(0, ascii.encode('RIFF')) && at(8, ascii.encode('WEBP'))) return 'image/webp';
  if (at(0, ascii.encode('%PDF-'))) return 'application/pdf';
  if (at(4, ascii.encode('ftyp')) && b.length >= 12) {
    final brand = ascii.decode(b.sublist(8, 12), allowInvalid: true);
    if (const {'heic', 'heix', 'heim', 'heis', 'mif1', 'msf1'}.contains(brand)) return 'image/heic';
  }
  return null;
}

String _ext(String mime) => switch (mime) {
  'image/jpeg' => 'jpg',
  'image/png' => 'png',
  'image/webp' => 'webp',
  'image/heic' => 'heic',
  _ => 'pdf',
};

/// Validates what Android handed over. Anything unexpected becomes null or [ShareFailed], never an exception.
LaunchAction? parseLaunch(Object? raw) {
  if (raw is! Map) return null;
  final kind = raw['kind'];
  if (kind is String && ShortcutAction.kinds.contains(kind)) return ShortcutAction(kind);
  if (kind == 'share_error') {
    return ShareFailed(switch (raw['why']) {
      'too_large' => 'That file is over 30 MB.',
      'unsupported' => 'LedgerLock can only take a photo or a PDF.',
      _ => 'Couldn’t read the shared file.',
    });
  }
  if (kind != 'share') return null;
  final bytes = raw['bytes'];
  if (bytes is! Uint8List || bytes.isEmpty) return const ShareFailed('Couldn’t read the shared file.');
  if (bytes.length > maxSharedBytes) return const ShareFailed('That file is over 30 MB.');
  final mime = sniffReceiptMime(bytes);
  if (mime == null) return const ShareFailed('LedgerLock can only take a photo or a PDF.');
  var name = raw['name'] is String ? (raw['name'] as String).trim() : '';
  name = name.replaceAll(RegExp(r'[\u0000-\u001F\u007F\u200E\u200F\u202A-\u202E\u2066-\u2069]'), '');
  if (name.length > 120) name = name.substring(0, 120);
  if (name.isEmpty) name = 'Shared receipt.${_ext(mime)}';
  return SharedFile(name, mime, bytes);
}

/// Where launch actions come from; a fake in tests.
abstract class LaunchSource {
  Future<LaunchAction?> take();

  /// [onReady] runs when Android says a new action is waiting (app already running).
  void listen(void Function() onReady);
}

class ChannelLaunchSource implements LaunchSource {
  static const _ch = MethodChannel('ledgerlock/launch');

  @override
  Future<LaunchAction?> take() async {
    try {
      return parseLaunch(await _ch.invokeMethod<Object?>('take'));
    } on MissingPluginException {
      return null; // tests / platforms without the channel
    } on PlatformException {
      return null;
    }
  }

  @override
  void listen(void Function() onReady) => _ch.setMethodCallHandler((call) async {
    if (call.method == 'ready') onReady();
  });
}
