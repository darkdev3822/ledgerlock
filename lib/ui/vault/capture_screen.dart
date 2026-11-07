// Receipt capture: frames are grabbed from the camera stream into memory (never
// takePicture(), which writes a JPEG to disk), cropped, then encrypted.
import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../media/receipt_image.dart';
import '../../platform/document_picker.dart';
import '../design/theme.dart';
import 'crop_screen.dart';

/// Returns the new attachment id, or null if cancelled.
Future<int?> captureReceipt(BuildContext context, {required int year}) =>
    Navigator.of(context).push<int>(MaterialPageRoute(builder: (_) => CaptureScreen(year: year)));

class CaptureScreen extends ConsumerStatefulWidget {
  final int year;
  const CaptureScreen({super.key, required this.year});
  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> with WidgetsBindingObserver {
  CameraController? _cam;
  String? _error;

  /// One camera start at a time: opening from the Quick Settings tile resumes the app while the screen's first start
  /// is still running, and a second bind fails ("too many use cases"). [_paused]: went to the background mid-start.
  bool _starting = false, _paused = false;
  bool _busy = false;
  Completer<YuvFrame>? _want;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cam?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _paused = true;
      _cam?.dispose();
      _cam = null;
    } else if (state == AppLifecycleState.resumed) {
      _paused = false;
      if (_cam == null && !_starting && mounted) _start();
    }
  }

  Future<void> _start() async {
    if (_starting) return;
    _starting = true;
    try {
      final cams = await availableCameras();
      final back = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cams.first);
      final c = CameraController(
        back,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await c.initialize();
      await c.startImageStream(_onFrame);
      if (!mounted || _paused) {
        await c.dispose(); // left the screen or the app while starting; resume starts a fresh one
        return;
      }
      setState(() => _cam = c);
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(
        () => _error = e.code == 'CameraAccessDenied'
            ? 'Camera access is off. Allow it in Android settings, or import a photo instead.'
            : 'The camera isn\'t available right now.',
      );
    } catch (_) {
      if (mounted) setState(() => _error = 'No camera found. You can import a photo or PDF instead.');
    } finally {
      _starting = false;
      if (mounted && !_paused && _cam == null && _error == null) _start(); // a resume came in while starting
    }
  }

  void _onFrame(CameraImage f) {
    final want = _want;
    if (want == null || want.isCompleted || f.planes.length < 3) return;
    _want = null;
    // Copy the plane bytes now: the buffers are reused after this callback.
    want.complete(
      YuvFrame(
        width: f.width,
        height: f.height,
        y: Uint8List.fromList(f.planes[0].bytes),
        u: Uint8List.fromList(f.planes[1].bytes),
        v: Uint8List.fromList(f.planes[2].bytes),
        yRowStride: f.planes[0].bytesPerRow,
        uvRowStride: f.planes[1].bytesPerRow,
        uvPixelStride: f.planes[1].bytesPerPixel ?? 1,
        rotationDegrees: _cam?.description.sensorOrientation ?? 0,
      ),
    );
  }

  Future<void> _shoot() async {
    if (_busy || _cam == null) return;
    HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    try {
      _want = Completer<YuvFrame>();
      final frame = await _want!.future.timeout(const Duration(seconds: 3));
      await _cam?.stopImageStream(); // stop the camera while cropping
      final d = await decodeFrame(frame);
      await _crop(d);
      if (mounted && _cam != null && !_cam!.value.isStreamingImages) await _cam!.startImageStream(_onFrame);
    } catch (_) {
      _snack('Couldn\'t capture. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final app = ref.read(appControllerProvider);
    final docs = app.documents;
    if (docs == null) return;
    try {
      final f = await app.picker.pick();
      if (f == null || !mounted) return;
      if (f.mime.startsWith('image/')) {
        setState(() => _busy = true);
        final decoded = await decodeBytes(f.bytes);
        if (decoded == null) return _snack('That image couldn\'t be opened.');
        await _crop(decoded);
      } else {
        final id = await docs.importFile(
          name: f.name,
          mime: f.mime,
          bytes: f.bytes,
          folder: 'receipt',
          year: widget.year,
        );
        if (mounted) Navigator.of(context).pop(id);
      }
    } on PickTooLarge {
      _snack('That file is over 30 MB.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _crop(Decoded d) async {
    if (!mounted) return;
    final id = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => CropScreen(image: d.image, initial: d.quad, preview: d.preview, year: widget.year),
      ),
    );
    if (id != null && mounted) Navigator.of(context).pop(id);
  }

  void _snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final c = _cam;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan receipt'),
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(Space.xxl),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    )
                  : c == null || !c.value.isInitialized
                  ? const CircularProgressIndicator(color: Colors.white)
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(Radii.card),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CameraPreview(c),
                          IgnorePointer(
                            child: FractionallySizedBox(
                              widthFactor: 0.82,
                              heightFactor: 0.82,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 2),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.xl, Space.lg, Space.xl, Space.xl),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _busy ? null : _import,
                      icon: const Icon(Icons.photo_library_outlined, color: Colors.white),
                      label: const Text('Import', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Take photo',
                    child: GestureDetector(
                      onTap: _busy || c == null ? null : _shoot,
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        padding: const EdgeInsets.all(5),
                        child: _busy
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const DecoratedBox(
                                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                              ),
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Encrypted instantly.\nNever in your gallery.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
