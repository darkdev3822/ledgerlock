// Functional M1 lock screens. Visual design comes in M2.
import 'package:flutter/material.dart';

import '../security/vault.dart';

/// 0..4 heuristic strength score (length + character variety).
int passwordStrength(String pw) {
  if (pw.length < 8) return 0;
  var variety = 0;
  for (final r in [RegExp('[a-z]'), RegExp('[A-Z]'), RegExp(r'\d'), RegExp(r'[^a-zA-Z\d]')]) {
    if (r.hasMatch(pw)) variety++;
  }
  var score = (pw.length >= 12 ? 2 : 1) + (variety >= 3 ? 1 : 0) + (pw.length >= 16 ? 1 : 0);
  return score.clamp(1, 4);
}

const _strengthLabels = ['Too short', 'Weak', 'Fair', 'Good', 'Strong'];

class LockShell extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;
  const LockShell({
    super.key,
    this.icon = Icons.lock_rounded,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(title, style: t.headlineMedium, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(subtitle, style: t.bodyMedium, textAlign: TextAlign.center),
                  const SizedBox(height: 32),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SetupScreen extends StatefulWidget {
  final Future<void> Function(String password) onSubmit;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final bool showRecoveryNote;
  const SetupScreen({
    super.key,
    required this.onSubmit,
    this.title = 'Create your master password',
    this.subtitle = 'Everything stays on this phone, encrypted with this password.',
    this.buttonLabel = 'Create encrypted vault',
    this.showRecoveryNote = true,
  });
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _pw = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _pw.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final score = passwordStrength(_pw.text);
    final cs = Theme.of(context).colorScheme;
    final ok = score >= 2 && _pw.text == _confirm.text && !_busy;
    return LockShell(
      title: widget.title,
      subtitle: widget.subtitle,
      children: [
        TextField(
          key: const Key('pw'),
          controller: _pw,
          obscureText: true,
          autofillHints: const [AutofillHints.newPassword],
          decoration: const InputDecoration(labelText: 'Master password', border: OutlineInputBorder()),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: score / 4,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
          color: [cs.error, cs.error, Colors.orange, cs.primary, cs.primary][score],
        ),
        const SizedBox(height: 4),
        Text(_strengthLabels[score], style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 16),
        TextField(
          key: const Key('confirm'),
          controller: _confirm,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Confirm password',
            border: const OutlineInputBorder(),
            errorText: _confirm.text.isNotEmpty && _confirm.text != _pw.text ? "Passwords don't match" : null,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        if (widget.showRecoveryNote)
          Card(
            color: cs.secondaryContainer,
            child: const ListTile(
              leading: Icon(Icons.health_and_safety_outlined),
              title: Text('You can always get back in'),
              subtitle: Text(
                'Next you\'ll save a recovery key and can turn on fingerprint reset, so a '
                'forgotten password never means lost records.',
              ),
            ),
          ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: ok
              ? () async {
                  setState(() => _busy = true);
                  try {
                    await widget.onSubmit(_pw.text);
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                }
              : null,
          child: _busy ? const BusyDot() : Text(widget.buttonLabel),
        ),
      ],
    );
  }
}

class UnlockScreen extends StatefulWidget {
  final Future<void> Function(String password) onSubmit;
  final VoidCallback? onForgot;
  const UnlockScreen({super.key, required this.onSubmit, this.onForgot});
  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final _pw = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _pw.text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_pw.text);
    } on WrongPassword {
      if (mounted) setState(() => _error = 'Wrong password');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => LockShell(
    title: 'LedgerLock',
    subtitle: 'Enter your master password to unlock.',
    children: [
      TextField(
        key: const Key('unlock'),
        controller: _pw,
        obscureText: true,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Master password',
          border: const OutlineInputBorder(),
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      const SizedBox(height: 24),
      FilledButton(onPressed: _busy ? null : _submit, child: _busy ? const BusyDot() : const Text('Unlock')),
      if (widget.onForgot != null)
        TextButton(onPressed: widget.onForgot, child: const Text('Forgot password?')),
    ],
  );
}

class UnlockedPlaceholder extends StatelessWidget {
  final VoidCallback onLock;
  final Widget? recoveryPanel;
  const UnlockedPlaceholder({super.key, required this.onLock, this.recoveryPanel});

  @override
  Widget build(BuildContext context) => LockShell(
    title: 'Vault unlocked',
    subtitle: 'Encrypted database and file store are open. The ledger arrives in M3.',
    children: [
      ?recoveryPanel,
      const SizedBox(height: 16),
      OutlinedButton.icon(onPressed: onLock, icon: const Icon(Icons.lock), label: const Text('Lock now')),
    ],
  );
}

class BusyDot extends StatelessWidget {
  const BusyDot({super.key});
  @override
  Widget build(BuildContext context) =>
      const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2));
}
