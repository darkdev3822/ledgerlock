// Recovery flows (SPEC §1 "Account recovery"). Functional; visual design comes in M2.
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../security/attempt_guard.dart';
import '../security/biometric_reset.dart';
import '../security/crypto.dart';
import '../security/vault.dart';
import 'lock_screens.dart';

const presetQuestions = [
  'What was the name of your first pet?',
  'What street did you live on in third grade?',
  'What was the make of your first car?',
  'What is your oldest cousin\'s first name?',
  'In what city did your parents meet?',
  'What was the name of your favourite teacher?',
  'What was the first concert you went to?',
  'What was your childhood nickname?',
];

// ---------------- setup: recovery key ----------------

/// Shows the new recovery key once, then asks the user to re-type its last two groups.
class RecoveryKeyScreen extends StatefulWidget {
  final String code;
  final VoidCallback onConfirmed;
  final bool isRegeneration;
  const RecoveryKeyScreen({
    super.key,
    required this.code,
    required this.onConfirmed,
    this.isRegeneration = false,
  });
  @override
  State<RecoveryKeyScreen> createState() => _RecoveryKeyScreenState();
}

class _RecoveryKeyScreenState extends State<RecoveryKeyScreen> {
  bool _confirming = false;
  final _check = TextEditingController();
  String? _error;

  String get _tail => widget.code.split('-').skip(4).join('-');

  @override
  void dispose() {
    _check.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    if (!_confirming) {
      return LockShell(
        title: 'Your recovery key',
        subtitle:
            'If you ever forget your password, this key gets you back in. '
            'Write it down on paper and keep it somewhere safe, like with your tax papers.',
        children: [
          Card(
            color: cs.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final g in widget.code.split('-'))
                    Text(g, style: t.headlineSmall?.copyWith(fontFamily: 'monospace', letterSpacing: 2)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.isRegeneration ? 'Your old recovery key no longer works.' : 'Don\'t screenshot it or store it in a notes app: anyone with this key can open your vault.',
            style: t.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => setState(() => _confirming = true),
            child: const Text('I\'ve written it down'),
          ),
        ],
      );
    }
    return LockShell(
      title: 'Check your copy',
      subtitle: 'Type the last two groups of your recovery key.',
      children: [
        TextField(
          enableIMEPersonalizedLearning: false,
          enableSuggestions: false,
          autocorrect: false,
          key: const Key('rkCheck'),
          controller: _check,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            hintText: 'XXXXX-XXXXX',
            border: const OutlineInputBorder(),
            errorText: _error,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () {
            if (RecoveryKey.normalize(_check.text) == RecoveryKey.normalize(_tail)) {
              widget.onConfirmed();
            } else {
              setState(() => _error = 'That doesn\'t match. Check what you wrote down.');
            }
          },
          child: const Text('Confirm'),
        ),
        TextButton(
          onPressed: () => setState(() {
            _confirming = false;
            _error = null;
            _check.clear();
          }),
          child: const Text('Show the key again'),
        ),
      ],
    );
  }
}

// ---------------- setup: biometric offer ----------------

class BiometricOfferScreen extends StatelessWidget {
  final Future<void> Function() onEnable;
  final VoidCallback onSkip;
  const BiometricOfferScreen({super.key, required this.onEnable, required this.onSkip});

  @override
  Widget build(BuildContext context) => LockShell(
    icon: Icons.fingerprint,
    title: 'Turn on fingerprint reset?',
    subtitle:
        'If you forget your password, you can reset it with your fingerprint or face on this phone. '
        'It\'s a second way back in, alongside your recovery key.',
    children: [
      FilledButton(onPressed: onEnable, child: const Text('Turn on')),
      TextButton(onPressed: onSkip, child: const Text('Not now')),
    ],
  );
}

// ---------------- setup: security questions ----------------

class SecurityQuestionsSetupScreen extends StatefulWidget {
  final Future<void> Function(List<String> questions, List<String> answers) onSave;
  const SecurityQuestionsSetupScreen({super.key, required this.onSave});
  @override
  State<SecurityQuestionsSetupScreen> createState() => _SecurityQuestionsSetupScreenState();
}

class _SecurityQuestionsSetupScreenState extends State<SecurityQuestionsSetupScreen> {
  final _questions = List<String>.of(presetQuestions.take(3));
  final _answers = List.generate(3, (_) => TextEditingController());
  bool _busy = false;

  @override
  void dispose() {
    for (final c in _answers) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _valid =>
      _questions.toSet().length == 3 && _answers.every((c) => normalizeAnswer(c.text).length >= 2);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Security questions')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Card(
          color: Theme.of(context).colorScheme.tertiaryContainer,
          child: const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Pick answers nobody could look up'),
            subtitle: Text(
              'Avoid anything on social media. You\'ll need all three answers. '
              'Capital letters and punctuation don\'t matter.',
            ),
          ),
        ),
        for (var i = 0; i < 3; i++) ...[
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            key: Key('q$i'),
            initialValue: _questions[i],
            isExpanded: true,
            decoration: InputDecoration(labelText: 'Question ${i + 1}', border: const OutlineInputBorder()),
            items: [for (final q in presetQuestions) DropdownMenuItem(value: q, child: Text(q))],
            onChanged: (v) => setState(() => _questions[i] = v!),
          ),
          const SizedBox(height: 8),
          TextField(
            enableIMEPersonalizedLearning: false,
            enableSuggestions: false,
            autocorrect: false,
            key: Key('a$i'),
            controller: _answers[i],
            decoration: const InputDecoration(labelText: 'Answer', border: OutlineInputBorder()),
            onChanged: (_) => setState(() {}),
          ),
        ],
        if (_questions.toSet().length < 3)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Pick three different questions.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _valid && !_busy
              ? () async {
                  setState(() => _busy = true);
                  await widget.onSave(_questions, [for (final c in _answers) c.text]);
                  if (context.mounted) Navigator.of(context).pop();
                }
              : null,
          child: _busy ? const BusyDot() : const Text('Save questions'),
        ),
      ],
    ),
  );
}

