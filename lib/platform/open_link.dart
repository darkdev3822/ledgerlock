// Opens an allowlisted official https link in the user's browser via our own channel (no url_launcher).
import 'package:flutter/services.dart';

import '../tax/guidance.dart';

const _channel = MethodChannel('ledgerlock/files');

/// Returns null on success, or a short message for the user.
Future<String?> openOfficialLink(String url) async {
  if (!isAllowedLink(url)) return 'That link isn\u2019t on the official list.';
  try {
    // Send the parsed, normalised form: what we checked is exactly what the browser gets.
    await _channel.invokeMethod<bool>('openUrl', {'url': Uri.parse(url).toString()});
    return null;
  } on PlatformException catch (e) {
    return e.code == 'no_browser' ? 'No browser is installed.' : 'Couldn\u2019t open the link.';
  } on MissingPluginException {
    return 'Opening links isn\u2019t available here yet.';
  }
}
