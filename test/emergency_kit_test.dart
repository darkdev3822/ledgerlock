import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerlock/security/emergency_kit.dart';

void main() {
  test('Emergency Kit is a PDF with no secret in it (SECURITY.md T13)', () async {
    final bytes = await buildEmergencyKit();
    expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');
    // buildEmergencyKit takes no arguments, so it cannot embed a key. Keep it that way.
    expect(bytes.length, lessThan(200 * 1024));
    for (final line in [...kitSteps, ...kitWarnings]) {
      expect(RegExp(r'[A-Z0-9]{5}-[A-Z0-9]{5}').hasMatch(line), isFalse);
    }
  });
}
