/// Supabase queries of `NotificationCenter.tsx`, `NotificationDetailModal.tsx`,
/// `societyNotificationSound.ts`, `pushNotification.ts`, `adminRecordNotifications.ts` and
/// `dispatchDirectoryChannels.ts` — same tables, columns, filters and edge functions.
library;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/db.dart';
import 'notification_compose.dart';
import 'notification_models.dart';

/// Recipients for the compose form (flats + residents + primary member names).
class NotificationTargets {
  const NotificationTargets(
      {this.flats = const [],
      this.residents = const [],
      this.primaryByFlatId = const {}});

  /// `{id, flat_number, owner_name}` ordered by flat number.
  final List<Map<String, dynamic>> flats;

  /// `{id, name, flat_number, flat_id}` ordered by name.
  final List<Map<String, dynamic>> residents;
  final Map<String, String> primaryByFlatId;
}

/// Web `SocietyNotificationSound`.
class SocietyNotificationSound {
  const SocietyNotificationSound({required this.soundKey, this.soundCustomUrl});

  final String soundKey;
  final String? soundCustomUrl;
}

class NotificationRepository {
  const NotificationRepository();

  /// Latest 150 notifications (society scoped when [societyId] is set).
  Future<List<AppNotification>> loadNotifications({String? societyId}) async {
    if (!dbReady) return const [];
    var q = db.from('notifications').select('*');
    if (societyId != null && societyId.isNotEmpty) {
      q = q.eq('society_id', societyId);
    }
    final data = await q.order('created_at', ascending: false).limit(150);
    return rowsOf(data).map(AppNotification.fromRow).toList();
  }

