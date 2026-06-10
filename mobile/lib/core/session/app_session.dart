import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Mirrors web `src/lib/appSession.ts` — society-scoped custom session (not Supabase Auth).
class AppSession {
  AppSession._();

  static const _key = 'sgb_app_session_v1';

  static Future<Map<String, dynamic>?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      if (parsed['v'] != 1) return null;
      return parsed;
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(Map<String, dynamic> session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode({...session, 'v': 1}));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
