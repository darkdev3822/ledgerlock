// Receipt image pipeline, all in memory (SPEC §1: plaintext photos never touch disk).
// Camera YUV frame -> RGB -> auto corner detection -> perspective crop -> JPEG + thumbnail.
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// A copied camera frame (plane bytes must be copied before the camera callback returns).
class YuvFrame {
  final int width, height;
  final Uint8List y, u, v;
  final int yRowStride, uvRowStride, uvPixelStride;
  final int rotationDegrees;

  const YuvFrame({
    required this.width,
    required this.height,
    required this.y,
    required this.u,
    required this.v,
    required this.yRowStride,
    required this.uvRowStride,
    required this.uvPixelStride,
    this.rotationDegrees = 0,
  });
}

/// Corners in image pixel coordinates, clockwise from top-left.
class Quad {
  final List<math.Point<double>> points; // tl, tr, br, bl
  const Quad(this.points);

  factory Quad.inset(int w, int h, [double f = 0.06]) => Quad([
    math.Point(w * f, h * f),
    math.Point(w * (1 - f), h * f),
    math.Point(w * (1 - f), h * (1 - f)),
    math.Point(w * f, h * (1 - f)),
  ]);

  Quad scaled(double s) => Quad([for (final p in points) math.Point(p.x * s, p.y * s)]);
}

/// YUV_420_888 (any pixel stride) -> RGB, rotated upright. Integer maths straight into the buffer.
img.Image yuvToImage(YuvFrame f) {
  final out = img.Image(width: f.width, height: f.height);
  final buf = out.buffer.asUint8List();
  final ch = out.numChannels;
  var o = 0;
  for (var row = 0; row < f.height; row++) {
    final yRow = row * f.yRowStride;
    final uvRow = (row >> 1) * f.uvRowStride;
    for (var col = 0; col < f.width; col++) {
      final yv = f.y[yRow + col];
      final uvi = uvRow + (col >> 1) * f.uvPixelStride;
      final u = f.u[uvi] - 128, v = f.v[uvi] - 128;
      // BT.601 full range, fixed point (x1024).
      var r = yv + ((1436 * v) >> 10);
      var g = yv - ((352 * u + 731 * v) >> 10);
      var b = yv + ((1815 * u) >> 10);
      buf[o] = r < 0 ? 0 : (r > 255 ? 255 : r);
      buf[o + 1] = g < 0 ? 0 : (g > 255 ? 255 : g);
      buf[o + 2] = b < 0 ? 0 : (b > 255 ? 255 : b);
      if (ch == 4) buf[o + 3] = 255;
      o += ch;
    }
  }
  return f.rotationDegrees == 0 ? out : img.copyRotate(out, angle: f.rotationDegrees);
}

/// Finds a receipt-like bright quadrilateral. Falls back to an inset rectangle.
/// Heuristic: Otsu threshold on a small grayscale copy, largest bright blob, extreme corners.
Quad detectCorners(img.Image src) {
  const target = 320;
  final scale = math.max(src.width, src.height) / target;
  final small = img.copyResize(src, width: (src.width / scale).round(), height: (src.height / scale).round());
  final w = small.width, h = small.height;
  final gray = Uint8List(w * h);
  final hist = List<int>.filled(256, 0);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = small.getPixel(x, y);
      final l = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).round().clamp(0, 255);
      gray[y * w + x] = l;
      hist[l]++;
    }
  }
  final t = _otsu(hist, w * h);
  // Largest 4-connected bright component.
  final label = Int32List(w * h);
  var best = 0, bestSize = 0, next = 0;
  final stack = <int>[];
  for (var i = 0; i < w * h; i++) {
    if (gray[i] <= t || label[i] != 0) continue;
    next++;
    var size = 0;
    stack.add(i);
    label[i] = next;
    while (stack.isNotEmpty) {
      final j = stack.removeLast();
      size++;
      final x = j % w, y = j ~/ w;
      for (final n in [if (x > 0) j - 1, if (x < w - 1) j + 1, if (y > 0) j - w, if (y < h - 1) j + w]) {
        if (label[n] == 0 && gray[n] > t) {
          label[n] = next;
          stack.add(n);
        }
      }
    }
    if (size > bestSize) {
      bestSize = size;
      best = next;
    }
  }
  final frac = bestSize / (w * h);
  if (best == 0 || frac < 0.08 || frac > 0.97) return Quad.inset(src.width, src.height);
  var tl = (0, 0, 1 << 30), br = (0, 0, -1), tr = (0, 0, -(1 << 30)), bl = (0, 0, 1 << 30);
  for (var i = 0; i < w * h; i++) {
    if (label[i] != best) continue;
    final x = i % w, y = i ~/ w;
    if (x + y < tl.$3) tl = (x, y, x + y);
    if (x + y > br.$3) br = (x, y, x + y);
    if (x - y > tr.$3) tr = (x, y, x - y);
    if (x - y < bl.$3) bl = (x, y, x - y);
  }
  math.Point<double> p((int, int, int) c) => math.Point(c.$1 * scale, c.$2 * scale);
  return Quad([p(tl), p(tr), p(br), p(bl)]);
}

