import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../../../core/ui/ui.dart';

/// A picked (and compressed) image.
class PickedImage {
  const PickedImage({required this.bytes, required this.name});

  final Uint8List bytes;
  final String name;

  /// `data:image/jpeg;base64,…` (how the web stores member photos / IDs in table rows).
  String get dataUrl => 'data:image/jpeg;base64,${base64Encode(bytes)}';
}

Uint8List _compress((Uint8List, int, int) args) {
  final (bytes, maxSide, quality) = args;
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;
  var out = decoded;
  final longest = decoded.width > decoded.height ? decoded.width : decoded.height;
  if (longest > maxSide) {
    out = decoded.width >= decoded.height
        ? img.copyResize(decoded, width: maxSide)
        : img.copyResize(decoded, height: maxSide);
  }
  return Uint8List.fromList(img.encodeJpg(out, quality: quality));
}

/// Camera / gallery picker with JPEG compression (max side + quality) done off the UI thread.
abstract final class PeopleImagePicker {
  static final _picker = ImagePicker();

  /// Ask camera vs gallery, then pick.
  static Future<PickedImage?> pick(
    BuildContext context, {
    int maxSide = 800,
    int quality = 70,
    String? title,
  }) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(title, style: AppText.sectionTitle(ctx)),
              ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(ctx.tr('Take photo', 'फ़ोटो लें')),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(ctx.tr('Gallery', 'गैलरी')),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return null;
    return pickFrom(source, maxSide: maxSide, quality: quality);
  }

  static Future<PickedImage?> pickFrom(ImageSource source, {int maxSide = 800, int quality = 70}) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: maxSide.toDouble(),
      maxHeight: maxSide.toDouble(),
      imageQuality: quality,
    );
    if (file == null) return null;
    final raw = await file.readAsBytes();
    final bytes = await compute(_compress, (raw, maxSide, quality));
    final base = file.name.contains('.') ? file.name.substring(0, file.name.lastIndexOf('.')) : file.name;
    return PickedImage(bytes: bytes, name: '${base.isEmpty ? 'photo' : base}.jpg');
  }
}
