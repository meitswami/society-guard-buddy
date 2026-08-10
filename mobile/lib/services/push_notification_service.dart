import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/config/env.dart';
import '../core/firebase/firebase_bootstrap.dart';
import '../core/supabase/supabase_bootstrap.dart';
import '../models/session_models.dart';

const _androidChannelId = 'kutumbika_alerts';
const _androidChannelName = 'Kutumbika alerts';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await FirebaseBootstrap.init();
}

/// Registers FCM device tokens in `fcm_web_tokens` (same table as web).
class PushNotificationService {
  static bool _foregroundListenerAttached = false;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final AudioPlayer _alertPlayer = AudioPlayer();

  static Future<void> ensureBackgroundHandler() async {
    if (!Env.isFirebaseConfigured) return;
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  Future<void> _initLocalNotifications() async {
    if (kIsWeb) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    if (defaultTargetPlatform == TargetPlatform.android) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _androidChannelId,
              _androidChannelName,
              importance: Importance.high,
            ),
          );
    }
  }

  Future<void> _playSocietyAlert(RemoteMessage message) async {
    final url = message.data['sound_custom_url']?.toString().trim();
    if (url == null || url.isEmpty) return;
    try {
      await _alertPlayer.stop();
      await _alertPlayer.play(UrlSource(url));
    } catch (e) {
      debugPrint('[FCM] alert sound failed: $e');
    }
  }

  Future<void> initForegroundListener() async {
    if (_foregroundListenerAttached || !Env.isFirebaseConfigured) return;
    _foregroundListenerAttached = true;

    if (!kIsWeb) {
      await _initLocalNotifications();
    }

    FirebaseMessaging.onMessage.listen((message) async {
      final title = message.notification?.title ?? 'Kutumbika';
      final body = message.notification?.body ?? '';
      debugPrint('[FCM] $title: $body');

      await _playSocietyAlert(message);

      if (kIsWeb || body.isEmpty) return;

      await _localNotifications.show(
        message.hashCode,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannelId,
            _androidChannelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    });
  }

  Future<void> registerForSession(AppSessionState session) async {
    if (!Env.isFirebaseConfigured) return;

    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      String? token;
      if (kIsWeb) {
        final vapid = Env.firebaseVapidKey;
        if (vapid.isEmpty) return;
        token = await messaging.getToken(vapidKey: vapid);
      } else {
        token = await messaging.getToken();
      }
      if (token == null || token.isEmpty) return;

      final payload = switch (session) {
        SessionResident(:final societyId, :final resident) => {
            'token': token,
            'user_type': 'resident',
            'app_user_id': resident.id,
            'flat_number': resident.flatNumber,
            'society_id': societyId,
          },
        SessionGuard(:final societyId, :final guard) => {
            'token': token,
            'user_type': 'guard',
            'app_user_id': guard.guardId,
            'flat_number': null,
            'society_id': societyId,
          },
        SessionAdmin(:final societyId, :final admin) => {
            'token': token,
            'user_type': 'admin',
            'app_user_id': admin.id,
            'flat_number': null,
            'society_id': societyId,
          },
        _ => null,
      };

      if (payload == null) return;

      await SupabaseBootstrap.client.from('fcm_web_tokens').upsert(
            payload,
            onConflict: 'token',
          );
    } catch (e) {
      debugPrint('[FCM] register failed: $e');
    }
  }
}
