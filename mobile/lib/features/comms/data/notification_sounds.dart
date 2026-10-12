/// Port of `src/lib/notificationSounds.ts`.
///
/// The web synthesises short tones with WebAudio oscillators. Mobile renders the very same
/// tone schedule (frequency, duration, wave shape, gain, exponential decay) into a small
/// 16-bit PCM WAV and plays it with `audioplayers` — no audio assets needed.
library;

import 'dart:math' as math;
import 'dart:typed_data';

class NotificationSoundPreset {
  const NotificationSoundPreset(this.id, this.labelKey);

  final String id;
  final String labelKey;
}

/// Keys stored on `notifications.sound_key` (admin-only upload uses `custom` + URL).
const List<NotificationSoundPreset> kNotificationSoundPresets = [
  NotificationSoundPreset('digital', 'comms.sound.digital'),
  NotificationSoundPreset('chime', 'comms.sound.chime'),
  NotificationSoundPreset('melody', 'comms.sound.melody'),
  NotificationSoundPreset('bell', 'comms.sound.bell'),
  NotificationSoundPreset('siren', 'comms.sound.siren'),
  NotificationSoundPreset('custom', 'comms.sound.custom'),
];

enum ToneWave { sine, square, triangle, sawtooth }

/// One oscillator burst: starts [startMs] after the alert begins (web `setTimeout`).
class ToneSpec {
  const ToneSpec(this.startMs, this.frequency, this.durationMs, this.wave, this.gain);

  final int startMs;
  final double frequency;
  final int durationMs;
  final ToneWave wave;
  final double gain;

  @override
  bool operator ==(Object other) =>
      other is ToneSpec &&
      other.startMs == startMs &&
      other.frequency == frequency &&
      other.durationMs == durationMs &&
      other.wave == wave &&
      other.gain == gain;

  @override
  int get hashCode => Object.hash(startMs, frequency, durationMs, wave, gain);

  @override
  String toString() => 'ToneSpec($startMs, $frequency, $durationMs, $wave, $gain)';
}

/// Web `playPresetNotificationSound` schedule. `custom` → no tones (handled by URL playback);
/// unknown keys fall back to `digital` (web `default:`).
List<ToneSpec> presetTones(String preset) {
  switch (preset) {
    case 'chime':
      return const [
        ToneSpec(0, 880, 120, ToneWave.sine, 0.1),
        ToneSpec(90, 1174, 140, ToneWave.sine, 0.08),
      ];
    case 'melody':
      return const [
        ToneSpec(0, 523, 160, ToneWave.sine, 0.1),
        ToneSpec(140, 659, 160, ToneWave.sine, 0.09),
        ToneSpec(280, 784, 160, ToneWave.sine, 0.09),
        ToneSpec(420, 1047, 220, ToneWave.sine, 0.08),
      ];
    case 'bell':
      return const [
        ToneSpec(0, 523, 200, ToneWave.triangle, 0.14),
        ToneSpec(120, 659, 220, ToneWave.triangle, 0.12),
      ];
    case 'siren':
      return const [
        ToneSpec(0, 880, 100, ToneWave.sawtooth, 0.12),
        ToneSpec(90, 660, 100, ToneWave.sawtooth, 0.1),
        ToneSpec(180, 880, 100, ToneWave.sawtooth, 0.12),
        ToneSpec(270, 660, 100, ToneWave.sawtooth, 0.1),
      ];
    case 'custom':
      return const [];
    case 'digital':
    default:
      return const [
        ToneSpec(0, 1200, 80, ToneWave.square, 0.08),
        ToneSpec(70, 900, 90, ToneWave.square, 0.06),
      ];
  }
}

/// What `playNotificationAlert(soundKey, soundCustomUrl)` should do.
class NotificationAlertPlan {
  const NotificationAlertPlan({this.customUrl, required this.preset});

  /// Play this URL (fallback to `digital` when it fails).
  final String? customUrl;

  /// Preset to synthesise when there is no custom URL.
  final String preset;

  @override
  String toString() => 'NotificationAlertPlan(customUrl: $customUrl, preset: $preset)';
}

