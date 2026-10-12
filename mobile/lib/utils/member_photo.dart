import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Decoded data-URL images are cached so list rebuilds reuse the same [MemoryImage]
/// (a fresh provider per build would make Flutter decode the photo again and flicker).
final LinkedHashMap<String, MemoryImage> _dataUrlCache = LinkedHashMap();
const _maxCachedDataUrls = 300;

/// Bytes of a `data:image/...;base64,...` URL, or null.
Uint8List? dataUrlBytes(String? value) {
  final s = value?.trim() ?? '';
  if (!s.startsWith('data:')) return null;
  final comma = s.indexOf(',');
  if (comma < 0) return null;
  try {
    return base64Decode(s.substring(comma + 1).replaceAll(RegExp(r'\s'), ''));
  } catch (_) {
    return null;
  }
}

/// True for `data:image/...` URLs (photos stored inline in table rows, like the web app).
bool isDataImageUrl(String? value) => (value ?? '').trim().startsWith('data:image');

/// Supports http(s) URLs and data-URL photos stored on `members.photo`.
ImageProvider? memberPhotoProvider(String? photo) {
  if (photo == null) return null;
  final trimmed = photo.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.startsWith('data:image')) {
    final cached = _dataUrlCache.remove(trimmed);
    if (cached != null) {
      _dataUrlCache[trimmed] = cached; // move to most-recent
      return cached;
    }
    final bytes = dataUrlBytes(trimmed);
    if (bytes == null || bytes.isEmpty) return null;
    final img = MemoryImage(bytes);
    _dataUrlCache[trimmed] = img;
    while (_dataUrlCache.length > _maxCachedDataUrls) {
      _dataUrlCache.remove(_dataUrlCache.keys.first);
    }
    return img;
  }
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return CachedNetworkImageProvider(trimmed);
  }
  return null;
}

Widget memberPhotoAvatar({
  required String name,
  String? photo,
  Color? backgroundColor,
  Color? foregroundColor,
  double radius = 22,
}) {
  final provider = memberPhotoProvider(photo);
  final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
  return CircleAvatar(
    radius: radius,
    backgroundColor: backgroundColor,
    backgroundImage: provider,
    child: provider == null
        ? Text(
            initial,
            style: TextStyle(
              color: foregroundColor,
              fontWeight: FontWeight.w600,
              fontSize: radius * 0.75,
            ),
          )
        : null,
  );
}
