// Onboarding (SPEC §5): privacy promise -> password -> recovery key -> biometrics -> business type -> first steps.
// Password, recovery key and biometric screens live in lock_screens / recovery_screens.
import 'package:flutter/material.dart';

import '../data/business_types.dart';
import 'design/components.dart';
import 'design/theme.dart';

/// Shared layout: scrollable content, a pinned primary action, and step dots so the user knows how far along
/// they are.
class _OnboardingShell extends StatelessWidget {
  final int step; // 0-based; -1 hides the dots
  final List<Widget> children;
  final Widget action;
  final Widget? secondary;
  const _OnboardingShell({required this.step, required this.children, required this.action, this.secondary});

  static const steps = 5;

  @override
  Widget build(BuildContext context) {
    final ll = context.ll;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(Space.xl, Space.xl, Space.xl, Space.lg),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (step >= 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.lg),
                      child: Semantics(
                        label: 'Step ${step + 1} of $steps',
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < steps; i++)
                              AnimatedContainer(
                                duration: Motion.medium,
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: i == step ? 22 : 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: i <= step ? ll.accent : ll.border,
                                  borderRadius: BorderRadius.circular(Radii.pill),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  action,
                  ?secondary,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Step 1: the promise. Shown only before a vault exists.
class WelcomeScreen extends StatelessWidget {
  final VoidCallback onStart;
  const WelcomeScreen({super.key, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final ll = context.ll;
    Widget promise(IconData icon, String title, String body) => Padding(
      padding: const EdgeInsets.only(bottom: Space.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: ll.accentSoft, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 20, color: ll.accent),
          ),
          const SizedBox(width: Space.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleSmall),
                const SizedBox(height: 2),
                Text(body, style: context.text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
    return _OnboardingShell(
      step: 0,
      action: FilledButton(onPressed: onStart, child: const Text('Get started')),
      children: [
        const SizedBox(height: Space.lg),
        const Center(child: Illustration(Art.ledger, width: 200)),
        const SizedBox(height: Space.xl),
        Text('Your side hustle,\nkept on your phone.', style: context.text.headlineMedium),
        const SizedBox(height: Space.sm),
        Text(
          'Track income, expenses and receipts, and see what to set aside for taxes. Here is the deal:',
          style: context.text.bodyMedium?.copyWith(color: ll.muted),
        ),
        const SizedBox(height: Space.xl),
        promise(Icons.wifi_off_rounded, 'Nothing leaves this phone', 'No internet permission, no servers, no cloud.'),
        promise(Icons.lock_outline_rounded, 'Encrypted, always', 'Records and receipts are locked with your password.'),
        promise(Icons.person_off_outlined, 'No account, no ads, no tracking', 'We never know who you are.'),
      ],
    );
  }
}

/// Step 4: "What kind of work do you do?" Reused from Settings with [settings] = true (no dots, Save label).
class BusinessTypeScreen extends StatefulWidget {
  final Set<String> initial;
  final Future<void> Function(Set<String>) onDone;
  final bool settings;
  const BusinessTypeScreen({super.key, this.initial = const {}, required this.onDone, this.settings = false});
  @override
  State<BusinessTypeScreen> createState() => _BusinessTypeScreenState();
}

class _BusinessTypeScreenState extends State<BusinessTypeScreen> {
  late final _picked = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final ll = context.ll;
    final body = [
      Text('What kind of work do you do?', style: context.text.headlineMedium),
      const SizedBox(height: Space.sm),
      Text(
        'Pick any that fit. Your most likely categories will show first. Nothing is hidden, and you can change '
        'this in Settings.',
        style: context.text.bodyMedium?.copyWith(color: ll.muted),
      ),
      const SizedBox(height: Space.xl),
      for (final e in businessTypes.entries)
        Padding(
          padding: const EdgeInsets.only(bottom: Space.md),
          child: _TypeCard(
            label: e.value.$1,
            hint: e.value.$2,
            icon: switch (e.key) {
              'products' => Icons.storefront_outlined,
              'services' => Icons.work_outline_rounded,
              'driving' => Icons.directions_car_outlined,
              _ => Icons.videocam_outlined,
            },
            selected: _picked.contains(e.key),
            onTap: () => setState(() => _picked.contains(e.key) ? _picked.remove(e.key) : _picked.add(e.key)),
          ),
        ),
    ];
    if (widget.settings) {
      return Scaffold(
        appBar: AppBar(title: const Text('Business type')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xxl),
          children: [
            ...body,
            const SizedBox(height: Space.md),
            FilledButton(onPressed: () => widget.onDone(_picked), child: const Text('Save')),
          ],
        ),
      );
    }
    return _OnboardingShell(
      step: 3,
      action: FilledButton(
        onPressed: () => widget.onDone(_picked),
        child: Text(_picked.isEmpty ? 'Skip for now' : 'Continue'),
      ),
      children: body,
    );
  }
}

class _TypeCard extends StatelessWidget {
  final String label, hint;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _TypeCard({
    required this.label,
    required this.hint,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ll = context.ll;
    return Semantics(
      checked: selected,
      child: Pressable(
        child: AnimatedContainer(
          duration: Motion.fast,
          decoration: BoxDecoration(
            color: selected ? ll.accentSoft : ll.surface,
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: selected ? ll.accent : ll.border, width: selected ? 1.6 : 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.card),
            onTap: () {
              tick();
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: Row(
                children: [
                  Icon(icon, color: selected ? ll.accent : ll.muted),
                  const SizedBox(width: Space.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: context.text.titleSmall),
                        Text(hint, style: context.text.bodySmall),
                      ],
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: Motion.fast,
                    child: Icon(
                      selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                      key: ValueKey(selected),
                      color: selected ? ll.accent : ll.border,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Step 5: done. Offer the first real action (SPEC: "scan your first receipt").
class FirstStepsScreen extends StatelessWidget {
  final void Function(String? action) onDone;
  const FirstStepsScreen({super.key, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final ll = context.ll;
    return _OnboardingShell(
      step: 4,
      action: FilledButton.icon(
        onPressed: () => onDone('scan'),
        icon: const Icon(Icons.document_scanner_rounded),
        label: const Text('Scan a receipt'),
      ),
      secondary: Padding(
        padding: const EdgeInsets.only(top: Space.sm),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(onPressed: () => onDone('add'), child: const Text('Add a record')),
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: TextButton(onPressed: () => onDone(null), child: const Text('Look around first')),
            ),
          ],
        ),
      ),
      children: [
        const SizedBox(height: Space.lg),
        const Center(child: Illustration(Art.receipt, width: 200)),
        const SizedBox(height: Space.xl),
        Text('You’re all set.', style: context.text.headlineMedium),
        const SizedBox(height: Space.sm),
        Text(
          'Your vault is ready and locked to this phone. The quickest way to start is a receipt you already have.',
          style: context.text.bodyMedium?.copyWith(color: ll.muted),
        ),
      ],
    );
  }
}