// ---------------- forgot password ----------------

/// Lets the user pick any configured recovery method; on success returns the data key.
class ForgotPasswordScreen extends StatefulWidget {
  final Vault vault;
  final BiometricSecretStore biometrics;
  final Future<void> Function(Uint8List dataKey) onRecovered;
  const ForgotPasswordScreen({
    super.key,
    required this.vault,
    required this.biometrics,
    required this.onRecovered,
  });
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  Set<Slot>? _slots;
  String? _message;

  @override
  void initState() {
    super.initState();
    widget.vault.enabledSlots().then((s) => mounted ? setState(() => _slots = s) : null);
  }

  Future<void> _biometric() async {
    try {
      final secret = await widget.biometrics.read();
      if (secret == null) return; // cancelled
      final dk = await widget.vault.recoverWithBiometricSecret(secret);
      LedgerCrypto.zero(secret);
      await _done(dk);
    } catch (_) {
      setState(
        () => _message =
            'Fingerprint reset stopped working on this phone (for example, because '
            'fingerprints were changed). Use your recovery key instead.',
      );
    }
  }

  Future<void> _done(Uint8List dk) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SetupScreen(
          title: 'Choose a new password',
          subtitle: 'You\'re verified. Your records are safe; pick a new master password.',
          buttonLabel: 'Save new password',
          showRecoveryNote: false,
          onSubmit: (pw) async {
            await widget.vault.setPassword(dk, pw);
            await widget.onRecovered(dk);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _slots;
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot password')),
      body: s == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(8, 0, 8, 16),
                  child: Text('Choose a way to prove it\'s you. Your data stays encrypted on this phone.'),
                ),
                if (_message != null)
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(padding: const EdgeInsets.all(16), child: Text(_message!)),
                  ),
                if (s.contains(Slot.biometric))
                  _Method(
                    Icons.fingerprint,
                    'Use fingerprint or face',
                    'Quickest, on this phone',
                    _biometric,
                  ),
                if (s.contains(Slot.recovery))
                  _Method(Icons.key, 'Enter recovery key', 'The 30-character key you wrote down', () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _RecoveryKeyEntry(vault: widget.vault, onRecovered: _done),
                      ),
                    );
                  }),
                if (s.contains(Slot.questions))
                  _Method(
                    Icons.quiz_outlined,
                    'Answer security questions',
                    'All three answers needed',
                    () async {
                      final qs = await widget.vault.securityQuestions();
                      if (!context.mounted) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              _QuestionsEntry(vault: widget.vault, questions: qs, onRecovered: _done),
                        ),
                      );
                    },
                  ),
                if (!s.contains(Slot.recovery) && !s.contains(Slot.biometric) && !s.contains(Slot.questions))
                  const ListTile(
                    title: Text('No recovery methods are set up. Restore from an encrypted backup instead.'),
                  ),
              ],
            ),
    );
  }
}

class _Method extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const _Method(this.icon, this.title, this.subtitle, this.onTap);
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

class _RecoveryKeyEntry extends StatefulWidget {
  final Vault vault;
  final Future<void> Function(Uint8List) onRecovered;
  const _RecoveryKeyEntry({required this.vault, required this.onRecovered});
  @override
  State<_RecoveryKeyEntry> createState() => _RecoveryKeyEntryState();
}

class _RecoveryKeyEntryState extends State<_RecoveryKeyEntry> {
  final _c = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final dk = await widget.vault.recoverWithKey(_c.text);
      await widget.onRecovered(dk);
    } on RecoveryFailed {
      if (mounted) setState(() => _error = 'That recovery key didn\'t work. Check each character.');
    } on TooManyAttempts catch (e) {
      if (mounted) setState(() => _error = lockoutMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Recovery key')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        TextField(
          enableIMEPersonalizedLearning: false,
          enableSuggestions: false,
          autocorrect: false,
          key: const Key('rkEntry'),
          controller: _c,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: 'Recovery key',
            hintText: 'XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX',
            helperText: 'Dashes and spaces are optional. O/0 and I/1 are treated the same.',
            border: const OutlineInputBorder(),
            errorText: _error,
          ),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy ? const BusyDot() : const Text('Continue'),
        ),
      ],
    ),
  );
}

class _QuestionsEntry extends StatefulWidget {
  final Vault vault;
  final List<String> questions;
  final Future<void> Function(Uint8List) onRecovered;
  const _QuestionsEntry({required this.vault, required this.questions, required this.onRecovered});
  @override
  State<_QuestionsEntry> createState() => _QuestionsEntryState();
}

class _QuestionsEntryState extends State<_QuestionsEntry> {
  late final _c = List.generate(widget.questions.length, (_) => TextEditingController());
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in _c) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final dk = await widget.vault.recoverWithAnswers([for (final c in _c) c.text]);
      await widget.onRecovered(dk);
    } on RecoveryFailed {
      if (mounted) setState(() => _error = 'At least one answer doesn\'t match.');
    } on TooManyAttempts catch (e) {
      if (mounted) setState(() => _error = lockoutMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Security questions')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        for (var i = 0; i < widget.questions.length; i++) ...[
          Text(widget.questions[i], style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            enableIMEPersonalizedLearning: false,
            enableSuggestions: false,
            autocorrect: false,
            controller: _c[i],
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 20),
        ],
        if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy ? const BusyDot() : const Text('Continue'),
        ),
      ],
    ),
  );
}
