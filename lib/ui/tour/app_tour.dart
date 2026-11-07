// App tour: an optional walk around the main screen for someone who has never done their own taxes. Offered once,
// right after setup ("Want a quick tour?"), and any time from Settings. Each step dims the screen, lights up one
// part of the app and explains it in plain, encouraging words. Back, Next and Skip are always there; system Back
// leaves the tour.
import 'package:flutter/material.dart';

import '../design/theme.dart';

/// What the tour points at. Attached to the real widgets in the app shell and Home.
abstract final class TourTargets {
  static final hero = GlobalKey(debugLabel: 'tour-hero');
  static final add = GlobalKey(debugLabel: 'tour-add');
  static final scan = GlobalKey(debugLabel: 'tour-scan');
  static final records = GlobalKey(debugLabel: 'tour-records');
  static final vault = GlobalKey(debugLabel: 'tour-vault');
  static final taxes = GlobalKey(debugLabel: 'tour-taxes');
  static final search = GlobalKey(debugLabel: 'tour-search');
  static final year = GlobalKey(debugLabel: 'tour-year');
  static final settings = GlobalKey(debugLabel: 'tour-settings');
}

class TourStep {
  final GlobalKey? target; // null = a card in the middle of the screen
  final String title, body;
  const TourStep(this.target, this.title, this.body);
}

final tourSteps = <TourStep>[
  const TourStep(
    null,
    'Welcome to LedgerLock',
    'This is a quick look around. You don\'t need to know anything about taxes: LedgerLock does the math and '
        'explains things in plain English. You can leave the tour any time.',
  ),
  TourStep(
    TourTargets.hero,
    'Your year at a glance',
    'Money in, business costs, and what\'s left: your profit. Taxes are based on profit, so every business '
        'expense you record works in your favor.',
  ),
  TourStep(
    TourTargets.add,
    'Add income or an expense',
    'Got paid, or spent money on your side business? Tap here. Type the amount, pick what it was for, and you\'re '
        'done. It takes a few seconds.',
  ),
  TourStep(
    TourTargets.scan,
    'Snap a receipt',
    'Point your camera at a receipt. LedgerLock reads it on this phone to fill in the amount, and keeps the photo '
        'locked away, never in your gallery.',
  ),
  TourStep(
    TourTargets.records,
    'All your records',
    'Everything you\'ve added, month by month. Tap one to change it. Press and hold to change or delete several '
        'at once.',
  ),
  TourStep(
    TourTargets.vault,
    'Your vault',
    'Receipts, tax forms and letters, locked with your password. Handy when it\'s time to file.',
  ),
  TourStep(
    TourTargets.taxes,
    'Taxes, made simple',
    'How much to set aside, when payments are due, and short lessons when you want to understand more. Nothing '
        'here is ever sent anywhere.',
  ),
  TourStep(
    TourTargets.search,
    'Find anything',
    'Search like you\'d say it: "coffee last month", "over 50" or "no receipt".',
  ),
  TourStep(
    TourTargets.year,
    'Switch tax years',
    'Each tax year is kept separately. Tap here to look back at last year.',
  ),
  TourStep(
    TourTargets.settings,
    'Settings and backups',
    'Your records live only on this phone, so make a backup here soon and keep it somewhere safe. You can replay '
        'this tour from here too.',
  ),
  const TourStep(
    null,
    'You\'re all set',
    'That\'s everything you need to get started. Add your first record whenever you\'re ready. You\'re already '
        'ahead of most people who wait until April.',
  ),
];

/// Asks once, right after setup. True if the user wants the tour.
Future<bool> offerAppTour(BuildContext context) async {
  final yes = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.waving_hand_rounded, size: 40, color: c.ll.accent),
            const SizedBox(height: Space.sm),
            Text('Want a quick tour?', style: c.text.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: Space.sm),
            Text(
              'Two minutes to see where everything is. No tax know-how needed: we\'ll explain as we go.',
              style: c.text.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Space.lg),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Show me around')),
            const SizedBox(height: Space.xs),
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Maybe later')),
            Text('You can take the tour any time from Settings.', style: c.text.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
  return yes == true;
}

