import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

abstract final class SupabaseBootstrap {
  static Future<void> init() async {
    if (!Env.isConfigured) return;
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
