import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase/db.dart';
import '../logic/js_compat.dart';
import '../logic/society_form.dart';

/// An image chosen on the phone, kept in memory until "Save" (web `File`).
class PickedImage {
  const PickedImage(
      {required this.name, required this.bytes, required this.mimeType});

  final String name;
  final Uint8List bytes;
  final String mimeType;

  int get size => bytes.length;

  /// Web `file.type.startsWith('image/')`.
  bool get isImage => mimeType.startsWith('image/');
}

const Map<String, String> _kImageMimeByExt = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
  'gif': 'image/gif',
  'heic': 'image/heic',
  'heif': 'image/heif',
  'bmp': 'image/bmp',
  'svg': 'image/svg+xml',
};

/// MIME type from the picker, falling back to the file extension.
String mimeForFile(String name, String? pickerMime) {
  if (pickerMime != null && pickerMime.isNotEmpty) return pickerMime;
  final dot = name.lastIndexOf('.');
  final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  return _kImageMimeByExt[ext] ?? 'application/octet-stream';
}

Future<PickedImage> _fromXFile(XFile f) async {
  final name = f.name.isNotEmpty ? f.name : f.path.split('/').last;
  return PickedImage(
      name: name,
      bytes: await f.readAsBytes(),
      mimeType: mimeForFile(name, f.mimeType));
}

/// Image picking with sensible phone limits (camera photos are often > 8 MB).
abstract final class SuperadminImagePicker {
  static final ImagePicker _picker = ImagePicker();

  /// One image; [maxSide] downsizes large photos (null keeps the original file).
  static Future<PickedImage?> pickOne(
      {ImageSource source = ImageSource.gallery,
      double? maxSide,
      int? quality}) async {
    final f = await _picker.pickImage(
        source: source,
        maxWidth: maxSide,
        maxHeight: maxSide,
        imageQuality: quality);
    if (f == null) return null;
    return _fromXFile(f);
  }

  /// Several gallery images (society photos).
  static Future<List<PickedImage>> pickMany(
      {double? maxSide = 2048, int? quality = 88}) async {
    final files = await _picker.pickMultiImage(
        maxWidth: maxSide, maxHeight: maxSide, imageQuality: quality);
    return [for (final f in files) await _fromXFile(f)];
  }
}

/// Storage uploads with the same buckets, object paths and limits as the web.
class SuperadminUploads {
  SuperadminUploads({void Function(String message)? onError})
      : _onError = onError ?? ((_) {});

  final void Function(String message) _onError;
  static const _uuid = Uuid();

  Future<String?> _upload(
      String bucket, String path, PickedImage file, String failLabel) async {
    try {
      await db.storage.from(bucket).uploadBinary(
            path,
            file.bytes,
            fileOptions: FileOptions(
                cacheControl: '3600',
                upsert: false,
                contentType: file.mimeType),
          );
      return db.storage.from(bucket).getPublicUrl(path);
    } catch (_) {
      _onError('$failLabel: ${file.name}');
      return null;
    }
  }

  /// Web `uploadSocietyLogo` → `society-photos/<societyId>/logo_<uuid>_<name>`.
  Future<String?> societyLogo(String societyId, PickedImage file) async {
    if (!file.isImage) {
      _onError('Not an image: ${file.name}');
      return null;
    }
    if (file.size > kMaxLogoBytes) {
      _onError('Logo too large (max 2 MB): ${file.name}');
      return null;
    }
    final path =
        '$societyId/logo_${_uuid.v4()}_${safeStorageFileName(file.name)}';
    return _upload('society-photos', path, file, 'Logo upload failed');
  }

  /// Web `uploadSocietyLetterhead` → `society-photos/<societyId>/letterhead_<uuid>_<name>` (max 4 MB).
  Future<String?> societyLetterhead(String societyId, PickedImage file) async {
    if (!file.isImage) {
      _onError('Not an image: ${file.name}');
      return null;
    }
    if (file.size > kMaxLetterheadBytes) {
      _onError('Letterhead too large (max 4 MB): ${file.name}');
      return null;
    }
    final path =
        '$societyId/letterhead_${_uuid.v4()}_${safeStorageFileName(file.name)}';
    return _upload('society-photos', path, file, 'Letterhead upload failed');
  }

  /// Web `uploadPlatformLogo` → `platform-assets/logo/<uuid>_<name>` (max 2 MB).
  Future<String?> platformLogo(PickedImage file) async {
    if (!file.isImage) {
      _onError('Not an image: ${file.name}');
      return null;
    }
    if (file.size > kMaxLogoBytes) {
      _onError('Logo too large (max 2 MB): ${file.name}');
      return null;
    }
    final path = 'logo/${_uuid.v4()}_${safeStorageFileName(file.name)}';
    return _upload('platform-assets', path, file, 'Logo upload failed');
  }

  /// Web `uploadSocietyPhotos` → `society-photos/<societyId>/<uuid>_<name>` (max 8 MB each).
  Future<List<String>> societyPhotos(
      String societyId, List<PickedImage> files) async {
    final urls = <String>[];
    for (final file in files) {
      if (!file.isImage) {
        _onError('Not an image: ${file.name}');
        continue;
      }
      if (file.size > kMaxSocietyPhotoBytes) {
        _onError('Image too large (max 8 MB): ${file.name}');
        continue;
      }
      final path = '$societyId/${_uuid.v4()}_${safeStorageFileName(file.name)}';
      final url = await _upload('society-photos', path, file, 'Upload failed');
      if (url != null) urls.add(url);
    }
    return urls;
  }
}
