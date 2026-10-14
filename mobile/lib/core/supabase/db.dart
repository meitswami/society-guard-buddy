import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import 'supabase_bootstrap.dart';

/// Shorthand for the shared Supabase client (same project / RLS as the web app).
SupabaseClient get db => SupabaseBootstrap.client;

/// False in demo builds without `.env` — services should return empty data then.
bool get dbReady => Env.isConfigured;

/// `[row, row, …]` → typed list of JSON maps.
List<Map<String, dynamic>> rowsOf(Object? data) =>
    data is List ? data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];

/// Invoke an Edge Function (same names as the web app's `supabase.functions.invoke`).
Future<Map<String, dynamic>?> invokeFunction(String name, Map<String, dynamic> body) async {
  final res = await db.functions.invoke(name, body: body);
  final data = res.data;
  if (data is Map) return Map<String, dynamic>.from(data);
  return null;
}
