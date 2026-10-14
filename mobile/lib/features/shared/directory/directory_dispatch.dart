import 'package:flutter/foundation.dart';

import '../../../core/format/formatters.dart';
import '../../../core/supabase/db.dart';

/// Port of web `src/lib/dispatchDirectoryChannels.ts` — best-effort WhatsApp + email
/// despatch via the directory contacts (edge function `dispatch-directory-message`).
/// Does not create in-app notifications or push — callers keep those paths.
///
/// Usage (e.g. after posting a notice):
/// ```dart
/// await dispatchDirectoryChannels(
///   societyId: sid, title: title, message: body,
///   channels: const DirectoryDispatchChannels(whatsapp: true, email: true),
///   target: DirectoryDispatchTarget.flats(['101', '102']),
/// );
/// ```
class DirectoryDispatchChannels {
  const DirectoryDispatchChannels({this.whatsapp = false, this.email = false});

  final bool whatsapp;
  final bool email;

  bool get any => whatsapp || email;
}

/// `{ type: 'all' } | { type: 'flat', flatNumbers } | { type: 'user', residentUserIds }`.
class DirectoryDispatchTarget {
  const DirectoryDispatchTarget._(
      this.type, this.flatNumbers, this.residentUserIds);

  const DirectoryDispatchTarget.all() : this._('all', const [], const []);

  const DirectoryDispatchTarget.flats(List<String> flatNumbers)
      : this._('flat', flatNumbers, const []);

  const DirectoryDispatchTarget.users(List<String> residentUserIds)
      : this._('user', const [], residentUserIds);

  final String type;
  final List<String> flatNumbers;
  final List<String> residentUserIds;
}

class DirectoryDispatchResult {
  const DirectoryDispatchResult({
    required this.whatsappSent,
    required this.whatsappFailed,
    required this.emailSent,
    required this.emailFailed,
    this.whatsappRecipients,
    this.emailRecipients,
    this.whatsappConfigured,
    this.emailConfigured,
    this.skipped,
  });

  final int whatsappSent;
  final int whatsappFailed;
  final int emailSent;
  final int emailFailed;
  final int? whatsappRecipients;
  final int? emailRecipients;
  final bool? whatsappConfigured;
  final bool? emailConfigured;
  final String? skipped;

  factory DirectoryDispatchResult.fromJson(Map<String, dynamic> j) =>
      DirectoryDispatchResult(
        whatsappSent: asInt(j['whatsapp_sent']),
        whatsappFailed: asInt(j['whatsapp_failed']),
        emailSent: asInt(j['email_sent']),
        emailFailed: asInt(j['email_failed']),
        whatsappRecipients: j['whatsapp_recipients'] == null
            ? null
            : asInt(j['whatsapp_recipients']),
        emailRecipients:
            j['email_recipients'] == null ? null : asInt(j['email_recipients']),
        whatsappConfigured: j['whatsapp_configured'] as bool?,
        emailConfigured: j['email_configured'] as bool?,
        skipped: j['skipped']?.toString(),
      );
}

/// Request body sent to `dispatch-directory-message` (exposed for tests).
Map<String, dynamic> directoryDispatchBody({
  required String societyId,
  required String title,
  required String message,
  required DirectoryDispatchChannels channels,
  DirectoryDispatchTarget target = const DirectoryDispatchTarget.all(),
  String? imageUrl,
}) =>
    {
      'society_id': societyId,
      'title': title,
      'message': message,
      'channels': {'whatsapp': channels.whatsapp, 'email': channels.email},
      'target_type': target.type,
      'target_flat_numbers':
          target.type == 'flat' ? target.flatNumbers : const <String>[],
      'target_ids':
          target.type == 'user' ? target.residentUserIds : const <String>[],
      'image_url': imageUrl,
    };

/// Returns null when no channel is requested or the call fails (never throws).
Future<DirectoryDispatchResult?> dispatchDirectoryChannels({
  required String societyId,
  required String title,
  required String message,
  required DirectoryDispatchChannels channels,
  DirectoryDispatchTarget target = const DirectoryDispatchTarget.all(),
  String? imageUrl,
}) async {
  if (!channels.any || !dbReady) return null;
  try {
    final data = await invokeFunction(
      'dispatch-directory-message',
      directoryDispatchBody(
        societyId: societyId,
        title: title,
        message: message,
        channels: channels,
        target: target,
        imageUrl: imageUrl,
      ),
    );
    if (data == null) return null;
    return DirectoryDispatchResult.fromJson(data);
  } catch (e) {
    debugPrint('dispatch-directory-message invoke error: $e');
    return null;
  }
}
