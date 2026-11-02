// Encrypted backups (M9): restore flow and the Home reminder. Backing up lives in Settings (AppController.backupNow).
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../app/app_controller.dart';
import '../backup/backup.dart';
import '../security/attempt_guard.dart';
import '../security/vault.dart';
import 'design/components.dart';
import 'design/theme.dart';

/// Restore from a `.llbackup`. Works on a fresh install (from the welcome screen) and from Settings, where it
/// replaces the current records after a clear warning.
class RestoreScreen extends ConsumerStatefulWidget {
  /// True when a vault already exists on this phone (its records will be replaced).
  final bool replacing;
  const RestoreScreen({super.key, this.replacing = false});
  @override
  ConsumerState<RestoreScreen> createState() => _RestoreScreenState();
}

enum _Method { password, recoveryKey }

class _RestoreScreenState extends ConsumerState<RestoreScreen> {
  BackupFile? _backup;
  _Method _method = _Method.password;
  final _secret = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _secret.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    setState(() => _error = null);
    try {
      final b = await ref.read(appControllerProvider).pickBackup();
      if (b != null && mounted) setState(() => _backup = b);
    } on BackupInvalid catch (e) {
      setState(() => _error = 'That isn’t a LedgerLock backup (${e.why}).');
    } catch (_) {
      setState(() => _error = 'Couldn’t read that file.');
    }
  }

  Future<void> _restore() async {
    final app = ref.read(appControllerProvider);
    final b = _backup!;
    setState(() {
      _busy = true;
      _error = null;
    });
    Uint8List? dk;
    try {
      final v = await b.stageVault(app.restoreStaging);
      dk = _method == _Method.password ? await v.unlock(_secret.text) : await v.recoverWithKey(_secret.text);
      final key = dk;
      dk = null; // finishRestore owns it now (wipes it on failure)
      await app.finishRestore(b, key);
      // Stage changed: main.dart pops back to the restored, unlocked app.
    } on WrongPassword {
      _fail('That password doesn’t open this backup. It needs the password you had when it was made.');
    } on RecoveryFailed {
      _fail('That recovery key doesn’t open this backup. Check each character.');
    } on TooManyAttempts catch (e) {
      _fail('Too many tries. Wait ${e.wait.inMinutes + 1} min.');
    } on BackupInvalid {
      _fail('This backup was changed or is incomplete, so nothing was restored. Your current data is untouched.');
    } catch (_) {
      _fail('Restore failed. Nothing was changed.');
    }
  }

  void _fail(String m) {
    if (mounted) {
      setState(() {
        _busy = false;
        _error = m;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ll = context.ll;
    final b = _backup;
    return PopScope(
      canPop: !_busy, // no leaving while every file is being checked (M9 review B2)
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) ref.read(appControllerProvider).cancelRestore();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Restore from a backup')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xxl),
          children: [
            if (widget.replacing)
              Container(
                padding: const EdgeInsets.all(Space.md),
                margin: const EdgeInsets.only(bottom: Space.lg),
                decoration: BoxDecoration(
                  color: ll.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(Radii.input),
                ),
                child: Text(
                  'Restoring replaces everything on this phone with the backup: records, receipts and settings. '
                  'Back up first if you might want today’s data.',
                  style: context.text.bodyMedium,
                ),
              ),
            if (b == null) ...[
              Text(
                'Pick a .llbackup file you saved earlier. It stays encrypted the whole way; only your password or '
                'recovery key can open it.',
                style: context.text.bodyMedium,
              ),
              const SizedBox(height: Space.lg),
              FilledButton.icon(
                onPressed: _pick,
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text('Choose a backup file'),
              ),
            ] else ...[
              LLCard(
                child: Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, color: ll.accent),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Text(
                        'Backup from ${DateFormat.yMMMd().add_jm().format(b.created.toLocal())}',
                        style: context.text.titleSmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.lg),
              LLSegmented<_Method>(
                options: [
                  (_Method.password, 'Password'),
                  if (b.slots.contains(Slot.recovery)) (_Method.recoveryKey, 'Recovery key'),
                ],
                value: _method,
                onChanged: (m) => setState(() {
                  _method = m;
                  _secret.clear();
                }),
              ),
              const SizedBox(height: Space.md),
              TextField(
                controller: _secret,
                onChanged: (_) => setState(() {}),
                obscureText: _method == _Method.password,
                enableIMEPersonalizedLearning: false,
                enableSuggestions: false,
                autocorrect: false,
                textCapitalization: _method == _Method.password
                    ? TextCapitalization.none
                    : TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: _method == _Method.password ? 'Password used when the backup was made' : 'Recovery key',
                  hintText: _method == _Method.password ? null : 'XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX',
                ),
              ),
              const SizedBox(height: Space.lg),
              FilledButton(
                onPressed: _busy || _secret.text.isEmpty ? null : _restore,
                child: Text(_busy ? 'Checking every file…' : 'Restore'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: Space.md),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Home reminder when there is data and no backup in 30 days (SPEC §1). Quiet: one line and one button.
class BackupNudge extends ConsumerWidget {
  final bool hasData;
  const BackupNudge({super.key, required this.hasData});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appControllerProvider);
    final today = ref.watch(todayProvider);
    final last = app.lastBackup;
    if (!hasData || (last != null && today.difference(last).inDays < 30)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: LLCard(
        child: Row(
          children: [
            Icon(Icons.save_outlined, color: context.ll.warning),
            const SizedBox(width: Space.md),
            Expanded(
              child: Text(
                last == null
                    ? 'No backup yet. If this phone is lost, a backup is the only way back.'
                    : 'Last backup ${DateFormat.MMMd().format(last)}. Time for a fresh one.',
                style: context.text.bodyMedium,
              ),
            ),
            TextButton(onPressed: () => runBackup(context, app), child: const Text('Back up')),
          ],
        ),
      ),
    );
  }
}

/// Shared "Back up now" action with feedback.
Future<void> runBackup(BuildContext context, AppController app) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    if (await app.backupNow()) {
      showSuccess(messenger, 'Backup saved. Keep it somewhere other than this phone.');
    }
  } catch (_) {
    messenger?.showSnackBar(const SnackBar(content: Text('Backup failed. Nothing was saved.')));
  }
}