  Future<Set<String>> loadDismissedIds(String residentId) async {
    if (!dbReady || residentId.isEmpty) return <String>{};
    final data = await db
        .from('notification_dismissals')
        .select('notification_id')
        .eq('resident_id', residentId);
    return rowsOf(data)
        .map((r) => r['notification_id']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toSet();
  }

  Future<void> markRead(String id) async {
    await db.from('notifications').update({
      'is_read': true,
      'read_at': DateTime.now().toUtc().toIso8601String()
    }).eq('id', id);
  }

  /// Resident / no-society "mark all": the visible unread ids, with `read_at`.
  Future<void> markIdsRead(List<String> ids) async {
    if (ids.isEmpty) return;
    await db.from('notifications').update({
      'is_read': true,
      'read_at': DateTime.now().toUtc().toIso8601String()
    }).inFilter('id', ids);
  }

  /// Admin "Mark all read": every unread row of the society (web sets only `is_read`).
  Future<void> markSocietyRead(String societyId) async {
    await db
        .from('notifications')
        .update({'is_read': true})
        .eq('society_id', societyId)
        .eq('is_read', false);
  }

  /// Rows on or before [cutoffIso] for "Clear till date".
  Future<List<Map<String, dynamic>>> loadForClear(
      String societyId, String cutoffIso) async {
    final data = await db
        .from('notifications')
        .select('id, target_type, target_id, created_at')
        .eq('society_id', societyId)
        .lte('created_at', cutoffIso)
        .order('created_at', ascending: false);
    return rowsOf(data);
  }

  Future<void> dismiss(List<String> ids, String residentId) async {
    if (ids.isEmpty) return;
    await db.from('notification_dismissals').upsert(
      [
        for (final id in ids)
          {'notification_id': id, 'resident_id': residentId},
      ],
      onConflict: 'notification_id,resident_id',
      ignoreDuplicates: true,
    );
  }

  Future<List<NotificationComment>> loadComments(String notificationId) async {
    final data = await db
        .from('notification_comments')
        .select('*')
        .eq('notification_id', notificationId)
        .order('created_at', ascending: true);
    return rowsOf(data).map(NotificationComment.fromRow).toList();
  }

  Future<void> addComment(Map<String, dynamic> row) async {
    await db.from('notification_comments').insert(row);
  }

  Future<String?> fetchSocietySoundUrl(String societyId) async {
    if (!dbReady || societyId.isEmpty) return null;
    final row = await db
        .from('societies')
        .select('admin_push_sound_url')
        .eq('id', societyId)
        .maybeSingle();
    final url = row?['admin_push_sound_url']?.toString().trim() ?? '';
    return url.isEmpty ? null : url;
  }

  /// Web `fetchSocietyNotificationSound`.
  Future<SocietyNotificationSound> fetchSocietyNotificationSound(
      String? societyId) async {
    if (societyId == null || societyId.isEmpty) {
      return const SocietyNotificationSound(soundKey: 'digital');
    }
    try {
      final url = await fetchSocietySoundUrl(societyId);
      if (url != null) {
        return SocietyNotificationSound(
            soundKey: 'custom', soundCustomUrl: url);
      }
    } catch (_) {}
    return const SocietyNotificationSound(soundKey: 'digital');
  }

  Future<void> updateSocietySoundUrl(String societyId, String? url) async {
    await db
        .from('societies')
        .update({'admin_push_sound_url': url}).eq('id', societyId);
  }

  /// Compose recipients (web effect after `loadNotifications`).
  Future<NotificationTargets> loadTargets(String societyId) async {
    final flatsData = await db
        .from('flats')
        .select('id, flat_number, owner_name')
        .eq('society_id', societyId)
        .order('flat_number');
    final flats = rowsOf(flatsData);
    final flatIds = flats
        .map((f) => f['id']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
    if (flatIds.isEmpty) return NotificationTargets(flats: flats);
    final results = await Future.wait([
      db
          .from('resident_users')
          .select('id, name, flat_number, flat_id')
          .inFilter('flat_id', flatIds)
          .order('name'),
      db
          .from('members')
          .select('flat_id, name')
          .eq('is_primary', true)
          .inFilter('flat_id', flatIds),
    ]);
    final primary = <String, String>{};
    for (final r in rowsOf(results[1])) {
      final fid = r['flat_id']?.toString();
      final name = r['name']?.toString().trim() ?? '';
      if (fid != null && name.isNotEmpty) primary[fid] = name;
    }
    return NotificationTargets(
        flats: flats, residents: rowsOf(results[0]), primaryByFlatId: primary);
  }

  /// Inserts rows one at a time (web inserts each flat row separately).
  Future<void> insertNotifications(List<Map<String, dynamic>> rows) async {
    for (final row in rows) {
      await db.from('notifications').insert([row]);
    }
  }

  /// `send-push-notification` (errors are returned in the map or rethrown for the caller).
  Future<Map<String, dynamic>?> invokePush(Map<String, dynamic> body) =>
      invokeFunction('send-push-notification', body);

  /// Best-effort push (web `invokePushNotification`): fills the society sound when the
  /// caller did not pass one; never throws.
  Future<void> invokePushBestEffort(Map<String, dynamic> body) async {
    try {
      final hasSound = body['sound_key'] != null;
      final sound = hasSound
          ? SocietyNotificationSound(
              soundKey: body['sound_key'].toString(),
              soundCustomUrl: body['sound_custom_url']?.toString())
          : await fetchSocietyNotificationSound(body['society_id']?.toString());
      await invokePush({
        'target_flat_numbers': const <String>[],
        'target_ids': const <String>[],
        'media_items': const <Object>[],
        ...body,
        'sound_key': sound.soundKey,
        'sound_custom_url': sound.soundCustomUrl ?? '',
      });
    } catch (e) {
      debugPrint('Push notification failed (may not be configured): $e');
    }
  }

  /// Web `dispatchDirectoryChannels` (edge fn `dispatch-directory-message`). Best effort.
  Future<Map<String, dynamic>?> dispatchDirectoryChannels({
    required String societyId,
    required String title,
    required String message,
    required bool whatsapp,
    required bool email,
    required NotificationTargetMode target,
    List<String> flatNumbers = const [],
    List<String> residentUserIds = const [],
    String? imageUrl,
  }) async {
    if (!whatsapp && !email) return null;
    try {
      return await invokeFunction('dispatch-directory-message', {
        'society_id': societyId,
        'title': title,
        'message': message,
        'channels': {'whatsapp': whatsapp, 'email': email},
        ...directoryTargetFields(target,
            flats: flatNumbers, userIds: residentUserIds),
        'image_url': imageUrl,
      });
    } catch (e) {
      debugPrint('dispatch-directory-message failed: $e');
      return null;
    }
  }

  /// Latest FCM token of this admin (push health check).
  Future<String?> latestAdminToken(String adminId, {String? societyId}) async {
    var q = db
        .from('fcm_web_tokens')
        .select('token, updated_at')
        .eq('user_type', 'admin')
        .eq('app_user_id', adminId);
    if (societyId != null && societyId.isNotEmpty) {
      q = q.eq('society_id', societyId);
    }
    final data = await q.order('updated_at', ascending: false).limit(1);
    final rows = rowsOf(data);
    if (rows.isEmpty) return null;
    return rows.first['token']?.toString();
  }

  /// Web `notifyResidentsOfRecord` — in-app rows + push (+ optional directory channels) for
  /// records saved by other admin modules. Returns false when inserting / pushing failed.
  Future<bool> notifyResidentsOfRecord({
    required String societyId,
    required String adminName,
    required RecordNotifyAudience audience,
    required List<String> selectedFlatNumbers,
    required String title,
    required String message,
    required String notificationType,
    String? billUrl,
    bool whatsapp = false,
    bool email = false,
  }) async {
    if (audience == RecordNotifyAudience.none) return true;
    final sound = await fetchSocietyNotificationSound(societyId);
    final plan = buildRecordNotificationPlan(
      societyId: societyId,
      adminName: adminName,
      audience: audience,
      selectedFlatNumbers: selectedFlatNumbers,
      title: title,
      message: message,
      notificationType: notificationType,
      billUrl: billUrl,
      soundKey: sound.soundKey,
      soundCustomUrl: sound.soundCustomUrl,
    );
    if (plan == null || plan.rows.isEmpty) return true;
    try {
      await insertNotifications(plan.rows);
      try {
        await invokePush(plan.pushBody);
      } catch (e) {
        // supabase-js `functions.invoke` resolves with `{ error }` instead of throwing.
        debugPrint('send-push-notification failed: $e');
      }
      if (whatsapp || email) {
        final media = mediaItemsFromReceiptUrl(billUrl);
        await dispatchDirectoryChannels(
          societyId: societyId,
          title: title,
          message: message,
          whatsapp: whatsapp,
          email: email,
          target: audience == RecordNotifyAudience.all
              ? NotificationTargetMode.all
              : NotificationTargetMode.flat,
          flatNumbers: plan.targetFlatNumbers,
          imageUrl: (media == null || media.isEmpty) ? null : media.first.url,
        );
      }
      return true;
    } catch (e) {
      debugPrint('Admin record notification / push failed: $e');
      return false;
    }
  }

  /// Realtime INSERTs on `notifications` for a society (web `useNotificationsRealtimeRevision`).
  /// Remove the returned channel with `db.removeChannel` in `dispose`.
  RealtimeChannel? subscribeInserts(String channelName, String? societyId,
      void Function(Map<String, dynamic> row) onInsert) {
    if (!dbReady) return null;
    return db
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: (societyId == null || societyId.isEmpty)
              ? null
              : PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'society_id',
                  value: societyId),
          callback: (payload) => onInsert(payload.newRecord),
        )
        .subscribe();
  }

  /// Realtime INSERTs on `notification_comments` for one notification.
  RealtimeChannel? subscribeComments(
      String notificationId, VoidCallback onInsert) {
    if (!dbReady) return null;
    return db
        .channel('notif-comments-$notificationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notification_comments',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'notification_id',
              value: notificationId),
          callback: (_) => onInsert(),
        )
        .subscribe();
  }
}
