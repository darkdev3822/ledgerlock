// Shared components. Screens compose these instead of styling raw widgets.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'theme.dart';

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
    style: (style ?? context.text.titleMedium)?.copyWith(fontFeatures: tabular, color: color),
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
  Widget build(BuildContext context) => Card(
    color: color,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: padding, child: child),
    ),
  );
}

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
  const EmptyState({
    super.key,
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
          Text(title, style: context.text.titleMedium, textAlign: TextAlign.center),
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