/// Runs the tour over the current screen (the shell shows Home first). Completes when it ends or is skipped.
Future<void> showAppTour(BuildContext context, {List<TourStep>? steps}) => Navigator.of(context).push(
  PageRouteBuilder<void>(
    opaque: false,
    barrierDismissible: false,
    transitionDuration: Motion.medium,
    reverseTransitionDuration: Motion.fast,
    pageBuilder: (_, _, _) => _Tour(steps: steps ?? tourSteps),
    transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
  ),
);

class _Tour extends StatefulWidget {
  final List<TourStep> steps;
  const _Tour({required this.steps});
  @override
  State<_Tour> createState() => _TourState();
}

class _TourState extends State<_Tour> {
  int _i = 0;
  Rect? _hole;

  @override
  void initState() {
    super.initState();
    _measure();
  }

  /// Scrolls the target into view if needed, then finds where it is on screen.
  void _measure() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final ctx = widget.steps[_i].target?.currentContext;
      if (ctx != null && ctx.mounted) {
        await Scrollable.ensureVisible(ctx, alignment: 0.1, duration: Motion.fast);
      }
      if (!mounted) return;
      final box = widget.steps[_i].target?.currentContext?.findRenderObject();
      setState(() {
        _hole = box is RenderBox && box.attached && box.hasSize
            ? (box.localToGlobal(Offset.zero) & box.size).inflate(6)
            : null;
      });
    });
  }

  void _go(int to) {
    if (to < 0) return;
    if (to >= widget.steps.length) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _i = to;
      _hole = null;
    });
    _measure();
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_i];
    final last = _i == widget.steps.length - 1;
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final hole = step.target == null ? null : _hole;
    // The card goes on the side of the target with more room; centered when there's no target.
    final below = hole == null || hole.center.dy < size.height / 2;
    final card = Material(
      color: context.ll.surface,
      elevation: 8,
      borderRadius: BorderRadius.circular(Radii.card),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.md, Space.sm),
        child: Semantics(
          liveRegion: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${_i + 1} of ${widget.steps.length}',
                style: context.text.labelSmall?.copyWith(color: context.ll.muted),
              ),
              const SizedBox(height: Space.xs),
              Text(step.title, style: context.text.titleMedium),
              const SizedBox(height: Space.xs),
              Text(step.body, style: context.text.bodyMedium),
              const SizedBox(height: Space.sm),
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Space.xs,
                children: [
                  if (!last) TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Skip tour')),
                  if (_i > 0) TextButton(onPressed: () => _go(_i - 1), child: const Text('Back')),
                  FilledButton(
                    onPressed: () => _go(_i + 1),
                    child: Text(last ? 'Let\'s go' : (_i == 0 ? 'Start' : 'Next')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return PopScope(
      child: Stack(
        children: [
          Positioned.fill(
            child: ExcludeSemantics(
              child: GestureDetector(
                onTap: () {}, // the dimmed app underneath doesn't react during the tour
                child: CustomPaint(painter: _Scrim(hole, Colors.black.withValues(alpha: 0.62))),
              ),
            ),
          ),
          if (hole == null)
            Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  Space.gutter,
                  pad.top + Space.gutter,
                  Space.gutter,
                  pad.bottom + Space.gutter,
                ),
                child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: card),
              ),
            )
          else
            Positioned(
              left: Space.gutter,
              right: Space.gutter,
              top: below ? (hole.bottom + Space.md).clamp(pad.top, size.height) : null,
              bottom: below ? null : (size.height - hole.top + Space.md).clamp(pad.bottom, size.height),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 440,
                    maxHeight: below
                        ? (size.height - hole.bottom - Space.md - pad.bottom - Space.sm).clamp(120, size.height)
                        : (hole.top - Space.md - pad.top - Space.sm).clamp(120, size.height),
                  ),
                  child: SingleChildScrollView(child: card),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Scrim extends CustomPainter {
  final Rect? hole;
  final Color color;
  _Scrim(this.hole, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final all = Path()..addRect(Offset.zero & size);
    final h = hole;
    final path = h == null
        ? all
        : Path.combine(
            PathOperation.difference,
            all,
            Path()..addRRect(RRect.fromRectAndRadius(h, const Radius.circular(18))),
          );
    canvas.drawPath(path, Paint()..color = color);
    if (h != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(h, const Radius.circular(18)),
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_Scrim old) => old.hole != hole || old.color != color;
}
