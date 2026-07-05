import 'package:firebase_core/firebase_core.dart';

import '../config/env.dart';

abstract final class FirebaseBootstrap {
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized || !Env.isFirebaseConfigured) return;
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: Env.firebaseApiKey,
        authDomain: Env.firebaseAuthDomain,
        projectId: Env.firebaseProjectId,
        messagingSenderId: Env.firebaseMessagingSenderId,
        appId: Env.firebaseAppId,
      ),
    );
    _initialized = true;
  }
}
