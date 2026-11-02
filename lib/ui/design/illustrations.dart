// In-house empty-state illustrations (SPEC §5): flat geometric scenes painted with theme colours, so they adapt to
// light/dark and add no assets. They float a few pixels on a slow loop (off with reduce-motion and in tests).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

enum Art { ledger, receipt }

class Illustration extends StatefulWidget {
  final Art art;
  final double width;
  const Illustration(this.art, {super.key, this.width = 168});
  @override
  State<Illustration> createState() => _IllustrationState();
}

class _IllustrationState extends State<Illustration> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 4));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.ambient && !Motion.reduced(context)) {
      if (!_c.isAnimating) _c.repeat(reverse: true);
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ll = context.ll;
    return ExcludeSemantics(
      child: SizedBox(
        width: widget.width,
        height: widget.width * 0.68,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => CustomPaint(
            painter: switch (widget.art) {
              Art.ledger => _LedgerArt(ll, Curves.easeInOutSine.transform(_c.value)),
              Art.receipt => _ReceiptArt(ll, Curves.easeInOutSine.transform(_c.value)),
            },
          ),
        ),
      ),
    );
  }
}

abstract class _Art extends CustomPainter {
  final LLColors ll;
  final double t; // 0..1 float phase
  _Art(this.ll, this.t);

  Paint fill(Color c) => Paint()..color = c;

  // Dark theme needs its own paper tones or the art sinks into the backdrop.
  bool get dark => ll.background.computeLuminance() < 0.1;
  Color get paper => dark ? const Color(0xFF30352C) : ll.surface;
  Color get sheet => dark ? const Color(0xFF242820) : ll.surfaceAlt;
  Color get line => dark ? ll.muted.withValues(alpha: 0.45) : ll.border;
  RRect rr(Rect r, double radius) => RRect.fromRectAndRadius(r, Radius.circular(radius));

  void shadow(Canvas c, RRect r) => c.drawRRect(
    r.shift(const Offset(0, 6)),
    Paint()
      ..color = ll.heroEnd.withValues(alpha: 0.10)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
  );

  void backdrop(Canvas c, Size s) {
    c.drawCircle(Offset(s.width * 0.5, s.height * 0.55), s.height * 0.46, fill(ll.accentSoft));
    c.drawCircle(Offset(s.width * 0.18, s.height * 0.2), s.height * 0.07, fill(ll.heroGlow.withValues(alpha: 0.55)));
    c.drawCircle(Offset(s.width * 0.86, s.height * 0.3), s.height * 0.04, fill(ll.accent.withValues(alpha: 0.35)));
  }

  /// Round badge with a glyph drawn by [glyph] around its centre.
  void badge(Canvas c, Offset o, double r, void Function(Canvas, Offset, double, Paint) glyph) {
    c.drawCircle(
      o.translate(0, 3),
      r,
      Paint()
        ..color = ll.heroEnd.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    c.drawCircle(o, r, fill(ll.accent));
    final p = Paint()
      ..color = ll.onAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.16
      ..strokeCap = StrokeCap.round;
    glyph(c, o, r, p);
  }

  @override
  bool shouldRepaint(_Art old) => old.t != t || old.ll != ll;
}

class _LedgerArt extends _Art {
  _LedgerArt(super.ll, super.t);

