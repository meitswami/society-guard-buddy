import 'package:flutter/foundation.dart';

import '../../../../core/supabase/db.dart';

/// Ports of `societyNotificationSound.fetchSocietyNotificationSound`,
/// `pushNotification.invokePushNotification` and `adminRecordNotifications.notifyResidentsOfRecord`.

/// `AdminRecordNotifyAudience`.
enum NotifyAudience {
  none('none'),
  selectedFlats('selected_flats'),
  all('all');

  const NotifyAudience(this.db);

  final String db;
}

class SocietySound {
  const SocietySound(this.soundKey, this.soundCustomUrl);

  final String soundKey;
  final String? soundCustomUrl;
}

abstract final class EventsNotify {
  /// Society signature tune (`societies.admin_push_sound_url`) → `custom`, else `digital`.
  static Future<SocietySound> societySound(String? societyId) async {
    if (societyId == null || societyId.isEmpty || !dbReady) return const SocietySound('digital', null);
    try {
      final data = await db.from('societies').select('admin_push_sound_url').eq('id', societyId).maybeSingle();
      final url = (data?['admin_push_sound_url'] as String?)?.trim();
      if (url != null && url.isNotEmpty) return SocietySound('custom', url);
    } catch (_) {
      // Fall back to the default tune like the web.
    }
    return const SocietySound('digital', null);
  }

  /// `mediaItemsFromReceiptUrl` — PDFs are not attached as images.
  static List<Map<String, String>>? mediaItemsFromReceiptUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    final u = url.split('?').first.toLowerCase();
    if (u.endsWith('.pdf')) return null;
    return [
      {'url': url, 'kind': 'image'},
    ];
  }

  /// Best-effort FCM push through the `send-push-notification` edge function.
  static Future<void> invokePush({
    required String title,
    required String message,
    required String targetType,
    required String societyId,
    List<String> targetFlatNumbers = const [],
  }) async {
    if (!dbReady) return;
    try {
      final sound = await societySound(societyId);
      await db.functions.invoke('send-push-notification', body: {
        'target_flat_numbers': targetFlatNumbers,
        'target_ids': <String>[],
        'media_items': <Map<String, String>>[],
        'title': title,
        'message': message,
        'target_type': targetType,
        'society_id': societyId,
        'sound_key': sound.soundKey,
        'sound_custom_url': sound.soundCustomUrl ?? '',
      });
    } catch (e) {
      debugPrint('Push notification failed (may not be configured): $e');
    }
  }

  /// In-app notification rows + best-effort push (same contract as the web NotificationCenter).
  /// For [NotifyAudience.selectedFlats] one row per flat and one push with `target_flat_numbers`.
  /// Returns false when inserting or pushing failed (caller shows the "saved but not notified" hint).
  static Future<bool> notifyResidentsOfRecord({
    required String societyId,
    required String adminName,
    required NotifyAudience audience,
    required List<String> selectedFlatNumbers,
    required String title,
    required String message,
    required String notificationType,
    required String? billUrl,
  }) async {
    if (audience == NotifyAudience.none) return true;
    final mediaItems = mediaItemsFromReceiptUrl(billUrl);
    final sound = await societySound(societyId);
    final rowBase = <String, dynamic>{
      'title': title,
      'message': message,
      'type': notificationType,
      'created_by': adminName,
      'society_id': societyId,
      'sound_key': sound.soundKey,
      'sound_custom_url': sound.soundCustomUrl,
      'media_items': mediaItems ?? const <Map<String, String>>[],
    };
    try {
      if (audience == NotifyAudience.all) {
        await db.from('notifications').insert([
          {...rowBase, 'target_type': 'all', 'target_id': null},
        ]);
        await _pushQuietly({
          'title': title,
          'message': message,
          'target_type': 'all',
          'target_flat_numbers': <String>[],
          'target_ids': <String>[],
          'media_items': mediaItems ?? const <Map<String, String>>[],
          'society_id': societyId,
          'sound_key': sound.soundKey,
          'sound_custom_url': sound.soundCustomUrl ?? '',
        });
      } else {
        final flats = <String>[];
        for (final f in selectedFlatNumbers) {
          if (f.isNotEmpty && !flats.contains(f)) flats.add(f);
        }
        if (flats.isEmpty) return true;
        for (final flat in flats) {
          await db.from('notifications').insert([
            {...rowBase, 'target_type': 'flat', 'target_id': flat},
          ]);
        }
        await _pushQuietly({
          'title': title,
          'message': message,
          'target_type': 'flat',
          'target_flat_numbers': flats,
          'target_ids': <String>[],
          'media_items': mediaItems ?? const <Map<String, String>>[],
          'society_id': societyId,
          'sound_key': sound.soundKey,
          'sound_custom_url': sound.soundCustomUrl ?? '',
        });
      }
      return true;
    } catch (e) {
      debugPrint('Admin record notification / push failed: $e');
      return false;
    }
  }

  /// The web ignores the invoke result (supabase-js never throws there); Dart throws on HTTP errors.
  static Future<void> _pushQuietly(Map<String, dynamic> body) async {
    try {
      await db.functions.invoke('send-push-notification', body: body);
    } catch (e) {
      debugPrint('send-push-notification failed: $e');
    }
  }
}
