import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../../../core/theme/app_tokens.dart';

/// Decoded data-URL images, kept so list rebuilds do not decode base64 again.
final LinkedHashMap<String, MemoryImage> _dataUrlCache = LinkedHashMap();
const _cacheLimit = 120;

/// Image provider for a stored photo: `data:image/...;base64,…` (web `PhotoCapture`) or http(s) URL.
ImageProvider? gateImageProvider(String? src) {
  final s = src?.trim() ?? '';
  if (s.isEmpty) return null;
  if (s.startsWith('data:image')) {
    final hit = _dataUrlCache.remove(s);
    if (hit != null) {
      _dataUrlCache[s] = hit;
      return hit;
    }
    final comma = s.indexOf(',');
    if (comma < 0) return null;
    try {
      final provider = MemoryImage(base64Decode(s.substring(comma + 1)));
      _dataUrlCache[s] = provider;
      if (_dataUrlCache.length > _cacheLimit) _dataUrlCache.remove(_dataUrlCache.keys.first);
      return provider;
    } catch (_) {
      return null;
    }
  }
  if (s.startsWith('http://') || s.startsWith('https://')) return CachedNetworkImageProvider(s);
  return null;
}

/// Square / round thumbnail of a stored photo with an initial-letter fallback.
class GatePhoto extends StatelessWidget {
  const GatePhoto({super.key, required this.src, this.size = 40, this.round = true, this.fallbackText, this.fallbackIcon});

  final String? src;
  final double size;
  final bool round;
  final String? fallbackText;
  final IconData? fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final provider = gateImageProvider(src);
    final radius = round ? BorderRadius.circular(size) : BorderRadius.circular(AppTokens.radiusSm);
    final initial = (fallbackText ?? '').trim();
    return ClipRRect(
      borderRadius: radius,
      child: Container(
        width: size,
        height: size,
        color: t.secondary,
        alignment: Alignment.center,
        child: provider != null
            ? Image(
                image: provider,
                width: size,
                height: size,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => Icon(fallbackIcon ?? Icons.person_outline, size: size * 0.45, color: t.mutedForeground),
              )
            : (initial.isNotEmpty
                ? Text(initial[0].toUpperCase(),
                    style: TextStyle(fontSize: size * 0.35, fontWeight: FontWeight.w700, color: t.mutedForeground))
                : Icon(fallbackIcon ?? Icons.person_outline, size: size * 0.45, color: t.mutedForeground)),
      ),
    );
  }
}

/// Web `compressImage(dataUrl, 800, 0.7)`: longest side ≤ [maxSide], JPEG at [quality] → data URL.
Future<String> compressToJpegDataUrl(Uint8List bytes, {int maxSide = 800, int quality = 70}) =>
    compute(_compressWorker, (bytes, maxSide, quality));

String _compressWorker((Uint8List, int, int) args) {
  final (bytes, maxSide, quality) = args;
  return 'data:image/jpeg;base64,${base64Encode(compressJpegBytes(bytes, maxSide: maxSide, quality: quality))}';
}

/// Synchronous resize + JPEG encode (used inside the isolate; exposed for tests).
Uint8List compressJpegBytes(Uint8List bytes, {int maxSide = 800, int quality = 70}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('Unsupported image');
  var image = img.bakeOrientation(decoded);
  final ratio = [maxSide / image.width, maxSide / image.height, 1.0].reduce((a, b) => a < b ? a : b);
  if (ratio < 1) {
    image = img.copyResize(
      image,
      width: (image.width * ratio).round(),
      height: (image.height * ratio).round(),
      interpolation: img.Interpolation.average,
    );
  }
  return img.encodeJpg(image, quality: quality);
}
