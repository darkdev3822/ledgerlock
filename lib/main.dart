import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'security/auto_lock.dart';
import 'security/session.dart';
import 'security/vault.dart';
import 'ui/lock_screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getApplicationSupportDirectory();
  runApp(LedgerLockApp(dataDir: dir));
}

class LedgerLockApp extends StatefulWidget {
  final Directory dataDir;
  const LedgerLockApp({super.key, required this.dataDir});

  @override
  State<LedgerLockApp> createState() => _LedgerLockAppState();
}

class _LedgerLockAppState extends State<LedgerLockApp> {
  late final Vault _vault = Vault(widget.dataDir);
  late final AutoLock _autoLock = AutoLock(onLock: _lock);
  Session? _session;

  @override
  void initState() {
    super.initState();
    _autoLock.attach();
  }

  @override
  void dispose() {
    _autoLock.detach();
    _session?.lock();
    super.dispose();
  }

  Future<void> _open(String password) async {
    final s = await Session.open(widget.dataDir, password, vault: _vault);
    final mins = int.tryParse(await s.db.getSetting('autoLockMinutes') ?? '');
    if (mins != null) _autoLock.timeout = Duration(minutes: mins);
    setState(() => _session = s);
  }

  void _lock() {
    final s = _session;
    if (s == null) return;
    setState(() => _session = null);
    s.lock();
  }

  @override
  Widget build(BuildContext context) {
    final Widget screen = _session != null
        ? UnlockedPlaceholder(onLock: _lock)
        : _vault.exists
            ? UnlockScreen(onSubmit: _open)
            : SetupScreen(onSubmit: _open);
    return MaterialApp(
      title: 'LedgerLock',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF1F6F5C), useMaterial3: true),
      darkTheme: ThemeData(
          colorSchemeSeed: const Color(0xFF1F6F5C), brightness: Brightness.dark, useMaterial3: true),
      home: screen,
      builder: (context, child) => ValueListenableBuilder<bool>(
        valueListenable: _autoLock.coverVisible,
        builder: (context, cover, _) => Stack(children: [
          child!,
          if (cover)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: ColoredBox(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
                  child: const Center(child: Icon(Icons.lock_outline, size: 56)),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