/// Web `playNotificationAlert` decision: `custom` + URL → URL; `custom` without URL →
/// `digital`; anything else → that preset (case-insensitive, default `digital`).
NotificationAlertPlan planNotificationAlert(String? soundKey, [String? soundCustomUrl]) {
  final key = ((soundKey == null || soundKey.isEmpty) ? 'digital' : soundKey).toLowerCase();
  final url = soundCustomUrl?.trim() ?? '';
  if (key == 'custom' && url.isNotEmpty) return NotificationAlertPlan(customUrl: url, preset: 'digital');
  if (key == 'custom') return const NotificationAlertPlan(preset: 'digital');
  return NotificationAlertPlan(preset: key);
}

/// WebAudio stops each oscillator 20 ms after its ramp ends (`osc.stop(t0 + d + 0.02)`).
const int kToneTailMs = 20;

double _wave(ToneWave w, double phase) {
  switch (w) {
    case ToneWave.sine:
      return math.sin(2 * math.pi * phase);
    case ToneWave.square:
      return phase < 0.5 ? 1.0 : -1.0;
    case ToneWave.triangle:
      if (phase < 0.25) return 4 * phase;
      if (phase < 0.75) return 2 - 4 * phase;
      return 4 * phase - 4;
    case ToneWave.sawtooth:
      return phase < 0.5 ? 2 * phase : 2 * phase - 2;
  }
}

/// Total length of a tone schedule in milliseconds (including the 20 ms tail).
int toneScheduleLengthMs(List<ToneSpec> tones) {
  var end = 0;
  for (final t in tones) {
    end = math.max(end, t.startMs + t.durationMs + kToneTailMs);
  }
  return end;
}

/// Mixes [tones] into a mono 16-bit PCM WAV. Each tone decays exponentially from its gain
/// to 0.001 over its duration (web `exponentialRampToValueAtTime(0.001, t0 + d)`).
/// [masterGain] lifts the quiet WebAudio levels to something audible on phone speakers.
Uint8List synthesizeToneWav(List<ToneSpec> tones, {int sampleRate = 22050, double masterGain = 2.5}) {
  final totalMs = toneScheduleLengthMs(tones);
  final frames = (totalMs * sampleRate / 1000).ceil();
  final mix = Float64List(frames);
  for (final t in tones) {
    final start = (t.startMs * sampleRate / 1000).round();
    final rampFrames = math.max(1, (t.durationMs * sampleRate / 1000).round());
    final total = ((t.durationMs + kToneTailMs) * sampleRate / 1000).round();
    const floor = 0.001;
    final ratio = floor / t.gain;
    // Short fades avoid clicks at the hard start / stop of the oscillator.
    final attack = math.max(1, (0.002 * sampleRate).round());
    final release = math.max(1, (0.004 * sampleRate).round());
    for (var i = 0; i < total; i++) {
      final idx = start + i;
      if (idx >= frames) break;
      final progress = i < rampFrames ? i / rampFrames : 1.0;
      var env = t.gain * math.pow(ratio, progress).toDouble();
      if (i < attack) env *= i / attack;
      final fromEnd = total - i;
      if (fromEnd < release) env *= fromEnd / release;
      final phase = (t.frequency * i / sampleRate) % 1.0;
      mix[idx] += env * _wave(t.wave, phase);
    }
  }
  final pcm = Int16List(frames);
  for (var i = 0; i < frames; i++) {
    final v = (mix[i] * masterGain).clamp(-1.0, 1.0);
    pcm[i] = (v * 32767).round();
  }
  return encodeWav16(pcm, sampleRate: sampleRate);
}

/// Wraps mono 16-bit samples in a RIFF/WAVE container.
Uint8List encodeWav16(Int16List samples, {required int sampleRate, int channels = 1}) {
  final dataBytes = samples.length * 2;
  final out = ByteData(44 + dataBytes);
  void ascii(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      out.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  out.setUint32(4, 36 + dataBytes, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  out.setUint32(16, 16, Endian.little); // PCM chunk size
  out.setUint16(20, 1, Endian.little); // PCM format
  out.setUint16(22, channels, Endian.little);
  out.setUint32(24, sampleRate, Endian.little);
  out.setUint32(28, sampleRate * channels * 2, Endian.little); // byte rate
  out.setUint16(32, channels * 2, Endian.little); // block align
  out.setUint16(34, 16, Endian.little); // bits per sample
  ascii(36, 'data');
  out.setUint32(40, dataBytes, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    out.setInt16(44 + i * 2, samples[i], Endian.little);
  }
  return out.buffer.asUint8List();
}
