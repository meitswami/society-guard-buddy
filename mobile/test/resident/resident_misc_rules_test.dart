import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/resident/data/alert_sounds.dart';
import 'package:kutumbika_mobile/features/resident/data/notification_audience.dart';
import 'package:kutumbika_mobile/features/resident/data/pass_rules.dart';

void main() {
  group('notificationVisibleToResident (web notificationAudience.ts)', () {
    bool visible(String type, String id) => notificationVisibleToResident(
          targetType: type,
          targetId: id,
          residentId: 'r-1',
          residentName: 'Asha',
          flatNumber: 'A-101',
        );

    test('society-wide, flat and person targets', () {
      expect(visible('all', ''), isTrue);
      expect(visible('flat', 'A-101'), isTrue);
      expect(visible('flat', 'B-2, A-101'), isTrue);
      expect(visible('flat', 'A-1010'), isFalse);
      expect(visible('user', 'r-1'), isTrue);
      expect(visible('user', 'Asha'), isTrue);
      expect(visible('user', 'x, Asha'), isTrue);
      expect(visible('user', 'r-2'), isFalse);
      expect(visible('role', 'guard'), isFalse);
    });

    test('rows of another society are ignored', () {
      bool row(Map<String, dynamic> r) =>
          notificationRowForResident(r, societyId: 's1', residentId: 'r-1', residentName: 'Asha', flatNumber: 'A-101');
      expect(row({'society_id': 's1', 'target_type': 'all'}), isTrue);
      expect(row({'society_id': 's2', 'target_type': 'all'}), isFalse);
      expect(row({'target_type': 'flat', 'target_id': 'A-101'}), isTrue);
    });
  });

  group('visitor passes', () {
    test('OTP is six digits like the web', () {
      final rng = Random(7);
      for (var i = 0; i < 200; i++) {
        final otp = generatePassOtp(rng);
        expect(otp.length, 6);
        final n = int.parse(otp);
        expect(n >= 100000 && n <= 999999, isTrue);
      }
    });

    test('slot label and share text', () {
      expect(hhmm('09:00:00'), '09:00');
      expect(hhmm(null), '');
      expect(passSlotLabel(validDate: '2026-10-12', start: '09:00:00', end: '18:00:00'), '12/10/2026 · 09:00 – 18:00');
      expect(passSlotLabel(validDate: '2026-10-12'), '12/10/2026');
      final msg = passShareMessage(
        otp: '482913',
        flatNumber: 'A-101',
        societyName: 'Green Park',
        validDate: '2026-10-12',
        guestName: 'Ravi',
        start: '09:00',
        end: '18:00',
      );
      expect(msg, contains('OTP: 482913'));
      expect(msg, contains('Hi Ravi,'));
      expect(msg, contains('12/10/2026 · 09:00 – 18:00'));
      expect(passShareMessage(otp: '1', flatNumber: 'A', societyName: 'S', validDate: '2026-01-01', hindi: true), contains('ओटीपी: 1'));
    });

    test('member invite text never contains a password', () {
      final msg = memberInviteMessage(memberName: 'Asha', phone: '9876543210', flatNumber: 'A-101', societyName: 'Green Park', invitedBy: 'Ravi');
      expect(msg, contains('9876543210'));
      expect(msg.toLowerCase(), contains('flat password'));
    });
  });

  group('alert tones (web notificationSounds.ts)', () {
    test('presets have the web tone counts', () {
      expect(presetTones('digital').length, 2);
      expect(presetTones('chime').length, 2);
      expect(presetTones('melody').length, 4);
      expect(presetTones('bell').length, 2);
      expect(presetTones('siren').length, 4);
      expect(presetTones('custom'), isEmpty);
      expect(presetTones('unknown').first.freq, 1200);
      expect(kApprovalChimeTones.map((t) => t.freq), [800, 1000]);
    });

    test('renders a valid PCM WAV', () {
      final wav = synthesizeWav(kApprovalChimeTones, sampleRate: 8000);
      final bd = ByteData.sublistView(wav);
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      expect(bd.getUint32(24, Endian.little), 8000);
      final frames = (8000 * (350 + 300 + 20) / 1000).ceil();
      expect(bd.getUint32(40, Endian.little), frames * 2);
      expect(wav.length, 44 + frames * 2);
      var peak = 0;
      for (var i = 0; i < frames; i++) {
        peak = max(peak, bd.getInt16(44 + i * 2, Endian.little).abs());
      }
      expect(peak, greaterThan(10000));
    });
  });
}
