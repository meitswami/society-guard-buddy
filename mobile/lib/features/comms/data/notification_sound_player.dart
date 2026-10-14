import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'notification_sounds.dart';

/// Plays notification alerts like web `playNotificationAlert`: preset tones are rendered
/// to WAV once and cached; `custom` plays the society URL (volume 0.9) and falls back to
/// the digital beep when the file cannot be played.
class NotificationSoundPlayer {
  NotificationSoundPlayer._();

  static final NotificationSoundPlayer instance = NotificationSoundPlayer._();

  AudioPlayer? _player;
  final Map<String, Uint8List> _cache = {};

  AudioPlayer _ensure() => _player ??= AudioPlayer();

  /// `playNotificationAlert(soundKey, soundCustomUrl)`.
  Future<void> play(String? soundKey, [String? soundCustomUrl]) async {
    final plan = planNotificationAlert(soundKey, soundCustomUrl);
    if (plan.customUrl != null) {
      final ok = await playUrl(plan.customUrl!);
      if (!ok) await playPreset('digital');
      return;
    }
    await playPreset(plan.preset);
  }

  /// `playPresetNotificationSound(preset)`.
  Future<void> playPreset(String preset) async {
    final tones = presetTones(preset);
    if (tones.isEmpty) return;
    final bytes = _cache.putIfAbsent(preset, () => synthesizeToneWav(tones));
    try {
      final p = _ensure();
      await p.stop();
      await p.play(BytesSource(bytes, mimeType: 'audio/wav'), volume: 1.0);
    } catch (e) {
      debugPrint('[sound] preset failed: $e');
    }
  }

  /// Plays a remote audio file; false when it could not be loaded.
  Future<bool> playUrl(String url, {double volume = 0.9}) async {
    try {
      final p = _ensure();
      await p.stop();
      await p.play(UrlSource(url.trim()), volume: volume);
      return true;
    } catch (e) {
      debugPrint('[sound] url failed: $e');
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _player?.stop();
    } catch (_) {}
  }
}

/// Shorthand for [NotificationSoundPlayer.play].
Future<void> playNotificationAlert(String? soundKey,
        [String? soundCustomUrl]) =>
    NotificationSoundPlayer.instance.play(soundKey, soundCustomUrl);
