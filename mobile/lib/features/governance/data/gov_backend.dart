import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase/db.dart';
import '../../../models/session_models.dart';
import '../logic/election_eligibility.dart';
import '../logic/election_governance.dart';
import '../logic/meeting_logic.dart';

/// Shared Supabase helpers for the governance module — same tables, buckets and
/// edge functions as the web (`notificationMediaStorage.ts`, `pushNotification.ts`,
/// `dispatchDirectoryChannels.ts`, `societyNotificationSound.ts`, `memberPhotos.ts`,
/// `electionAudit.ts`, `electionEligibility.ts`).
abstract final class GovBackend {
  static const notificationMediaBucket = 'notification-media';
  static const societyDocumentsBucket = 'society-documents';
  static const _uuid = Uuid();

  static String newId() => _uuid.v4();

  /// Society signature / member-notification tune (`societies.admin_push_sound_url`).
  static Future<({String soundKey, String? customUrl})> societySound(String? societyId) async {
    if (societyId == null || societyId.isEmpty || !dbReady) return (soundKey: 'digital', customUrl: null);
    try {
      final row = await db.from('societies').select('admin_push_sound_url').eq('id', societyId).maybeSingle();
      final url = (row?['admin_push_sound_url'] as String?)?.trim();
      if (url != null && url.isNotEmpty) return (soundKey: 'custom', customUrl: url);
    } catch (e) {
      debugPrint('societySound failed: $e');
    }
    return (soundKey: 'digital', customUrl: null);
  }

  /// Upload to the public `notification-media` bucket and return the public URL.
  static Future<String?> uploadToNotificationMedia(
    String path,
    Uint8List bytes, {
    String? contentType,
    bool upsert = false,
    void Function(String message)? onError,
  }) async {
    try {
      await db.storage.from(notificationMediaBucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(cacheControl: '3600', upsert: upsert, contentType: contentType),
          );
      return db.storage.from(notificationMediaBucket).getPublicUrl(path);
    } catch (e) {
      onError?.call(errorText(e));
      return null;
    }
  }

  /// Web `uploadMeetingFile` (`meetings/{society}/{meeting}/{kind}/{uuid}_{name}`).
  static Future<String?> uploadMeetingFile({
    required String societyId,
    required String meetingId,
    required String kind,
    required Uint8List bytes,
    required String fileName,
    String? contentType,
  }) {
    var safe = sanitizeStorageFileName(fileName);
    if (safe.length > 120) safe = safe.substring(0, 120);
    final path = 'meetings/$societyId/$meetingId/$kind/${newId()}_$safe';
    return uploadToNotificationMedia(path, bytes, contentType: contentType);
  }

  /// Web `invokePushNotification` (best effort; uses the society tune when no sound is given).
  static Future<void> invokePush({
    required String title,
    required String message,
    required String societyId,
    String targetType = 'all',
  }) async {
    if (!dbReady) return;
    try {
      final sound = await societySound(societyId);
      await db.functions.invoke('send-push-notification', body: {
        'target_flat_numbers': <String>[],
        'target_ids': <String>[],
        'media_items': <Map<String, dynamic>>[],
        'title': title,
        'message': message,
        'target_type': targetType,
        'society_id': societyId,
        'sound_key': sound.soundKey,
        'sound_custom_url': sound.customUrl ?? '',
      });
    } catch (e) {
      debugPrint('Push notification failed (may not be configured): $e');
    }
  }

  /// Web `dispatchDirectoryChannels` (WhatsApp / email to directory contacts, best effort).
  static Future<Map<String, dynamic>?> dispatchDirectoryChannels({
    required String societyId,
    required String title,
    required String message,
    required bool whatsapp,
    required bool email,
  }) async {
    if (!whatsapp && !email) return null;
    if (!dbReady) return null;
    try {
      final res = await db.functions.invoke('dispatch-directory-message', body: {
        'society_id': societyId,
        'title': title,
        'message': message,
        'channels': {'whatsapp': whatsapp, 'email': email},
        'target_type': 'all',
        'target_flat_numbers': <String>[],
        'target_ids': <String>[],
        'image_url': null,
      });
      final data = res.data;
      return data is Map ? Map<String, dynamic>.from(data) : null;
    } catch (e) {
      debugPrint('dispatch-directory-message invoke error: $e');
      return null;
    }
  }

  /// Meeting notices: in-app row (with society tune) + push + optional directory channels
  /// (web `MeetingManager.notifyResidentsOfMeeting`).
  static Future<void> notifyResidentsOfMeeting({
    required String societyId,
    required String createdBy,
    required String title,
    required String body,
    bool whatsapp = false,
    bool email = false,
  }) async {
    final sound = await societySound(societyId);
    await db.from('notifications').insert({
      'title': title,
      'message': body,
      'type': 'general',
      'target_type': 'all',
      'target_id': 'all',
      'created_by': createdBy,
      'society_id': societyId,
      'sound_key': sound.soundKey,
      'sound_custom_url': sound.customUrl,
    });
    try {
      await db.functions.invoke('send-push-notification', body: {
        'title': title,
        'message': body,
        'target_type': 'all',
        'society_id': societyId,
        'sound_key': sound.soundKey,
        'sound_custom_url': sound.customUrl ?? '',
      });
    } catch (e) {
      debugPrint('Push failed: $e');
    }
    if (whatsapp || email) {
      await dispatchDirectoryChannels(
        societyId: societyId,
        title: title,
        message: body,
        whatsapp: whatsapp,
        email: email,
      );
    }
  }

