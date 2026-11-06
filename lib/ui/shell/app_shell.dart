// App shell (SPEC §5): year switcher in the top bar, bottom bar
// Home · Records · [Scan] · Vault · Taxes with a raised centre Scan button.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../data/tax_rules.dart';
import '../design/components.dart';
import '../design/theme.dart';
import '../settings_screen.dart';
import '../ledger/entry_screen.dart';
import '../search/search_screen.dart';
import '../vault/capture_screen.dart';
import '../vault/vault_screens.dart';
import 'tabs.dart';

class AppShell extends ConsumerStatefulWidget {
  final int initialTab;
  const AppShell({super.key, this.initialTab = 0});
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  late int _tab = widget.initialTab;

  static const _titles = ['Home', 'Records', 'Vault', 'Taxes'];

  @override
  void initState() {
    super.initState();
    // Onboarding's last step may ask for a first action.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final added = ref.read(appControllerProvider).takeRecurringAdded();
      if (added > 0) {
        showSuccess(
          ScaffoldMessenger.maybeOf(context),
          added == 1 ? 'Added 1 repeating record.' : 'Added $added repeating records.',
        );
      }
      switch (ref.read(appControllerProvider).takeFirstAction()) {
        case 'scan':
          _scan();
        case 'add':
          openEntry(context);
      }
    });
  }

  Future<void> _scan() async {
    HapticFeedback.mediumImpact();
    final app = ref.read(appControllerProvider);
    final id = await captureReceipt(context, year: app.selectedYear);
    if (id == null || !mounted) return;
    // Straight into a new expense, pre-filled from the receipt (read on this phone). Cancel keeps the receipt in
    // the Vault, unmatched.
    await openEntry(context, receiptId: id);
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appControllerProvider);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        titleSpacing: Space.gutter,
        title: Row(
          children: [
            // Home's greeting is its title (one hero per screen); other tabs name themselves.
            if (_tab != 0) ...[
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedSwitcher(
                    duration: Motion.medium,
                    child: Text(
                      _titles[_tab],
                      key: ValueKey(_tab),
                      style: context.text.headlineSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Space.sm),
            ],
            YearSwitcher(year: app.selectedYear, onChanged: app.setYear, filed: app.filedYears),
            if (_tab == 0) const Spacer(),
          ],
        ),
        actions: [
          IconButton(tooltip: 'Search', icon: const Icon(Icons.search_rounded), onPressed: () => openSearch(context)),
          IconButton(tooltip: 'Add a record', icon: const Icon(Icons.add_rounded), onPressed: () => openEntry(context)),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          const SizedBox(width: Space.sm),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          for (final (i, tab) in const <Widget>[HomeTab(), RecordsTab(), VaultTab(), TaxesTab()].indexed)
            _TabFade(active: i == _tab, child: tab),
        ],
      ),
      // Nav labels stop growing at 1.3x text (common practice): five labels can't fit at 2x (UI review L4).
      bottomNavigationBar: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: LLBottomBar(
          index: _tab,
          onTap: (i) {
            HapticFeedback.selectionClick();
            setState(() => _tab = i);
          },
          onScan: _scan,
        ),
      ),
    );
  }
}

class YearSwitcher extends StatelessWidget {
  final int year;
  final ValueChanged<int> onChanged;
  final Set<int> filed;
  const YearSwitcher({super.key, required this.year, required this.onChanged, this.filed = const {}});

  @override
  Widget build(BuildContext context) {
    final ll = context.ll;
    return Semantics(
      button: true,
      label: 'Tax year $year${filed.contains(year) ? ', filed' : ''}. Change year',
      child: Material(
        color: ll.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.pill),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.pill),
          onTap: () async {
            final y = await showModalBottomSheet<int>(
              context: context,
              builder: (ctx) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Tax year', style: ctx.text.titleMedium),
                    const SizedBox(height: Space.sm),
                    for (final y in TaxRules.supportedYears)
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: Space.xl),
                        title: Text('$y', style: ctx.text.titleMedium),
                        subtitle: Text(
                          '${y == DateTime.now().year ? 'Current year' : 'Previous year'}'
                          '${filed.contains(y) ? ' · Filed' : ''}',
                        ),
                        trailing: y == year ? Icon(Icons.check_circle, color: ctx.ll.accent) : null,
                        onTap: () => Navigator.pop(ctx, y),
                      ),
                    const SizedBox(height: Space.lg),
                  ],
                ),
              ),
            );
            if (y != null && y != year) onChanged(y);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14), // 48 dp target
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$year',
                  style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontFeatures: tabular),
                ),
                if (filed.contains(year)) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.task_alt_rounded, size: 16, color: ll.accent),
                  const SizedBox(width: 2),
                  Text('Filed', style: context.text.labelMedium?.copyWith(color: ll.accent)),
                ],
                const SizedBox(width: 2),
                Icon(Icons.expand_more, size: 18, color: ll.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LLBottomBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final VoidCallback onScan;
  const LLBottomBar({super.key, required this.index, required this.onTap, required this.onScan});

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.receipt_long_outlined, Icons.receipt_long, 'Records'),
    (Icons.folder_outlined, Icons.folder_rounded, 'Vault'),
    (Icons.account_balance_outlined, Icons.account_balance, 'Taxes'),
  ];

  @override
  Widget build(BuildContext context) {
    final ll = context.ll;
    Widget item(int i) {
      final (off, on, label) = _items[i];
      final selected = i == index;
      return Expanded(
        child: Semantics(
          selected: selected,
          button: true,
          label: label,
          excludeSemantics: true,
          child: InkResponse(
            onTap: () => onTap(i),
            radius: 36,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: selected ? ll.accentSoft : Colors.transparent,
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                  child: Icon(selected ? on : off, color: selected ? ll.accent : ll.muted, size: 24),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: context.text.labelSmall?.copyWith(
                    color: selected ? ll.text : ll.muted,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: ll.surface,
        border: Border(top: BorderSide(color: ll.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              item(0),
              item(1),
              Expanded(
                child: Center(
                  child: Transform.translate(
                    offset: const Offset(0, -14),
                    child: Semantics(
                      button: true,
                      label: 'Scan a receipt',
                      child: GestureDetector(
                        onTap: onScan,
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [ll.heroStart, ll.heroEnd],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: ll.accent.withValues(alpha: 0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                            border: Border.all(color: ll.surface, width: 4),
                          ),
                          child: const Icon(Icons.document_scanner_rounded, color: Colors.white, size: 26),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              item(2),
              item(3),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tab change: the incoming tab fades and rises a few pixels (continuity) while keeping its state and scroll.
class _TabFade extends StatefulWidget {
  final bool active;
  final Widget child;
  const _TabFade({required this.active, required this.child});
  @override
  State<_TabFade> createState() => _TabFadeState();
}

class _TabFadeState extends State<_TabFade> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: Motion.medium, value: 1);

  @override
  void didUpdateWidget(_TabFade old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active && !Motion.reduced(context)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (_, child) {
      final v = Motion.enter.transform(_c.value);
      return Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 8 * (1 - v)), child: child),
      );
    },
  );
}
