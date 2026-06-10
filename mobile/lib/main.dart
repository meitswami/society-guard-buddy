import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/supabase/supabase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Demo mode when .env is missing (theme preview).
  }

  await SupabaseBootstrap.init();
  runApp(
    const ProviderScope(
      child: KutumbikaApp(),
    ),
  );
}