int _otsu(List<int> hist, int total) {
  var sum = 0.0;
  for (var i = 0; i < 256; i++) {
    sum += i * hist[i];
  }
  var sumB = 0.0, wB = 0, best = 0.0, threshold = 127;
  for (var i = 0; i < 256; i++) {
    wB += hist[i];
    if (wB == 0) continue;
    final wF = total - wB;
    if (wF == 0) break;
    sumB += i * hist[i];
    final mB = sumB / wB, mF = (sum - sumB) / wF;
    final between = wB * wF * (mB - mF) * (mB - mF);
    if (between > best) {
      best = between;
      threshold = i;
    }
  }
  return threshold;
}

/// Perspective-corrects the quad into an upright rectangle.
img.Image rectify(img.Image src, Quad q) {
  final [tl, tr, br, bl] = q.points;
  double d(math.Point<double> a, math.Point<double> b) => a.distanceTo(b);
  final outW = math.max(d(tl, tr), d(bl, br)).round().clamp(16, 4000);
  final outH = math.max(d(tl, bl), d(tr, br)).round().clamp(16, 4000);
  return img.copyRectify(
    src,
    topLeft: img.Point(tl.x, tl.y),
    topRight: img.Point(tr.x, tr.y),
    bottomLeft: img.Point(bl.x, bl.y),
    bottomRight: img.Point(br.x, br.y),
    interpolation: img.Interpolation.linear,
    toImage: img.Image(width: outW, height: outH),
  );
}

class ProcessedReceipt {
  final Uint8List jpeg;
  final Uint8List thumbJpeg;
  const ProcessedReceipt(this.jpeg, this.thumbJpeg);
}

/// Crop + encode. Long edge capped at 2000 px (plenty for OCR); thumbnail 320 px.
ProcessedReceipt finishReceipt(img.Image src, Quad q) {
  var out = rectify(src, q);
  const maxEdge = 2000;
  if (math.max(out.width, out.height) > maxEdge) {
    out = out.width >= out.height ? img.copyResize(out, width: maxEdge) : img.copyResize(out, height: maxEdge);
  }
  final thumb = out.width >= out.height ? img.copyResize(out, width: 320) : img.copyResize(out, height: 320);
  return ProcessedReceipt(img.encodeJpg(out, quality: 85), img.encodeJpg(thumb, quality: 70));
}

/// Largest image we'll decode: a crafted file can claim huge dimensions in a few KB and
/// make the decoder allocate gigabytes (decompression bomb, SECURITY.md T2). 40 MP covers phone cameras.
const maxDecodePixels = 40000000;

/// Decodes only after checking the header's dimensions. Returns null for unknown,
/// corrupt or oversized images instead of throwing or exhausting memory.
img.Image? safeDecode(Uint8List bytes) {
  try {
    final decoder = img.findDecoderForData(bytes);
    if (decoder == null) return null;
    final info = decoder.startDecode(bytes);
    if (info == null || info.width <= 0 || info.height <= 0) return null;
    if (info.width * info.height > maxDecodePixels) return null;
    return decoder.decode(bytes, frame: 0);
  } catch (_) {
    return null;
  }
}

/// Thumbnail for an imported image (no crop).
Uint8List? thumbnailFor(Uint8List bytes) {
  final im = safeDecode(bytes);
  if (im == null) return null;
  final t = im.width >= im.height ? img.copyResize(im, width: 320) : img.copyResize(im, height: 320);
  return img.encodeJpg(t, quality: 70);
}

// ---------- isolate helpers (top-level so closures capture nothing but their arguments) ----------

/// Decoded photo + detected corners + a small in-memory preview JPEG for the crop screen.
class Decoded {
  final img.Image image;
  final Quad quad;
  final Uint8List preview;
  const Decoded(this.image, this.quad, this.preview);
}

Decoded _decoded(img.Image im) {
  final small = im.width > 1200 ? img.copyResize(im, width: 1200) : im;
  return Decoded(im, detectCorners(im), img.encodeJpg(small, quality: 80));
}

Future<Decoded> decodeFrame(YuvFrame f) => Isolate.run(() => _decoded(yuvToImage(f)));

Future<Decoded?> decodeBytes(Uint8List bytes) => Isolate.run(() {
  final im = safeDecode(bytes);
  return im == null ? null : _decoded(img.bakeOrientation(im));
});

Future<ProcessedReceipt> finishInBackground(img.Image src, Quad q) => Isolate.run(() => finishReceipt(src, q));

Future<Uint8List?> thumbnailInBackground(Uint8List bytes) => Isolate.run(() => thumbnailFor(bytes));
