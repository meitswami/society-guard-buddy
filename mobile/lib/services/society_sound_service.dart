import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/env.dart';
import '../core/supabase/supabase_bootstrap.dart';

/// Plays the society signature / notification tune (`societies.admin_push_sound_url`).
class SocietySoundService {
  SocietySoundService({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  static const _prefsKeyPrefix = 'society_signature_tune_played_';

  Future<String?> fetchSoundUrl(String societyId) async {
    if (!Env.isConfigured || societyId.isEmpty) return null;
    final row = await SupabaseBootstrap.client
        .from('societies')
        .select('admin_push_sound_url')
        .eq('id', societyId)
        .maybeSingle();
    final url = row?['admin_push_sound_url']?.toString().trim();
    if (url == null || url.isEmpty) return null;
    return url;
  }

  Future<void> playUrl(String url) async {
    try {
      await _player.stop();
      await _player.play(UrlSource(url));
    } catch (_) {
      // Autoplay / network failures are non-fatal.
    }
  }

  /// Signature tune once per install+day for this society (app open).
  Future<void> playSignatureTuneOnOpen(String societyId, {bool force = false}) async {
    final url = await fetchSoundUrl(societyId);
    if (url == null) return;

    if (!force) {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final key = '$_prefsKeyPrefix$societyId';
      if (prefs.getString(key) == today) return;
      await prefs.setString(key, today);
    }

    await playUrl(url);
  }

  Future<void> dispose() => _player.dispose();
}
