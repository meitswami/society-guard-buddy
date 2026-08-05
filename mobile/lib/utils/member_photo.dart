import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Supports http(s) URLs and data-URL photos stored on `members.photo`.
ImageProvider? memberPhotoProvider(String? photo) {
  if (photo == null) return null;
  final trimmed = photo.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.startsWith('data:image')) {
    final comma = trimmed.indexOf(',');
    if (comma < 0) return null;
    try {
      final bytes = base64Decode(trimmed.substring(comma + 1));
      return MemoryImage(bytes);
    } catch (_) {
      return null;
    }
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
