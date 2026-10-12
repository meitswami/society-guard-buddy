import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../../core/ui/ui.dart';

/// A file chosen on the device (receipt screenshot / PDF, feedback media).
class PickedMedia {
  const PickedMedia({required this.bytes, required this.name, required this.mimeType});

  final Uint8List bytes;
  final String name;
  final String mimeType;

  bool get isImage => mimeType.startsWith('image/');
  bool get isVideo => mimeType.startsWith('video/');
  bool get isPdf => mimeType == 'application/pdf';
}

String mimeFromName(String name, {String fallback = 'application/octet-stream'}) {
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  return switch (ext) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    'heic' => 'image/heic',
    'heif' => 'image/heif',
    'pdf' => 'application/pdf',
    'mp4' => 'video/mp4',
    'mov' => 'video/quicktime',
    '3gp' => 'video/3gpp',
    'webm' => 'video/webm',
    'mkv' => 'video/x-matroska',
    'm4a' => 'audio/mp4',
    _ => fallback,
  };
}

Uint8List _reencodeJpeg(List<Object> args) {
  final bytes = args[0] as Uint8List;
  final maxSide = args[1] as int;
  final quality = args[2] as int;
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;
  var im = decoded;
  if (im.width > maxSide || im.height > maxSide) {
    im = im.width >= im.height ? img.copyResize(im, width: maxSide) : img.copyResize(im, height: maxSide);
  }
  return Uint8List.fromList(img.encodeJpg(im, quality: quality));
}

/// Camera / gallery helpers. Photos are stored like the web (data URLs on `members` /
/// `member_documents`), compressed to JPEG so rows stay small.
abstract final class ResidentMedia {
  static final _picker = ImagePicker();

  /// Camera or gallery choice sheet; null when dismissed.
  static Future<ImageSource?> chooseSource(BuildContext context) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(ctx.tr('Take photo', 'फ़ोटो लें')),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(ctx.tr('Choose from gallery', 'गैलरी से चुनें')),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  /// Picks one image and returns a `data:image/jpeg;base64,…` URL.
  /// [maxSide] 800 / q70 for face photos (web `PhotoCapture`), larger for ID documents.
  static Future<String?> pickImageDataUrl(BuildContext context, {int maxSide = 800, int quality = 70}) async {
    final source = await chooseSource(context);
    if (source == null) return null;
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: maxSide.toDouble(),
        maxHeight: maxSide.toDouble(),
        imageQuality: quality,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (file == null) return null;
      final raw = await file.readAsBytes();
      final jpeg = await compute(_reencodeJpeg, <Object>[raw, maxSide, quality]);
      return 'data:image/jpeg;base64,${base64Encode(jpeg)}';
    } catch (_) {
      if (context.mounted) {
        AppFeedback.toast(context, context.tr('Could not open the camera / gallery', 'कैमरा / गैलरी नहीं खुल सकी'),
            tone: BadgeTone.alert);
      }
      return null;
    }
  }

  /// Payment proof (web `accept="image/*,application/pdf"`): camera, gallery or a PDF file.
  static Future<PickedMedia?> pickReceipt(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(ctx.tr('Take photo', 'फ़ोटो लें')),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(ctx.tr('Screenshot from gallery', 'गैलरी से स्क्रीनशॉट')),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: Text(ctx.tr('PDF / image file', 'PDF / चित्र फ़ाइल')),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return null;
    try {
      if (choice == 'file') {
        final res = await FilePicker.pickFiles(
            type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'], withData: true);
        final f = res?.files.firstOrNull;
        if (f == null || f.bytes == null) return null;
        return PickedMedia(bytes: f.bytes!, name: f.name, mimeType: mimeFromName(f.name));
      }
      final file = await _picker.pickImage(
        source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
      if (file == null) return null;
      final bytes = await file.readAsBytes();
      return PickedMedia(
          bytes: bytes, name: file.name, mimeType: file.mimeType ?? mimeFromName(file.name, fallback: 'image/jpeg'));
    } catch (_) {
      return null;
    }
  }

  /// Feedback attachments (web `accept="image/*,video/*" multiple`).
  static Future<List<PickedMedia>> pickFeedbackMedia(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(ctx.tr('Take photo', 'फ़ोटो लें')),
              onTap: () => Navigator.pop(ctx, 'photo'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: Text(ctx.tr('Record video', 'वीडियो रिकॉर्ड करें')),
              onTap: () => Navigator.pop(ctx, 'video'),
            ),
            ListTile(
              leading: const Icon(Icons.perm_media_outlined),
              title: Text(ctx.tr('Photos / videos from gallery', 'गैलरी से फ़ोटो / वीडियो')),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return const [];
    try {
      final files = <XFile>[];
      if (choice == 'photo') {
        final f =
            await _picker.pickImage(source: ImageSource.camera, maxWidth: 1920, maxHeight: 1920, imageQuality: 85);
        if (f != null) files.add(f);
      } else if (choice == 'video') {
        final f = await _picker.pickVideo(source: ImageSource.camera, maxDuration: const Duration(minutes: 3));
        if (f != null) files.add(f);
      } else {
        files.addAll(await _picker.pickMultipleMedia(maxWidth: 1920, maxHeight: 1920, imageQuality: 85));
      }
      final out = <PickedMedia>[];
      for (final f in files) {
        final mime = f.mimeType ?? mimeFromName(f.name);
        out.add(PickedMedia(bytes: await f.readAsBytes(), name: f.name, mimeType: mime));
      }
      return out;
    } catch (_) {
      return const [];
    }
  }
}
