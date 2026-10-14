import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/supabase/db.dart';

/// A file picked on the phone (camera / gallery / files) ready to upload.
class PickedAttachment {
  const PickedAttachment({required this.name, required this.bytes, required this.mimeType});

  final String name;
  final Uint8List bytes;
  final String mimeType;

  int get size => bytes.length;

  bool get isImage => mimeType.startsWith('image/');
  bool get isPdf => mimeType == 'application/pdf';
  bool get isAudio => mimeType.startsWith('audio/');
}

/// Port of `src/lib/notificationMediaStorage.ts` (bucket `notification-media`).
abstract final class EventsStorage {
  static const bucket = 'notification-media';

  /// Max upload size used across the web forms (8 MB).
  static const maxBytes = 8 * 1024 * 1024;

  static String sanitizeStorageFileName(String name) => name.replaceAll(RegExp(r'[^\w.-]'), '_');

  static Future<String> _upload(String path, PickedAttachment file) async {
    await db.storage.from(bucket).uploadBinary(
          path,
          file.bytes,
          fileOptions: FileOptions(cacheControl: '3600', upsert: false, contentType: file.mimeType),
        );
    return db.storage.from(bucket).getPublicUrl(path);
  }

  /// `uploadExpenseBill(groupId, file)` → `expense-bills/{groupId}/{uuid}_{name}`.
  static Future<String> uploadExpenseBill(String groupId, PickedAttachment file) =>
      _upload('expense-bills/$groupId/${const Uuid().v4()}_${sanitizeStorageFileName(file.name)}', file);

  /// `uploadContributionReceipt(file)` → `event-contributions/{uuid}_{name}`.
  static Future<String> uploadContributionReceipt(PickedAttachment file) =>
      _upload('event-contributions/${const Uuid().v4()}_${sanitizeStorageFileName(file.name)}', file);
}

/// MIME type from a file name (the web reads `File.type`).
String mimeTypeForFileName(String name) {
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  return switch (ext) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'bmp' => 'image/bmp',
    'heic' => 'image/heic',
    'heif' => 'image/heif',
    'svg' => 'image/svg+xml',
    'pdf' => 'application/pdf',
    'mp3' => 'audio/mpeg',
    'm4a' => 'audio/mp4',
    'aac' => 'audio/aac',
    'wav' => 'audio/wav',
    'ogg' || 'oga' => 'audio/ogg',
    'opus' => 'audio/opus',
    'amr' => 'audio/amr',
    'webm' => 'audio/webm',
    'doc' => 'application/msword',
    'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls' => 'application/vnd.ms-excel',
    'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'csv' => 'text/csv',
    _ => 'application/octet-stream',
  };
}
