// Settings: recovery health, security, appearance, privacy facts.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../app/app_controller.dart';
import '../app/build_info.dart';
import '../data/business_types.dart';
import '../security/vault.dart';
import 'backup_screens.dart';
import 'design/brand.dart';
import 'design/components.dart';
import 'design/theme.dart';
import 'ledger/budgets_screen.dart';
import 'ledger/businesses_screen.dart';
import 'ledger/categories_screen.dart';
import 'ledger/import_screen.dart';
import 'ledger/recurring_screen.dart';
import 'onboarding_screens.dart';
import 'lock_screens.dart';
import 'recovery_screens.dart';
import 'taxes/tools.dart';

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
                    MaterialPageRoute(builder: (_) => SecurityQuestionsSetupScreen(onSave: app.setSecurityQuestions)),
                  ),
                  child: Text(app.slots.contains(Slot.questions) ? 'Change' : 'Set up'),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.backup_outlined),
                title: const Text('Back up now'),
                subtitle: Text(
                  app.lastBackup == null
                      ? 'Never. A backup is the only way back if this phone is lost.'
                      : 'Last: ${DateFormat.yMMMd().format(app.lastBackup!)}. Saved where you choose, still encrypted.',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => runBackup(context, app),
              ),
              ListTile(
                leading: const Icon(Icons.settings_backup_restore_rounded),
                title: const Text('Restore from a backup'),
                subtitle: const Text('Replaces the records on this phone'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RestoreScreen(replacing: true))),
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
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _ChangePassword())),
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
              ListTile(leading: const Icon(Icons.lock_outline_rounded), title: const Text('Lock now'), onTap: app.lock),
            ],
          ),
          const SectionHeader('Records'),
          LLGroup(
            children: [
              ListTile(
                leading: const Icon(Icons.work_outline_rounded),
                title: const Text('Business type'),
                subtitle: Text(
                  app.businessTypes.isEmpty
                      ? 'Not set: categories in the usual order'
                      : [for (final t in app.businessTypes) businessTypes[t]?.$1 ?? t].join(', '),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (c) => BusinessTypeScreen(
                      settings: true,
                      initial: app.businessTypes,
                      onDone: (t) async {
                        await app.setBusinessTypes(t);
                        if (c.mounted) Navigator.of(c).pop();
                      },
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.auto_fix_high_outlined),
                title: const Text('Smart rules'),
                subtitle: const Text('Pick categories automatically by payee'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RulesScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.storefront_outlined),
                title: const Text('Businesses'),
                subtitle: const Text('Separate books for each side business'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BusinessesScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.label_outline_rounded),
                title: const Text('Your categories'),
                subtitle: const Text('Your own names, counted as a standard category'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CategoriesScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Budgets & goal'),
                subtitle: const Text('Monthly limits per category, a yearly income goal'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BudgetsScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.repeat_rounded),
                title: const Text('Repeating records'),
                subtitle: const Text('Subscriptions, rent share, regular clients'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RecurringScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.upload_file_rounded),
                title: const Text('Import from a CSV file'),
                subtitle: const Text('Bank, PayPal, Etsy and other exports'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ImportScreen())),
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
              // MergeSemantics: TalkBack reads the row as one button including the current value ("Weekly").
              MergeSemantics(
                child: ListTile(
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
                ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_outlined)),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_outlined)),
              ],
              selected: {app.themeMode},
              onSelectionChanged: (s) => app.setThemeMode(s.first),
            ),
          ),
          const SectionHeader('Privacy'),
          LLGroup(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.screenshot_monitor_outlined),
                title: const Text('Allow screenshots'),
                subtitle: const Text(
                  'Off keeps amounts and receipts out of screenshots, screen recordings and the app switcher. '
                  'Always off while locked.',
                ),
                value: app.allowScreenshots,
                onChanged: app.setAllowScreenshots,
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          LLCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (icon, text) in const [
                  (Icons.wifi_off_rounded, 'No internet permission. LedgerLock can\'t send your data anywhere.'),
                  (Icons.enhanced_encryption_outlined, 'Records, receipts and documents are encrypted on this phone.'),
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
          const SectionHeader('About'),
          LLGroup(
            children: [
              ListTile(
                leading: const BrandMark(size: 36),
                title: const Text('Free and open source'),
                subtitle: const Text(
                  'No paid tier, no ads, nothing locked. Licensed under GPL-3.0, so anyone can '
                  'check what this app does.',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: Text('Version $appVersion'),
                subtitle: isBeta
                    ? const Text('Beta: some tax figures are still waiting on the IRS (see the Taxes tab).')
                    : null,
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Open-source licences'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () =>
                    showLicensePage(context: context, applicationName: 'LedgerLock', applicationVersion: appVersion),
              ),
            ],
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
        // Old backups still open with the old password (same data key; M9 review B4 / SECURITY A1).
        if (app.lastBackup != null) {
          await showDialog<void>(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('Make a fresh backup'),
              content: const Text(
                'Your password is changed on this phone. Backups you made earlier still open with the OLD password. '
                'Save a new backup now and delete the old backup files, especially if the old password may be known '
                'to someone else.',
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c), child: const Text('Later')),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(c);
                    runBackup(context, app);
                  },
                  child: const Text('Back up now'),
                ),
              ],
            ),
          );
        }
        if (!context.mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger.showSnackBar(const SnackBar(content: Text('Master password changed')));
      },
    );
  }
}

void _notifDenied(BuildContext context) => ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(content: Text('Notifications are off for LedgerLock. Turn them on in Android settings.')),
);
