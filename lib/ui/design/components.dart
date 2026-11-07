// Shared components. Screens compose these instead of styling raw widgets.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'illustrations.dart';
import 'theme.dart';

export 'illustrations.dart' show Art, Illustration;

final _usd = NumberFormat.currency(locale: 'en_US', symbol: r'$');

/// Money is always integer cents in the app; formatted with tabular figures.
String formatCents(int cents) => _usd.format(cents / 100);

class MoneyText extends StatelessWidget {
  final int cents;
  final TextStyle? style;
  final Color? color;
  const MoneyText(this.cents, {super.key, this.style, this.color});

  @override
  Widget build(BuildContext context) => Text(
    formatCents(cents),
    // Always Manrope: the voice serif has no tabular figures (docs/DESIGN.md).
    style: (style ?? context.text.titleMedium)?.copyWith(fontFamily: Fonts.ui, fontFeatures: tabular, color: color),
    semanticsLabel: '${cents < 0 ? 'minus ' : ''}${formatCents(cents.abs())}',
  );
}

/// 20 px rounded surface with a hairline border.
class LLCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  const LLCard({super.key, required this.child, this.padding = const EdgeInsets.all(Space.lg), this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final card = Card(
      color: color,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
    return onTap == null ? card : Pressable(child: card);
  }
}

/// Tactile press: the child sinks slightly while touched and springs back (critically damped, no wobble).
/// Purely visual: taps still go to the child's own InkWell/onTap.
class Pressable extends StatefulWidget {
  final Widget child;
  final double depth;
  const Pressable({super.key, required this.child, this.depth = 0.975});
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  void _set(bool v) {
    if (v != _down) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _set(true),
    onPointerUp: (_) => _set(false),
    onPointerCancel: (_) => _set(false),
    child: AnimatedScale(
      scale: _down ? widget.depth : 1,
      duration: Motion.reduced(context) ? Duration.zero : (_down ? Motion.fast : Motion.medium),
      curve: _down ? Curves.easeOut : Curves.easeOutCubic,
      child: widget.child,
    ),
  );
}

/// Money that counts to its new value instead of jumping (continuity). Instant with reduce-motion.
class AnimatedMoney extends StatefulWidget {
  final int cents;
  final TextStyle? style;
  final Color? color;
  const AnimatedMoney(this.cents, {super.key, this.style, this.color});
  @override
  State<AnimatedMoney> createState() => _AnimatedMoneyState();
}

class _AnimatedMoneyState extends State<AnimatedMoney> {
  late int _from = widget.cents;
  @override
  void didUpdateWidget(AnimatedMoney old) {
    super.didUpdateWidget(old);
    if (old.cents != widget.cents) _from = old.cents;
  }

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context) || _from == widget.cents) {
      return MoneyText(widget.cents, style: widget.style, color: widget.color);
    }
    return TweenAnimationBuilder<double>(
      key: ValueKey(widget.cents),
      tween: Tween(begin: _from.toDouble(), end: widget.cents.toDouble()),
      duration: Motion.slow,
      curve: Curves.easeOutCubic,
      onEnd: () => _from = widget.cents,
      builder: (_, v, _) => MoneyText(v.round(), style: widget.style, color: widget.color),
    );
  }
}

/// Entrance: fade + rise, staggered by [index]. Plays once when first built. Instant with reduce-motion.
class Reveal extends StatelessWidget {
  final int index;
  final Widget child;
  const Reveal({super.key, this.index = 0, required this.child});

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return child;
    final delay = Motion.stagger.inMilliseconds * index.clamp(0, 8);
    final total = Motion.medium.inMilliseconds + 150 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      builder: (_, t, c) {
        final v = Motion.enter.transform(((t * total - delay) / (total - delay)).clamp(0.0, 1.0));
        return Opacity(
          opacity: v,
          child: Transform.translate(offset: Offset(0, 14 * (1 - v)), child: c),
        );
      },
      child: child,
    );
  }
}

