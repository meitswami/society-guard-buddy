/// Port of `src/lib/emergencyAlert.ts` (+ the `send-emergency-alert` edge function contract).
library;

import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase/db.dart';
import 'notification_compose.dart';
import 'notification_media_storage.dart';
import 'notification_models.dart';

/// Default title (web `useState('🚨 EMERGENCY ALERT')`).
const String kEmergencyDefaultTitle = '🚨 EMERGENCY ALERT';

/// Web `PhotoCapture maxPhotos={4}` + file picker cap.
const int kEmergencyMaxPhotos = 4;

/// Roles accepted by the edge function.
const kEmergencySenderRoles = ['guard', 'resident', 'admin'];

/// One image to attach (camera capture or picked file).
class EmergencyImage {
  const EmergencyImage({required this.bytes, required this.fileName, this.mimeType});

  final Uint8List bytes;
  final String fileName;
  final String? mimeType;
}

class EmergencyAlertResult {
  const EmergencyAlertResult({
    required this.success,
    this.notificationId,
    this.pushSent,
    this.whatsappRecipients,
    this.whatsappSent,
    this.whatsappFailed,
    this.whatsappConfigured,
    this.error,
  });

  final bool success;
  final String? notificationId;
  final int? pushSent;
  final int? whatsappRecipients;
  final int? whatsappSent;
  final int? whatsappFailed;
  final bool? whatsappConfigured;
  final String? error;

  factory EmergencyAlertResult.fromResponse(Map<String, dynamic>? data) {
    int? n(Object? v) => v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'));
    if (data != null && data['error'] != null) {
      return EmergencyAlertResult(success: false, error: data['error'].toString());
    }
    return EmergencyAlertResult(
      success: true,
      notificationId: data?['notification_id']?.toString(),
      pushSent: n(data?['push_sent']),
      whatsappRecipients: n(data?['whatsapp_recipients']),
      whatsappSent: n(data?['whatsapp_sent']),
      whatsappFailed: n(data?['whatsapp_failed']),
      whatsappConfigured: data?['whatsapp_configured'] == true,
    );
  }
}

/// Request body for `send-emergency-alert`.
Map<String, dynamic> buildEmergencyAlertBody({
  required String societyId,
  required String title,
  required String message,
  required String senderRole,
  required String senderName,
  String? senderFlatNumber,
  List<NotificationMediaItem> media = const [],
}) =>
    {
      'society_id': societyId,
      'title': title,
      'message': message,
      'sender_role': senderRole,
      'sender_name': senderName,
      'sender_flat_number': senderFlatNumber,
      'media_items': media.map((m) => m.toJson()).toList(),
    };

class EmergencyAlertService {
  const EmergencyAlertService();

  /// Web `uploadEmergencyMedia`: images only, ≤ 12 MB each, path
  /// `emergency/{uuid}/{timestamp}_{name}` in `notification-media`. Failed uploads are skipped.
  Future<List<NotificationMediaItem>> uploadMedia(List<EmergencyImage> images) async {
    final items = <NotificationMediaItem>[];
    for (final img in images) {
      final kind = fileMediaKind(mimeType: img.mimeType, fileName: img.fileName);
      if (kind == null) continue;
      if (kind == 'image' && img.bytes.length > kMaxNotificationImageBytes) continue;
      final safe = sanitizeStorageFileName(img.fileName);
      final path = 'emergency/${const Uuid().v4()}/${DateTime.now().millisecondsSinceEpoch}_$safe';
      try {
        final url = await uploadToNotificationMedia(
          path,
          img.bytes,
          contentType: guessContentType(img.fileName, mimeType: img.mimeType),
        );
        items.add(NotificationMediaItem(url: url, kind: kind));
      } catch (_) {
        // Web `uploadToNotificationMedia` returns null on error and the item is skipped.
      }
    }
    return items;
  }

  /// Web `sendEmergencyAlert`.
  Future<EmergencyAlertResult> send({
    required String societyId,
    required String title,
    required String message,
    required String senderRole,
    required String senderName,
    String? senderFlatNumber,
    List<EmergencyImage> images = const [],
  }) async {
    if (!dbReady) return const EmergencyAlertResult(success: false, error: 'Supabase not configured');
    try {
      final media = await uploadMedia(images);
      final data = await invokeFunction(
        'send-emergency-alert',
        buildEmergencyAlertBody(
          societyId: societyId,
          title: title,
          message: message,
          senderRole: senderRole,
          senderName: senderName,
          senderFlatNumber: senderFlatNumber,
          media: media,
        ),
      );
      return EmergencyAlertResult.fromResponse(data);
    } on FunctionException catch (e) {
      return EmergencyAlertResult(success: false, error: commsErrorMessage(e));
    } catch (e) {
      return EmergencyAlertResult(success: false, error: commsErrorMessage(e));
    }
  }
}

/// Success toast text (web `Emergency alert sent · Push: n · WhatsApp: a/b`).
String emergencySentSummary(EmergencyAlertResult r, {required String sentLabel, required String waNotConfigured}) {
  final wa = (r.whatsappConfigured ?? false)
      ? ' · WhatsApp: ${r.whatsappSent ?? 0}/${r.whatsappRecipients ?? 0}'
      : ' · $waNotConfigured';
  return '$sentLabel · Push: ${r.pushSent ?? 0}$wa';
}
