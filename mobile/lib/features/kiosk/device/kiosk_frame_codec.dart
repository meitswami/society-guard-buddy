import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Raw pixel layout of a streamed camera frame.
enum KioskFrameFormat { nv21, bgra8888 }

/// A copy of one camera frame (safe to send to another isolate).
class KioskFrame {
  const KioskFrame({
    required this.bytes,
    required this.width,
    required this.height,
    required this.bytesPerRow,
    required this.format,
    required this.rotation,
  });

  final Uint8List bytes;
  final int width;
  final int height;
  final int bytesPerRow;
  final KioskFrameFormat format;

  /// Clockwise degrees that make the frame upright (same value ML Kit gets).
  final int rotation;
}

/// JPEG data URL of [frame], upright, max 640 px, quality 72 — web `captureFrame`
/// (`canvas.toDataURL('image/jpeg', 0.72)`). Runs off the UI isolate.
Future<String?> encodeKioskFrame(KioskFrame frame) => Isolate.run(() => _encode(frame));

/// JPEG data URL from a JPEG file's bytes (fallback via `takePicture`).
Future<String?> encodeKioskJpeg(Uint8List jpeg) => Isolate.run(() {
      final decoded = img.decodeJpg(jpeg);
      if (decoded == null) return null;
      return _toDataUrl(img.bakeOrientation(decoded));
    });

String? _encode(KioskFrame f) {
  final image = switch (f.format) {
    KioskFrameFormat.nv21 => _fromNv21(f),
    KioskFrameFormat.bgra8888 => _fromBgra(f),
  };
  if (image == null) return null;
  final upright = f.rotation % 360 == 0 ? image : img.copyRotate(image, angle: f.rotation);
  return _toDataUrl(upright);
}

String _toDataUrl(img.Image image) {
  final ratio = math.min(1.0, math.min(640 / image.width, 640 / image.height));
  final sized = ratio < 1
      ? img.copyResize(image,
          width: (image.width * ratio).round(),
          height: (image.height * ratio).round(),
          interpolation: img.Interpolation.average)
      : image;
  final jpeg = img.encodeJpg(sized, quality: 72);
  return 'data:image/jpeg;base64,${base64Encode(jpeg)}';
}

img.Image? _fromNv21(KioskFrame f) {
  final w = f.width, h = f.height;
  final stride = f.bytesPerRow <= 0 ? w : f.bytesPerRow;
  final ySize = stride * h;
  if (f.bytes.length < ySize + (stride * (h ~/ 2))) return null;
  final out = img.Image(width: w, height: h);
  final src = f.bytes;
  for (var y = 0; y < h; y++) {
    final uvRow = ySize + (y >> 1) * stride;
    for (var x = 0; x < w; x++) {
      final yy = src[y * stride + x];
      final uvIndex = uvRow + (x & ~1);
      final v = src[uvIndex] - 128;
      final u = src[uvIndex + 1] - 128;
      final r = (yy + 1.402 * v).round().clamp(0, 255);
      final g = (yy - 0.344136 * u - 0.714136 * v).round().clamp(0, 255);
      final b = (yy + 1.772 * u).round().clamp(0, 255);
      out.setPixelRgb(x, y, r, g, b);
    }
  }
  return out;
}

img.Image? _fromBgra(KioskFrame f) {
  final stride = f.bytesPerRow <= 0 ? f.width * 4 : f.bytesPerRow;
  if (f.bytes.length < stride * f.height) return null;
  final out = img.Image(width: f.width, height: f.height);
  final src = f.bytes;
  for (var y = 0; y < f.height; y++) {
    final row = y * stride;
    for (var x = 0; x < f.width; x++) {
      final i = row + x * 4;
      out.setPixelRgb(x, y, src[i + 2], src[i + 1], src[i]);
    }
  }
  return out;
}