  @override
  void paint(Canvas c, Size s) {
    backdrop(c, s);
    final bob = -3 * t;
    final w = s.width * 0.56, h = s.height * 0.62;
    final front = Rect.fromCenter(center: Offset(s.width * 0.5, s.height * 0.56 + bob), width: w, height: h);
    // Back card, tilted.
    c.save();
    c.translate(front.center.dx, front.center.dy + 4);
    c.rotate(-0.12);
    final back = rr(Rect.fromCenter(center: Offset.zero, width: w, height: h), 12);
    c.drawRRect(back, fill(sheet));
    c.restore();
    // Front card with three rows.
    final card = rr(front, 12);
    shadow(c, card);
    c.drawRRect(card, fill(paper));
    for (var i = 0; i < 3; i++) {
      final y = front.top + h * (0.24 + i * 0.26);
      c.drawCircle(Offset(front.left + w * 0.14, y), h * 0.075, fill(i == 0 ? ll.accentSoft : sheet));
      c.drawRRect(rr(Rect.fromLTWH(front.left + w * 0.27, y - 4, w * (i == 1 ? 0.34 : 0.44), 6), 3), fill(line));
      c.drawRRect(
        rr(Rect.fromLTWH(front.right - w * 0.2, y - 4, w * 0.1, 6), 3),
        fill(i == 0 ? ll.accent.withValues(alpha: 0.7) : line),
      );
    }
    // "+" badge.
    badge(c, Offset(front.right - 2, front.bottom - 4), s.height * 0.12, (c, o, r, p) {
      c.drawLine(o.translate(-r * 0.4, 0), o.translate(r * 0.4, 0), p);
      c.drawLine(o.translate(0, -r * 0.4), o.translate(0, r * 0.4), p);
    });
  }
}

class _ReceiptArt extends _Art {
  _ReceiptArt(super.ll, super.t);

  @override
  void paint(Canvas c, Size s) {
    backdrop(c, s);
    final bob = -3 * t;
    final w = s.width * 0.36, h = s.height * 0.74;
    c.save();
    c.translate(s.width * 0.5, s.height * 0.52 + bob);
    c.rotate(0.07);
    final r = Rect.fromCenter(center: Offset.zero, width: w, height: h);
    // Paper with a zigzag bottom edge.
    final path = Path()
      ..moveTo(r.left, r.top + 6)
      ..quadraticBezierTo(r.left, r.top, r.left + 6, r.top)
      ..lineTo(r.right - 6, r.top)
      ..quadraticBezierTo(r.right, r.top, r.right, r.top + 6)
      ..lineTo(r.right, r.bottom);
    const teeth = 6;
    final tw = w / teeth;
    for (var i = 0; i < teeth; i++) {
      path
        ..lineTo(r.right - tw * (i + 0.5), r.bottom - 6)
        ..lineTo(r.right - tw * (i + 1), r.bottom);
    }
    path.close();
    c.drawPath(
      path.shift(const Offset(0, 6)),
      Paint()
        ..color = ll.heroEnd.withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    c.drawPath(path, fill(paper));
    // Lines and a total.
    for (var i = 0; i < 4; i++) {
      final y = r.top + h * (0.18 + i * 0.13);
      c.drawRRect(rr(Rect.fromLTWH(r.left + w * 0.16, y, w * (i.isEven ? 0.5 : 0.38), 5), 2.5), fill(line));
      c.drawRRect(rr(Rect.fromLTWH(r.right - w * 0.26, y, w * 0.1, 5), 2.5), fill(line));
    }
    c.drawRRect(
      rr(Rect.fromLTWH(r.left + w * 0.16, r.top + h * 0.74, w * 0.68, 7), 3.5),
      fill(ll.heroGlow.withValues(alpha: 0.7)),
    );
    c.restore();
    // Lock badge: the receipt is sealed.
    badge(c, Offset(s.width * 0.5 + w * 0.55, s.height * 0.8 + bob), s.height * 0.13, (c, o, r, p) {
      final body = RRect.fromRectAndRadius(
        Rect.fromCenter(center: o.translate(0, r * 0.18), width: r * 0.9, height: r * 0.68),
        Radius.circular(r * 0.14),
      );
      c.drawRRect(body, Paint()..color = ll.onAccent);
      c.drawArc(
        Rect.fromCenter(center: o.translate(0, -r * 0.18), width: r * 0.56, height: r * 0.62),
        math.pi,
        math.pi,
        false,
        p,
      );
    });
  }
}