/// Light haptic for selections and toggles; medium for commits (save, log payment).
void tick() => HapticFeedback.selectionClick();

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionHeader(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, Space.xl, 4, Space.sm),
    child: Row(
      children: [
        Expanded(
          child: Text(title.toUpperCase(), style: context.text.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Small label + money value tile used on the dashboard.
class StatTile extends StatelessWidget {
  final String label;
  final int cents;
  final IconData icon;
  final Color? tint;
  const StatTile({super.key, required this.label, required this.cents, required this.icon, this.tint});

  @override
  Widget build(BuildContext context) {
    final c = tint ?? context.ll.accent;
    return LLCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 20, color: c),
          ),
          const SizedBox(height: Space.md),
          Text(label, style: context.text.bodySmall),
          const SizedBox(height: 2),
          MoneyText(cents, style: context.text.titleLarge),
        ],
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData? icon;
  const Pill(this.label, {super.key, this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.ll.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(Radii.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: c), const SizedBox(width: 4)],
          Text(
            label,
            style: context.text.labelMedium?.copyWith(color: c, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Empty states that teach (SPEC §5): icon, a clear title, one sentence, one action.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// In-house illustration instead of the icon circle.
  final Art? art;
  const EmptyState({
    super.key,
    this.art,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final ll = context.ll;
    return LLCard(
      padding: const EdgeInsets.fromLTRB(Space.xl, Space.xxl, Space.xl, Space.xl),
      child: Column(
        children: [
          if (art != null)
            Illustration(art!)
          else
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [ll.accentSoft, ll.accentSoft.withValues(alpha: 0.4)],
                ),
              ),
              child: Icon(icon, size: 32, color: ll.accent),
            ),
          const SizedBox(height: Space.lg),
          Text(
            title,
            style: context.text.titleMedium?.copyWith(
              fontFamily: Fonts.voice,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Space.sm),
          Text(body, style: context.text.bodySmall, textAlign: TextAlign.center),
          if (actionLabel != null) ...[
            const SizedBox(height: Space.lg),
            FilledButton.tonal(
              onPressed: onAction,
              style: FilledButton.styleFrom(minimumSize: const Size(160, 48)),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

/// Settings-style grouped list.
class LLGroup extends StatelessWidget {
  final List<Widget> children;
  const LLGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) => LLCard(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[if (i > 0) const Divider(indent: 56), children[i]],
      ],
    ),
  );
}

/// Segmented switch with a sliding pill (continuity: the selection moves rather than blinking).
class LLSegmented<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;
  const LLSegmented({super.key, required this.options, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final ll = context.ll;
    final i = options.indexWhere((o) => o.$1 == value).clamp(0, options.length - 1);
    return Container(
      height: 56, // 48 dp segments inside the 4 px track (M8 a11y)
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: ll.surfaceAlt, borderRadius: BorderRadius.circular(Radii.pill)),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth / options.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: Motion.reduced(context) ? Duration.zero : Motion.medium,
                curve: Motion.enter,
                left: w * i,
                top: 0,
                bottom: 0,
                width: w,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: ll.surface,
                    borderRadius: BorderRadius.circular(Radii.pill),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  for (final (j, (v, label)) in options.indexed)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: j == i,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(Radii.pill),
                          onTap: () {
                            if (v == value) return;
                            tick();
                            onChanged(v);
                          },
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: Motion.fast,
                              style: context.text.labelLarge!.copyWith(color: j == i ? ll.text : ll.muted),
                              child: Text(label),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Success moment (peak-end rule): a check that pops in, a firm haptic, one plain line saying what happened.
/// Pass the messenger captured before popping a route. [onUndo] adds an Undo button (5 s, never persistent: U4).
void showSuccess(ScaffoldMessengerState? messenger, String message, {VoidCallback? onUndo}) {
  HapticFeedback.mediumImpact();
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: onUndo == null ? const Duration(milliseconds: 2600) : const Duration(seconds: 5),
        persist: false,
        action: onUndo == null ? null : SnackBarAction(label: 'Undo', onPressed: onUndo),
        content: Row(
          children: [
            const _PopCheck(),
            const SizedBox(width: Space.md),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

class _PopCheck extends StatelessWidget {
  const _PopCheck();
  @override
  Widget build(BuildContext context) {
    final ll = context.ll;
    final circle = Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(color: ll.accent, shape: BoxShape.circle),
      child: Icon(Icons.check_rounded, size: 18, color: ll.onAccent),
    );
    if (Motion.reduced(context)) return circle;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Motion.success,
      builder: (_, v, c) => Transform.scale(scale: v, child: c),
      child: circle,
    );
  }
}

/// "Record deleted · Undo". Not persistent and short-lived, so it can't outlive an auto-lock and call into a
/// closed database (UI review U4); main.dart also clears snackbars whenever the app locks.
void showUndo(ScaffoldMessengerState messenger, String message, VoidCallback onUndo) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        persist: false,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(label: 'Undo', onPressed: onUndo),
      ),
    );
}

/// Two-column tile grid whose rows grow with their content (text size), unlike GridView's fixed aspect ratio which
/// overflowed at 1.3x text (UI review L2). Tiles in a row share the taller height.
class TileGrid extends StatelessWidget {
  final List<Widget> children;
  final double minHeight;
  const TileGrid({super.key, required this.children, this.minHeight = 112});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < children.length; i += 2) ...[
        if (i > 0) const SizedBox(height: Space.md),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: minHeight),
                  child: children[i],
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox.shrink()),
            ],
          ),
        ),
      ],
    ],
  );
}

/// Asks for a whole-dollar amount; pops with cents (0 = Remove), or null on Cancel. Owns its controller, so it is
/// disposed only after the dialog has left the tree. Disposing it from the caller while the route animated out
/// crashed on a device ("_dependents.isEmpty", budgets) - same class as UI review U2.
class AmountDialog extends StatefulWidget {
  final String title, helper;
  final int currentCents;
  final bool allowRemove;
  final int maxDigits;
  const AmountDialog({
    super.key,
    required this.title,
    required this.helper,
    this.currentCents = 0,
    this.allowRemove = false,
    this.maxDigits = 8,
  });
  @override
  State<AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<AmountDialog> {
  late final _c = TextEditingController(text: widget.currentCents > 0 ? '${widget.currentCents ~/ 100}' : '');

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _c,
      autofocus: true,
      enableIMEPersonalizedLearning: false,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(widget.maxDigits)],
      decoration: InputDecoration(prefixText: r'$ ', helperText: widget.helper, helperMaxLines: 2),
    ),
    actions: [
      if (widget.allowRemove) TextButton(onPressed: () => Navigator.pop(context, 0), child: const Text('Remove')),
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(
        onPressed: () => Navigator.pop(context, (int.tryParse(_c.text) ?? 0) * 100),
        child: const Text('Save'),
      ),
    ],
  );
}
