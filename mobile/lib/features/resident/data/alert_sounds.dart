/// In-app alert tones — port of web `src/lib/notificationSounds.ts` (preset notification
/// sounds, society custom URL) and the two-tone approval beep of `ResidentDashboard.tsx`.
/// The web synthesises tones with WebAudio oscillators; here the same tone sequences are
/// rendered into a small WAV and played with `audioplayers`.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

enum ToneWave { sine, square, triangle, sawtooth }

class ToneSpec {
  const ToneSpec(this.freq, this.durationMs, {this.wave = ToneWave.sine, this.gain = 0.12, this.offsetMs = 0, this.decay = true});

  final double freq;
  final int durationMs;
  final ToneWave wave;
  final double gain;
  final int offsetMs;
  /// Web presets ramp the gain exponentially to 0.001 over the tone; the approval beep does not.
  final bool decay;
}

/// Web `notificationSound()` — 800 Hz then 1000 Hz (0.3 s each, gain 0.3).
const List<ToneSpec> kApprovalChimeTones = [
  ToneSpec(800, 300, gain: 0.3, decay: false),
  ToneSpec(1000, 300, gain: 0.3, offsetMs: 350, decay: false),
];

/// Web `NOTIFICATION_SOUND_PRESETS` ids.
const List<String> kNotificationSoundPresets = ['digital', 'chime', 'melody', 'bell', 'siren', 'custom'];

/// Tone sequence of web `playPresetNotificationSound(preset)`.
List<ToneSpec> presetTones(String preset) {
  switch (preset) {
    case 'chime':
      return const [ToneSpec(880, 120, gain: 0.1), ToneSpec(1174, 140, gain: 0.08, offsetMs: 90)];
    case 'melody':
      return const [
        ToneSpec(523, 160, gain: 0.1),
        ToneSpec(659, 160, gain: 0.09, offsetMs: 140),
        ToneSpec(784, 160, gain: 0.09, offsetMs: 280),
        ToneSpec(1047, 220, gain: 0.08, offsetMs: 420),
      ];
    case 'bell':
      return const [
        ToneSpec(523, 200, wave: ToneWave.triangle, gain: 0.14),
        ToneSpec(659, 220, wave: ToneWave.triangle, gain: 0.12, offsetMs: 120),
      ];
    case 'siren':
      return const [
        ToneSpec(880, 100, wave: ToneWave.sawtooth, gain: 0.12),
        ToneSpec(660, 100, wave: ToneWave.sawtooth, gain: 0.1, offsetMs: 90),
        ToneSpec(880, 100, wave: ToneWave.sawtooth, gain: 0.12, offsetMs: 180),
        ToneSpec(660, 100, wave: ToneWave.sawtooth, gain: 0.1, offsetMs: 270),
      ];
    case 'custom':
      return const [];
    case 'digital':
    default:
      return const [
        ToneSpec(1200, 80, wave: ToneWave.square, gain: 0.08),
        ToneSpec(900, 90, wave: ToneWave.square, gain: 0.06, offsetMs: 70),
      ];
  }
}

double _wave(ToneWave w, double phase) {
  switch (w) {
    case ToneWave.sine:
      return math.sin(2 * math.pi * phase);
    case ToneWave.square:
      return math.sin(2 * math.pi * phase) >= 0 ? 1 : -1;
    case ToneWave.triangle:
      return (2 / math.pi) * math.asin(math.sin(2 * math.pi * phase));
    case ToneWave.sawtooth:
      return 2 * (phase - (0.5 + phase).floorToDouble());
  }
}

/// Renders tones into 16-bit mono PCM WAV bytes. [masterGain] lifts the web levels a bit
/// so the tones are audible on phone speakers.
Uint8List synthesizeWav(List<ToneSpec> tones, {int sampleRate = 22050, double masterGain = 2.0}) {
  var endMs = 0;
  for (final t in tones) {
    endMs = math.max(endMs, t.offsetMs + t.durationMs + 20);
  }
  final frames = (sampleRate * endMs / 1000).ceil();
  final samples = Float64List(frames);
  for (final t in tones) {
    final start = (sampleRate * t.offsetMs / 1000).floor();
    final len = (sampleRate * t.durationMs / 1000).floor();
    for (var i = 0; i < len && start + i < frames; i++) {
      final time = i / sampleRate;
      final progress = len <= 1 ? 1.0 : i / (len - 1);
      final g = t.decay ? t.gain * math.pow(0.001 / t.gain, progress) : t.gain;
      samples[start + i] += _wave(t.wave, t.freq * time) * g * masterGain;
    }
  }
  final dataBytes = frames * 2;
  final bytes = ByteData(44 + dataBytes);
  void ascii(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      bytes.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  bytes.setUint32(4, 36 + dataBytes, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little); // PCM
  bytes.setUint16(22, 1, Endian.little); // mono
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, sampleRate * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  bytes.setUint32(40, dataBytes, Endian.little);
  for (var i = 0; i < frames; i++) {
    final v = samples[i].clamp(-1.0, 1.0);
    bytes.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
  }
  return bytes.buffer.asUint8List();
}

/// Plays approval / notification alerts for the resident shell.
class ResidentAlertSounds {
  ResidentAlertSounds();

  AudioPlayer? _player;
  final Map<String, Uint8List> _cache = {};

  AudioPlayer get _p => _player ??= AudioPlayer();

  Future<void> _playTones(String cacheKey, List<ToneSpec> tones) async {
    if (tones.isEmpty) return;
    try {
      final wav = _cache.putIfAbsent(cacheKey, () => synthesizeWav(tones));
      await _p.stop();
      await _p.setVolume(1.0);
      await _p.play(BytesSource(wav, mimeType: 'audio/wav'));
    } catch (_) {
      // Audio focus / platform failures are not fatal.
    }
  }

  /// Two-tone beep when a new pending approval arrives.
  Future<void> playApprovalChime() => _playTones('approval', kApprovalChimeTones);

  /// Web `playNotificationAlert(soundKey, soundCustomUrl)`.
  Future<void> playNotificationAlert(String? soundKey, [String? customUrl]) async {
    final key = (soundKey == null || soundKey.isEmpty ? 'digital' : soundKey).toLowerCase();
    final url = (customUrl ?? '').trim();
    if (key == 'custom' && url.isNotEmpty) {
      try {
        await _p.stop();
        await _p.setVolume(0.9);
        await _p.play(UrlSource(url));
        return;
      } catch (_) {
        await _playTones('digital', presetTones('digital'));
        return;
      }
    }
    final preset = key == 'custom' ? 'digital' : key;
    await _playTones(preset, presetTones(preset));
  }

  Future<void> dispose() async {
    final p = _player;
    _player = null;
    await p?.dispose();
  }
}
