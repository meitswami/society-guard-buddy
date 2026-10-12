import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase/db.dart';
import 'resident_media.dart';

/// Limits from web `ResidentFeedbackForm.tsx`.
const int kFeedbackMaxAttachments = 6;
const int kFeedbackMaxImageBytes = 12 * 1024 * 1024;
const int kFeedbackMaxVideoBytes = 50 * 1024 * 1024;
const int kFeedbackMaxAudioBytes = 15 * 1024 * 1024;

/// Why an attachment was refused (web toasts).
enum FeedbackFileIssue { notMedia, imageTooLarge, videoTooLarge, uploadFailed }

class FeedbackUploadReport {
  FeedbackUploadReport();
  final items = <Map<String, String>>[];
  final issues = <(String, FeedbackFileIssue)>[];
}

/// Feedback → `support_tickets` + `send-feedback-alert` (web `ResidentFeedbackForm` submit).
class ResidentFeedbackRepository {
  const ResidentFeedbackRepository();

  static const _bucket = 'notification-media';

  static FeedbackFileIssue? checkAttachment(PickedMedia f) {
    if (!f.isImage && !f.isVideo) return FeedbackFileIssue.notMedia;
    if (f.isImage && f.bytes.length > kFeedbackMaxImageBytes) return FeedbackFileIssue.imageTooLarge;
    if (f.isVideo && f.bytes.length > kFeedbackMaxVideoBytes) return FeedbackFileIssue.videoTooLarge;
    return null;
  }

  /// Web `uploadFiles` — `feedback/<residentId>/<uuid>_<ms>_<name>`.
  Future<FeedbackUploadReport> uploadFiles(List<PickedMedia> files, String subfolder) async {
    final report = FeedbackUploadReport();
    for (final f in files) {
      final issue = checkAttachment(f);
      if (issue != null) {
        report.issues.add((f.name, issue));
        continue;
      }
      final safe = f.name.replaceAll(RegExp(r'[^\w.-]'), '_');
      final path = 'feedback/$subfolder/${const Uuid().v4()}_${DateTime.now().millisecondsSinceEpoch}_$safe';
      try {
        await db.storage.from(_bucket).uploadBinary(
              path,
              f.bytes,
              fileOptions: FileOptions(cacheControl: '3600', upsert: false, contentType: f.mimeType),
            );
        report.items.add({'url': db.storage.from(_bucket).getPublicUrl(path), 'kind': f.isImage ? 'image' : 'video'});
      } catch (_) {
        report.issues.add((f.name, FeedbackFileIssue.uploadFailed));
      }
    }
    return report;
  }

  /// Web `uploadAudioBlob` — `feedback/<residentId>/voice_<ms>.m4a`. Throws on failure.
  Future<String> uploadVoice(Uint8List bytes, String subfolder) async {
    final path = 'feedback/$subfolder/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await db.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false, contentType: 'audio/mp4'),
        );
    return db.storage.from(_bucket).getPublicUrl(path);
  }

  Future<String> insertTicket({
    required String societyId,
    required String societyName,
    required String residentId,
    required String residentName,
    required String flatNumber,
    required String message,
    required List<Map<String, String>> mediaItems,
    String? audioUrl,
  }) async {
    final row = await db
        .from('support_tickets')
        .insert({
          'society_id': societyId,
          'society_name': societyName,
          'submitter_kind': 'resident',
          'submitter_resident_id': residentId,
          'submitter_name': residentName,
          'flat_number': flatNumber,
          'message': message.isEmpty ? '(voice / attachments only)' : message,
          'media_items': mediaItems,
          'audio_url': audioUrl,
        })
        .select('id')
        .single();
    final id = row['id'].toString();
    try {
      await invokeFunction('send-feedback-alert', {'ticket_id': id});
    } catch (_) {
      // Email alert is best-effort (web logs a warning).
    }
    return id;
  }
}
