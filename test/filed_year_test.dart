import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerlock/ui/shell/app_shell.dart';

void main() {
  testWidgets('year switcher shows Filed for a filed year, and says so to screen readers', (t) async {
    Widget app(Set<int> filed) => MaterialApp(
      home: Scaffold(body: YearSwitcher(year: 2025, onChanged: (_) {}, filed: filed)),
    );
    await t.pumpWidget(app(const {}));
    expect(find.text('Filed'), findsNothing);
    await t.pumpWidget(app(const {2025}));
    expect(find.text('Filed'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Tax year 2025, filed')), findsOneWidget);
  });
}
