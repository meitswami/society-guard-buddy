import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../config/env.dart';

/// Starts Firebase (phone OTP login + FCM push).
///
/// Android / iOS use the native config bundled in the app (`google-services.json` /
/// `GoogleService-Info.plist`). The web app's Firebase app id (in `.env`) does not work for
/// FCM tokens or phone auth on a phone, so it is only used on web, or on a phone when a
/// matching `FIREBASE_ANDROID_APP_ID` / `FIREBASE_IOS_APP_ID` is set.
abstract final class FirebaseBootstrap {
  static bool _initialized = false;

  /// True once Firebase is running; push and OTP features check this.
  static bool get isReady => _initialized;

  static Future<void> init() async {
    if (_initialized) return;
    try {
      final mobile = !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
      if (mobile) {
        try {
          await Firebase.initializeApp();
          _initialized = true;
          return;
        } catch (_) {
          // No native config bundled; try a mobile app id from .env below.
        }
        final appId =
            defaultTargetPlatform == TargetPlatform.android ? Env.firebaseAndroidAppId : Env.firebaseIosAppId;
        if (appId.isEmpty || Env.firebaseApiKey.isEmpty || Env.firebaseProjectId.isEmpty) return;
        await Firebase.initializeApp(options: _options(appId));
      } else {
        if (!Env.isFirebaseConfigured) return;
        await Firebase.initializeApp(options: _options(Env.firebaseAppId));
      }
      _initialized = true;
    } catch (e) {
      debugPrint('[Firebase] init failed: $e');
    }
  }

  static FirebaseOptions _options(String appId) => FirebaseOptions(
        apiKey: Env.firebaseApiKey,
        authDomain: Env.firebaseAuthDomain,
        projectId: Env.firebaseProjectId,
        messagingSenderId: Env.firebaseMessagingSenderId,
        appId: appId,
      );
}
