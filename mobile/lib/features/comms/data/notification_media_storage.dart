/// Port of `src/lib/notificationMediaStorage.ts` (bucket `notification-media`).
library;

import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/db.dart';

const String kNotificationMediaBucket = 'notification-media';

/// Web `sanitizeStorageFileName`: every character outside `[A-Za-z0-9_.-]` becomes `_`.
String sanitizeStorageFileName(String name) =>
    name.replaceAll(RegExp(r'[^\w.-]'), '_');

/// Upload bytes to `notification-media` and return the public URL (web
/// `uploadToNotificationMedia`). Throws [StorageException] on failure.
Future<String> uploadToNotificationMedia(
  String path,
  Uint8List bytes, {
  String? contentType,
  bool upsert = false,
  String cacheControl = '3600',
}) async {
  final bucket = db.storage.from(kNotificationMediaBucket);
  await bucket.uploadBinary(
    path,
    bytes,
    fileOptions: FileOptions(
        cacheControl: cacheControl, upsert: upsert, contentType: contentType),
  );
  return bucket.getPublicUrl(path);
}

/// Readable message for storage / database errors.
String commsErrorMessage(Object e) {
  if (e is StorageException) return e.message;
  if (e is PostgrestException) return e.message;
  if (e is FunctionException) {
    final d = e.details;
    if (d is Map && d['error'] != null) return d['error'].toString();
    return e.reasonPhrase ?? 'Request failed (${e.status})';
  }
  final s = e.toString();
  return s.startsWith('Exception: ') ? s.substring(11) : s;
}
