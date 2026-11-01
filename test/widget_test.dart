import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerlock/security/vault.dart';
import 'package:ledgerlock/ui/lock_screens.dart';

void main() {
  test('password strength', () {
    expect(passwordStrength('short'), 0);
    expect(passwordStrength('abcdefgh'), 1);
    expect(passwordStrength('abcdefghijkl'), 2);
    expect(passwordStrength('Abcdefghij1!'), 3);
    expect(passwordStrength('Correct-Horse-Battery-9'), 4);
  });

  testWidgets('setup requires strong matching password and the no-recovery acknowledgement', (t) async {
    String? submitted;
    await t.pumpWidget(MaterialApp(home: SetupScreen(onSubmit: (p) async => submitted = p)));
    final button = find.widgetWithText(FilledButton, 'Create encrypted vault');
    bool enabled() => t.widget<FilledButton>(button).onPressed != null;

    await t.enterText(find.byKey(const Key('pw')), 'Correct-Horse-9');
    await t.enterText(find.byKey(const Key('confirm')), 'Correct-Horse-9');
    await t.pump();
    expect(enabled(), isFalse, reason: 'must acknowledge no recovery');
    await t.ensureVisible(find.byKey(const Key('understood')));
    await t.tap(find.byKey(const Key('understood')));
    await t.pump();
    expect(enabled(), isTrue);
    await t.enterText(find.byKey(const Key('confirm')), 'mismatch');
    await t.pump();
    expect(enabled(), isFalse);
    expect(find.text("Passwords don't match"), findsOneWidget);
    await t.enterText(find.byKey(const Key('confirm')), 'Correct-Horse-9');
    await t.pump();
    await t.ensureVisible(button);
    await t.pump();
    await t.tap(button);
    await t.pump();
    expect(submitted, 'Correct-Horse-9');
  });

  testWidgets('unlock shows an error on a wrong password', (t) async {
    await t.pumpWidget(MaterialApp(home: UnlockScreen(onSubmit: (_) async => throw const WrongPassword())));
    await t.enterText(find.byKey(const Key('unlock')), 'nope');
    await t.tap(find.text('Unlock'));
    await t.pump();
    expect(find.text('Wrong password'), findsOneWidget);
  });
}
