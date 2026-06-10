import 'dart:typed_data';

import '../core/config/env.dart';
import '../core/supabase/supabase_bootstrap.dart';
import 'media_upload_service.dart';

class FeedbackService {
  final _media = MediaUploadService();

  Future<void> submitResidentFeedback({
    required String societyId,
    required String societyName,
    required String residentId,
    required String residentName,
    required String flatNumber,
    required String message,
    List<({Uint8List bytes, String fileName})> images = const [],
    Uint8List? audioBytes,
    String audioFileName = 'voice.m4a',
  }) async {
    if (!Env.isConfigured) return;

    final text = message.trim();
    if (text.isEmpty && images.isEmpty && audioBytes == null) {
      throw StateError('Please enter feedback, attach a photo, or record voice');
    }

    final mediaItems = await _media.uploadImages(images, 'feedback/$societyId');

    String? audioUrl;
    if (audioBytes != null && audioBytes.isNotEmpty) {
      audioUrl = await _media.uploadImage(
        bytes: audioBytes,
        folder: 'feedback/$societyId',
        fileName: audioFileName,
        mimeType: 'audio/mp4',
      );
    }

    final row = await SupabaseBootstrap.client
        .from('support_tickets')
        .insert({
          'society_id': societyId,
          'society_name': societyName,
          'submitter_kind': 'resident',
          'submitter_resident_id': residentId,
          'submitter_name': residentName,
          'flat_number': flatNumber,
          'message': text.isEmpty ? '(voice / attachments only)' : text,
          'media_items': mediaItems,
          if (audioUrl != null) 'audio_url': audioUrl,
        })
        .select('id')
        .single();

    final ticketId = row['id'] as String?;
    if (ticketId != null) {
      try {
        await SupabaseBootstrap.client.functions.invoke(
          'send-feedback-alert',
          body: {'ticket_id': ticketId},
        );
      } catch (_) {
        // Non-blocking — ticket is already saved.
      }
    }
  }
}
