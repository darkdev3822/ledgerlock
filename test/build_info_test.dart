import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerlock/app/build_info.dart';

void main() {
  test('appVersion matches pubspec.yaml', () {
    final v = RegExp(r'^version:\s*(\S+)\+\d+$', multiLine: true).firstMatch(File('pubspec.yaml').readAsStringSync());
    expect(v?.group(1), appVersion);
  });
}
