// The LedgerLock mark, painted with the exact geometry of the launcher icon (docs/brand/icon.svg,
// res/drawable/ic_launcher_*.xml): a padlock whose body is an open ledger, lines on the left page and a gold coin
// keyhole on the right. Coordinates are in the icon's 108-unit space.
import 'package:flutter/material.dart';

class BrandMark extends StatelessWidget {
  final double size;

  /// false: just the mark (for use on an already-coloured surface).
  final bool tile;
  const BrandMark({super.key, this.size = 72, this.tile = true});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'LedgerLock',
    image: true,
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _MarkPainter(tile)),
    ),
  );
}

class _MarkPainter extends CustomPainter {
  final bool tile;
  _MarkPainter(this.tile);

  static const emerald = Color(0xFF0D6B55), deep = Color(0xFF083F33), paper = Color(0xFFFBF7EC);
  static const paperShade = Color(0xFFEFE6D1), gold = Color(0xFFE7B648), goldEdge = Color(0xFFC9952C);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 108;
    final rect = Offset.zero & size;
    if (tile) {
      final rr = RRect.fromRectAndRadius(rect, Radius.circular(size.width * 0.24));
      canvas.save();
      canvas.clipRRect(rr);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment(-0.7, -1),
            end: Alignment(0.7, 1),
            colors: [Color(0xFF14906F), emerald, deep],
            stops: [0, 0.55, 1],
          ).createShader(rect),
      );
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.5, -0.76),
            radius: 0.7,
            colors: [Colors.white.withValues(alpha: 0.16), Colors.white.withValues(alpha: 0)],
          ).createShader(rect),
      );
      canvas.restore();
    }
    canvas.save();
    // In-app there is no launcher mask, so the mark can fill more of its tile than the 66-unit icon safe zone.
    final zoom = tile ? 1.4 : 1.0;
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(s * zoom);
    canvas.translate(-54, -56); // the mark's visual centre (shackle top 31 to body bottom 81)

    // Shackle.
    canvas.drawPath(
      Path()
        ..moveTo(43.5, 49)
        ..lineTo(43.5, 41.5)
        ..arcToPoint(const Offset(64.5, 41.5), radius: const Radius.circular(10.5))
        ..lineTo(64.5, 49),
      Paint()
        ..color = paper
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.4
        ..strokeCap = StrokeCap.round,
    );

    // Ledger body: flat top, pages dipping at the spine along the bottom.
    final body = Path()
      ..moveTo(39, 46)
      ..lineTo(69, 46)
      ..arcToPoint(const Offset(76, 53), radius: const Radius.circular(7))
      ..lineTo(76, 73)
      ..arcToPoint(const Offset(71, 78), radius: const Radius.circular(5))
      ..cubicTo(64, 78, 58, 78.4, 54, 81)
      ..cubicTo(50, 78.4, 44, 78, 37, 78)
      ..arcToPoint(const Offset(32, 73), radius: const Radius.circular(5))
      ..lineTo(32, 53)
      ..arcToPoint(const Offset(39, 46), radius: const Radius.circular(7))
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [paper, paperShade],
        ).createShader(const Rect.fromLTRB(32, 46, 76, 81)),
    );
    canvas.drawLine(
      const Offset(54, 50),
      const Offset(54, 79.5),
      Paint()
        ..color = emerald.withValues(alpha: 0.28)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );

    // Ledger lines.
    for (final (y, w, a) in const [(55.0, 12.5, 1.0), (61.0, 9.0, 0.7), (67.0, 11.0, 0.5)]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(37.5, y, w, 2.8), const Radius.circular(1.4)),
        Paint()..color = emerald.withValues(alpha: a),
      );
    }

    // Gold coin keyhole.
    const c = Offset(64.5, 62.5);
    canvas.drawCircle(c, 6.3, Paint()..color = gold);
    canvas.drawCircle(
      c,
      6.3,
      Paint()
        ..color = goldEdge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
    final hole = Paint()..color = deep;
    canvas.drawCircle(const Offset(64.5, 61.2), 1.7, hole);
    canvas.drawPath(
      Path()
        ..moveTo(63.6, 62)
        ..lineTo(65.4, 62)
        ..lineTo(65.9, 66.4)
        ..lineTo(63.1, 66.4)
        ..close(),
      hole,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.tile != tile;
}
