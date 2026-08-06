import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'core/supabase/supabase_bootstrap.dart';
import 'services/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Demo mode when .env is missing (theme preview).
  }

  // Parallelize independent SDKs; do not block first frame on push listeners.
  await Future.wait([
    SupabaseBootstrap.init(),
    FirebaseBootstrap.init(),
  ]);
  await PushNotificationService.ensureBackgroundHandler();

  runApp(
    const ProviderScope(
      child: KutumbikaApp(),
    ),
  );

  // Foreground FCM after first frame so cold start is not gated on notification setup.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    PushNotificationService().initForegroundListener();
  });
}
