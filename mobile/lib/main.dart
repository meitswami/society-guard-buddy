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

  await SupabaseBootstrap.init();
  await FirebaseBootstrap.init();
  await PushNotificationService.ensureBackgroundHandler();
  await PushNotificationService().initForegroundListener();
  runApp(
    const ProviderScope(
      child: KutumbikaApp(),
    ),
  );
}
