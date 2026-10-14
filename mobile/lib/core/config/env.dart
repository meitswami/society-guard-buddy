import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract final class Env {
  /// Reads `.env` values; empty when the file was not loaded (tests, demo builds).
  static String _get(String key) => dotenv.isInitialized ? (dotenv.env[key] ?? '') : '';

  static String get supabaseUrl => _get('SUPABASE_URL');
  static String get supabaseAnonKey => _get('SUPABASE_ANON_KEY');

  static String get firebaseApiKey => _get('FIREBASE_API_KEY');
  static String get firebaseProjectId => _get('FIREBASE_PROJECT_ID');
  static String get firebaseMessagingSenderId => _get('FIREBASE_MESSAGING_SENDER_ID');
  static String get firebaseAppId => _get('FIREBASE_APP_ID');
  static String get firebaseAuthDomain {
    final v = _get('FIREBASE_AUTH_DOMAIN');
    if (v.isNotEmpty) return v;
    return firebaseProjectId.isNotEmpty ? '$firebaseProjectId.firebaseapp.com' : '';
  }

  static String get firebaseVapidKey => _get('FIREBASE_VAPID_KEY');

  /// Firebase app ids of the Android / iOS apps (only needed when the build has no
  /// `google-services.json` / `GoogleService-Info.plist`).
  static String get firebaseAndroidAppId => _get('FIREBASE_ANDROID_APP_ID');
  static String get firebaseIosAppId => _get('FIREBASE_IOS_APP_ID');

  /// Public URL of the web app (legal pages, signup, deep links). Optional.
  static String get webAppUrl {
    final v = _get('WEB_APP_URL');
    return v.isNotEmpty ? v : 'https://evergreen-heights-society-guard-bud.vercel.app';
  }

  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get isFirebaseConfigured =>
      firebaseApiKey.isNotEmpty && firebaseProjectId.isNotEmpty && firebaseAppId.isNotEmpty;
}
