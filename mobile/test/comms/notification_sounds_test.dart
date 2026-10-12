import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/comms/data/notification_sounds.dart';

String _ascii(Uint8List b, int start, int len) => String.fromCharCodes(b.sublist(start, start + len));

void main() {
  group('presets (web NOTIFICATION_SOUND_PRESETS)', () {
    test('ids in web order', () {
      expect(kNotificationSoundPresets.map((p) => p.id), ['digital', 'chime', 'melody', 'bell', 'siren', 'custom']);
    });

    test('tone schedules match playPresetNotificationSound', () {
      expect(presetTones('digital'), const [
        ToneSpec(0, 1200, 80, ToneWave.square, 0.08),
        ToneSpec(70, 900, 90, ToneWave.square, 0.06),
      ]);
      expect(presetTones('chime').map((t) => t.startMs), [0, 90]);
      expect(presetTones('melody').map((t) => t.frequency), [523, 659, 784, 1047]);
      expect(presetTones('bell').every((t) => t.wave == ToneWave.triangle), isTrue);
      expect(presetTones('siren').map((t) => t.startMs), [0, 90, 180, 270]);
      expect(presetTones('custom'), isEmpty);
      expect(presetTones('unknown-key'), presetTones('digital'));
    });
  });

  group('planNotificationAlert (web playNotificationAlert)', () {
    test('custom with URL plays the URL', () {
      final p = planNotificationAlert('custom', '  https://s/tune.mp3 ');
      expect(p.customUrl, 'https://s/tune.mp3');
    });

    test('custom without URL falls back to digital', () {
      final p = planNotificationAlert('custom', '   ');
      expect(p.customUrl, isNull);
      expect(p.preset, 'digital');
    });

    test('preset keys are case-insensitive, empty → digital', () {
      expect(planNotificationAlert('CHIME').preset, 'chime');
      expect(planNotificationAlert(null).preset, 'digital');
      expect(planNotificationAlert('').preset, 'digital');
      expect(planNotificationAlert('siren', 'https://ignored').customUrl, isNull);
    });
  });

  group('WAV synthesis', () {
    test('schedule length includes the 20 ms oscillator tail', () {
      expect(toneScheduleLengthMs(presetTones('digital')), 70 + 90 + 20);
      expect(toneScheduleLengthMs(presetTones('melody')), 420 + 220 + 20);
      expect(toneScheduleLengthMs(const []), 0);
    });

    test('valid RIFF/WAVE header and data size', () {
      const sr = 8000;
      final wav = synthesizeToneWav(presetTones('chime'), sampleRate: sr);
      expect(_ascii(wav, 0, 4), 'RIFF');
      expect(_ascii(wav, 8, 4), 'WAVE');
      expect(_ascii(wav, 12, 4), 'fmt ');
      expect(_ascii(wav, 36, 4), 'data');
      final bd = ByteData.sublistView(wav);
      expect(bd.getUint16(20, Endian.little), 1, reason: 'PCM');
      expect(bd.getUint16(22, Endian.little), 1, reason: 'mono');
      expect(bd.getUint32(24, Endian.little), sr);
      expect(bd.getUint16(34, Endian.little), 16);
      final frames = (toneScheduleLengthMs(presetTones('chime')) * sr / 1000).ceil();
      expect(bd.getUint32(40, Endian.little), frames * 2);
      expect(wav.length, 44 + frames * 2);
      expect(bd.getUint32(4, Endian.little), wav.length - 8);
    });

    test('audible but never clipped hard, and decays toward the end', () {
      const sr = 8000;
      final wav = synthesizeToneWav(presetTones('bell'), sampleRate: sr);
      final bd = ByteData.sublistView(wav);
      final n = (wav.length - 44) ~/ 2;
      var peak = 0;
      var tailPeak = 0;
      for (var i = 0; i < n; i++) {
        final s = bd.getInt16(44 + i * 2, Endian.little).abs();
        if (s > peak) peak = s;
        if (i > n - (sr * 0.03)) tailPeak = s > tailPeak ? s : tailPeak;
      }
      expect(peak, greaterThan(3000));
      expect(peak, lessThanOrEqualTo(32767));
      expect(tailPeak, lessThan(peak ~/ 4));
    });

    test('encodeWav16 wraps raw samples', () {
      final wav = encodeWav16(Int16List.fromList([0, 1000, -1000]), sampleRate: 16000);
      final bd = ByteData.sublistView(wav);
      expect(wav.length, 44 + 6);
      expect(bd.getInt16(46, Endian.little), 1000);
      expect(bd.getInt16(48, Endian.little), -1000);
      expect(bd.getUint32(28, Endian.little), 32000, reason: 'byte rate');
    });
  });
}