  /// In-app notification + push for an election lifecycle event (web `notifyElectionEvent`).
  static Future<void> notifyElectionEvent({
    required ElectionNotifyEvent event,
    required String societyId,
    required String createdBy,
    required String electionTitle,
    String? message,
  }) async {
    final title = electionNotifyTitle(event);
    final msg = message ?? electionNotifyMessage(event, electionTitle);
    try {
      await db.from('notifications').insert({
        'title': title,
        'message': msg,
        'type': 'poll',
        'target_type': 'all',
        'created_by': createdBy,
        'society_id': societyId,
      });
    } catch (e) {
      debugPrint('election notification failed: $e');
    }
    await invokePush(title: title, message: msg, societyId: societyId);
  }

  /// Web `fetchMemberPhotoMap`.
  static Future<Map<String, String>> fetchMemberPhotoMap(Iterable<String> memberIds) async {
    final ids = memberIds.where((s) => s.isNotEmpty).toSet().toList();
    if (ids.isEmpty || !dbReady) return {};
    try {
      final rows = rowsOf(await db.from('members').select('id, photo').inFilter('id', ids));
      final map = <String, String>{};
      for (final r in rows) {
        final photo = (r['photo'] is String) ? (r['photo'] as String).trim() : '';
        if (photo.isNotEmpty) map['${r['id']}'] = photo;
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  /// Members of the society still living there (`flats!inner(society_id)`, `date_leave is null`).
  static Future<int?> activeMemberCount(String societyId) async {
    if (!dbReady) return null;
    try {
      final res = await db
          .from('members')
          .select('id, flats!inner(society_id)')
          .eq('flats.society_id', societyId)
          .isFilter('date_leave', null)
          .limit(1)
          .count(CountOption.exact);
      return res.count;
    } catch (e) {
      debugPrint('member count failed: $e');
      return null;
    }
  }

  /// Append-only election audit (RPC `log_election_audit_event`).
  static Future<String?> logElectionAudit({
    required String societyId,
    String? pollId,
    required String eventType,
    String? actorType,
    String? actorId,
    String? actorName,
    Map<String, dynamic> payload = const {},
  }) async {
    if (!dbReady) return null;
    try {
      final data = await db.rpc('log_election_audit_event', params: {
        'p_society_id': societyId,
        'p_poll_id': pollId,
        'p_event_type': eventType,
        'p_actor_type': actorType,
        'p_actor_id': actorId,
        'p_actor_name': actorName,
        'p_payload': payload,
      });
      return data is String ? data : null;
    } catch (e) {
      debugPrint('Election audit failed: $e');
      return null;
    }
  }

  /// Record bye-law voting method before polling (RPC `record_election_voting_method`).
  /// Returns an error message or null.
  static Future<String?> recordElectionVotingMethod({
    required String pollId,
    required String method,
    String? recordedBy,
    bool separateOfficeVotes = false,
  }) async {
    try {
      await db.rpc('record_election_voting_method', params: {
        'p_poll_id': pollId,
        'p_method': method,
        'p_recorded_by': recordedBy,
        'p_separate_office_votes': separateOfficeVotes,
      });
      return null;
    } catch (e) {
      return errorText(e);
    }
  }

  /// DB bye-law eligibility (RPC `member_election_eligibility`).
  static Future<({ElectionEligibility? data, String? error})> memberEligibility({
    required String memberId,
    required String societyId,
    String? asOf,
    int arrearsDays = ByeLaw.arrearsDisqualifyDays,
  }) async {
    try {
      final data = await db.rpc('member_election_eligibility', params: {
        'p_member_id': memberId,
        'p_society_id': societyId,
        'p_as_of': asOf ?? utcIsoDate(),
        'p_arrears_days': arrearsDays,
      });
      return (data: ElectionEligibility.fromRpc(data, memberId: memberId), error: null);
    } catch (e) {
      return (data: null, error: errorText(e));
    }
  }

  /// The household `members` row of the logged-in resident (matched by phone digits,
  /// like the web `myMemberRecord`).
  static Future<ResidentMemberRecord?> residentMember(SessionResident session) async {
    if (!dbReady) return null;
    final myPhone = session.resident.phone.replaceAll(RegExp(r'\D'), '');
    if (myPhone.isEmpty) return null;
    try {
      final rows = rowsOf(
        await db.from('members').select('*').eq('flat_id', session.resident.flatId).order('created_at'),
      );
      for (final m in rows) {
        final p = (m['phone'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
        if (p.isNotEmpty && p == myPhone) {
          return ResidentMemberRecord(
            id: '${m['id']}',
            name: (m['name'] ?? '').toString(),
            photo: m['photo'] as String?,
          );
        }
      }
    } catch (e) {
      debugPrint('resident member lookup failed: $e');
    }
    return null;
  }

  /// Human readable error text from Supabase exceptions.
  static String errorText(Object e) {
    if (e is PostgrestException) return e.message;
    if (e is StorageException) return e.message;
    if (e is FunctionException) return '${e.details ?? e.reasonPhrase ?? e.status}';
    if (e is StateError) return e.message;
    return e.toString();
  }
}

/// Household member record of the logged-in resident.
class ResidentMemberRecord {
  const ResidentMemberRecord({required this.id, required this.name, this.photo});

  final String id;
  final String name;
  final String? photo;
}
