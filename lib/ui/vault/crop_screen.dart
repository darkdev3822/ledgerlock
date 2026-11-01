// Adjust the auto-detected corners, then crop, encode and encrypt the receipt.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../../app/app_controller.dart';
import '../../media/receipt_image.dart';
import '../design/theme.dart';

class CropScreen extends ConsumerStatefulWidget {
  final img.Image image;
  final Quad initial;
  final Uint8List preview;
  final int year;
  final int? entryId;
  const CropScreen({
    super.key,
    required this.image,
    required this.initial,
    required this.preview,
    required this.year,
    this.entryId,
  });
  @override
  ConsumerState<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends ConsumerState<CropScreen> {
  late List<math.Point<double>> _pts = List.of(widget.initial.points);
  late final Uint8List _preview = widget.preview; // in-memory JPEG, never written to disk
  bool _saving = false;

  Future<void> _save() async {
    final docs = ref.read(appControllerProvider).documents;
    if (docs == null || _saving) return;
    setState(() => _saving = true);
    final r = await finishInBackground(widget.image, Quad(_pts));
    final id = await docs.saveReceipt(r, year: widget.year, entryId: widget.entryId);
    HapticFeedback.mediumImpact();
    if (mounted) Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    final iw = widget.image.width.toDouble(), ih = widget.image.height.toDouble();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Adjust corners'),
        actions: [
          TextButton(
            onPressed: () => setState(() => _pts = List.of(Quad.inset(iw.round(), ih.round(), 0).points)),
            child: const Text('Full photo', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(Space.xl),
              child: LayoutBuilder(
                builder: (context, box) {
                  final s = math.min(box.maxWidth / iw, box.maxHeight / ih);
                  final w = iw * s, h = ih * s;
                  return Center(
                    child: SizedBox(
                      width: w,
                      height: h,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: Image.memory(_preview, fit: BoxFit.fill, gaplessPlayback: true),
                          ),
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _QuadPainter([for (final p in _pts) Offset(p.x * s, p.y * s)]),
                            ),
                          ),
                          for (var i = 0; i < 4; i++)
                            Positioned(
                              left: _pts[i].x * s - 22,
                              top: _pts[i].y * s - 22,
                              child: Semantics(
                                label: 'Corner ${i + 1}',
                                child: GestureDetector(
                                  onPanUpdate: (d) => setState(() {
                                    _pts[i] = math.Point(
                                      (_pts[i].x + d.delta.dx / s).clamp(0, iw),
                                      (_pts[i].y + d.delta.dy / s).clamp(0, ih),
                                    );
                                  }),
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    alignment: Alignment.center,
                                    child: Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: context.ll.accent,
                                        border: Border.all(color: Colors.white, width: 3),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.xl),
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.lock_rounded),
                label: const Text('Save encrypted'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuadPainter extends CustomPainter {
  final List<Offset> pts;
  _QuadPainter(this.pts);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addPolygon(pts, true);
    final shade = Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), path);
    canvas.drawPath(shade, Paint()..color = Colors.black.withValues(alpha: 0.45));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_QuadPainter old) => old.pts != pts;
}
