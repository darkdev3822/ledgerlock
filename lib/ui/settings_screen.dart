// Settings: recovery health, security, appearance, privacy facts.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app_controller.dart';
import '../security/vault.dart';
import 'design/components.dart';
import 'design/theme.dart';
import 'lock_screens.dart';
import 'recovery_screens.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _snack(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appControllerProvider);
    final ll = context.ll;
    final methods = app.slots.where((s) => s != Slot.password).length;
    final healthy = methods >= 2;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xxl),
        children: [
          // ---- recovery health ----
          LLCard(
            color: healthy ? ll.accentSoft : ll.warning.withValues(alpha: 0.12),
            child: Row(
              children: [
                Icon(
                  healthy ? Icons.verified_user_rounded : Icons.shield_outlined,
                  color: healthy ? ll.accent : ll.warning,
                  size: 32,
                ),
                const SizedBox(width: Space.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Recovery health', style: context.text.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        healthy
                            ? '$methods ways back in if you forget your password. You\'re well covered.'
                            : 'Add another way back in, so a forgotten password never locks you out.',
                        style: context.text.bodySmall?.copyWith(color: ll.text),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SectionHeader('Ways back in'),
          LLGroup(
            children: [
              ListTile(
                leading: const Icon(Icons.key_rounded),
                title: const Text('Recovery key'),
                subtitle: Text(app.slots.contains(Slot.recovery) ? 'Saved' : 'Not set up'),
                trailing: TextButton(
                  onPressed: () {
                    final code = RecoveryKey.generate();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => RecoveryKeyScreen(
                          code: code,
                          isRegeneration: true,
                          onConfirmed: () async {
                            await app.replaceRecoveryKey(code);
                            if (ctx.mounted) Navigator.of(ctx).pop();
                          },
                        ),
                      ),
                    );
                  },
                  child: const Text('New key'),
                ),
              ),
              if (app.biometricsAvailable || app.slots.contains(Slot.biometric))
                SwitchListTile(
                  secondary: const Icon(Icons.fingerprint_rounded),
                  title: const Text('Fingerprint reset'),
                  subtitle: const Text('Reset your password with your fingerprint on this phone'),
                  value: app.slots.contains(Slot.biometric),
                  onChanged: (on) async {
                    if (on) {
                      if (!await app.enableBiometric() && context.mounted) {
                        _snack(context, 'Fingerprint reset wasn\'t turned on.');
                      }
                    } else {
                      await app.disableBiometric();
                    }
                  },
                ),
              ListTile(
                leading: const Icon(Icons.quiz_outlined),
                title: const Text('Security questions'),
                subtitle: Text(app.slots.contains(Slot.questions) ? 'On' : 'Optional extra'),
                trailing: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SecurityQuestionsSetupScreen(onSave: app.setSecurityQuestions),
                    ),
                  ),
                  child: Text(app.slots.contains(Slot.questions) ? 'Change' : 'Set up'),
                ),
              ),
              const ListTile(
                leading: Icon(Icons.backup_outlined),
                title: Text('Encrypted backup'),
                subtitle: Text('Protects you if this phone is lost. Coming in M9.'),
                enabled: false,
              ),
            ],
          ),
          const SectionHeader('Security'),
          LLGroup(
            children: [
              ListTile(
                leading: const Icon(Icons.password_rounded),
                title: const Text('Change master password'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _ChangePassword())),
              ),
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: const Text('Auto-lock'),
                subtitle: const Text('After this long in the background'),
                trailing: DropdownButton<int>(
                  value: app.autoLockMinutes,
                  underline: const SizedBox.shrink(),
                  borderRadius: BorderRadius.circular(Radii.input),
                  items: [
                    for (final m in const [1, 5, 15, 30]) DropdownMenuItem(value: m, child: Text('$m min')),
                  ],
                  onChanged: (m) => app.setAutoLockMinutes(m!),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.lock_outline_rounded),
                title: const Text('Lock now'),
                onTap: app.lock,
              ),
            ],
          ),
          const SectionHeader('Reminders'),
          LLGroup(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.event_note_outlined),
                title: const Text('Quarterly tax dates'),
                subtitle: const Text('A week before and the day before each estimated tax due date'),
                value: app.quarterlyReminders,
                onChanged: (v) async {
                  if (!await app.setQuarterlyReminders(v) && context.mounted) _notifDenied(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.fact_check_outlined),
                title: const Text('"Keep me in check" check-ins'),
                subtitle: const Text('A few quick questions to catch anything you forgot'),
                trailing: DropdownButton<String>(
                  value: app.checkInFrequency,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'off', child: Text('Off')),
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                    DropdownMenuItem(value: 'biweekly', child: Text('Every 2 weeks')),
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                  ],
                  onChanged: (v) async {
                    if (v != null && !await app.setCheckInFrequency(v) && context.mounted) {
                      _notifDenied(context);
                    }
                  },
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, Space.sm, 4, 0),
            child: Text(
              'Notifications only ever say things like "Time for a quick check-in": never amounts or names.',
              style: context.text.bodySmall,
            ),
          ),
          const SectionHeader('Appearance'),
          LLCard(
            padding: const EdgeInsets.all(Space.md),
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('System'),
                  icon: Icon(Icons.brightness_auto_outlined),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode_outlined),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode_outlined),
                ),
              ],
              selected: {app.themeMode},
              onSelectionChanged: (s) => app.setThemeMode(s.first),
            ),
          ),
          const SectionHeader('Privacy'),
          LLCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (icon, text) in const [
                  (
                    Icons.wifi_off_rounded,
                    'No internet permission. LedgerLock can\'t send your data anywhere.',
                  ),
                  (
                    Icons.enhanced_encryption_outlined,
                    'Records, receipts and documents are encrypted on this phone.',
                  ),
                  (Icons.visibility_off_outlined, 'No accounts, no analytics, no ads.'),
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, size: 20, color: ll.accent),
                        const SizedBox(width: Space.md),
                        Expanded(child: Text(text, style: context.text.bodyMedium)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Asks for the current password, then a new one.
class _ChangePassword extends ConsumerStatefulWidget {
  const _ChangePassword();
  @override
  ConsumerState<_ChangePassword> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends ConsumerState<_ChangePassword> {
  String? _current;

  @override
  Widget build(BuildContext context) {
    final app = ref.read(appControllerProvider);
    if (_current == null) {
      return UnlockScreen(
        title: 'Change password',
        subtitle: 'First, enter your current master password.',
        buttonLabel: 'Continue',
        onSubmit: (pw) async {
          final dk = await app.vault.unlock(pw); // throws WrongPassword
          dk.fillRange(0, dk.length, 0);
          setState(() => _current = pw);
        },
      );
    }
    return SetupScreen(
      title: 'New master password',
      subtitle: 'Your records stay as they are; only the lock changes.',
      buttonLabel: 'Save new password',
      showRecoveryNote: false,
      onSubmit: (pw) async {
        await app.changePassword(_current!, pw);
        if (!context.mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Master password changed')));
      },
    );
  }
}

void _notifDenied(BuildContext context) => ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(content: Text('Notifications are off for LedgerLock. Turn them on in Android settings.')),
);
