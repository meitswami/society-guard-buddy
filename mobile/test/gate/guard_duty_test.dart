import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kutumbika_mobile/features/gate/data/guard_duty_types.dart';
import 'package:kutumbika_mobile/features/gate/widgets/gate_photo.dart';
import 'package:kutumbika_mobile/features/guard/guard_geofence_monitor.dart';
import 'package:kutumbika_mobile/services/visitor_pass_verify_service.dart';

GuardDutyBundle bundle(
        {List<GuardDutyStaffAttendance> staff = const [],
        List<GuardDutySystemCheck> checks = const []}) =>
    GuardDutyBundle(
      duty: const GuardDailyDuty(
        id: 'd',
        societyId: 's',
        guardUuid: 'u',
        guardId: 'G',
        guardName: 'N',
        shiftId: 'sh',
        dutyDate: '2026-10-12',
        status: 'in_progress',
      ),
      staff: staff,
      checks: checks,
      incidents: const [],
    );

void main() {
  group('guard duty', () {
    test('seed rows cover every staff role and check', () {
      final staff = staffSeedRows('d1');
      expect(staff, hasLength(kStaffRoles.length));
      expect(staff.first,
          {'duty_id': 'd1', 'staff_role': 'gardener', 'status': 'not_marked'});
      final checks = checkSeedRows('d1');
      expect(checks, hasLength(9));
      expect(checks.every((c) => c['status'] == 'not_checked'), isTrue);
    });

    test('status tones (web statusColor)', () {
      expect(dutyStatusTone('present'), DutyTone.success);
      expect(dutyStatusTone('ok'), DutyTone.success);
      expect(dutyStatusTone('absent'), DutyTone.danger);
      expect(dutyStatusTone('not_working'), DutyTone.danger);
      expect(dutyStatusTone('late'), DutyTone.warning);
      expect(dutyStatusTone('problem'), DutyTone.warning);
      expect(dutyStatusTone('not_marked'), DutyTone.none);
    });

    test('reason / preset are only kept where the web keeps them', () {
      expect(attendanceNeedsReason('absent'), isTrue);
      expect(attendanceNeedsReason('present'), isFalse);
      expect(attendanceReasonToSave('late', 'sick'), 'sick');
      expect(attendanceReasonToSave('present', 'sick'), isNull);
      expect(checkPresetToSave('ok', 'stuck'), isNull);
      expect(checkPresetToSave('not_checked', 'stuck'), isNull);
      expect(checkPresetToSave('problem', 'stuck'), 'stuck');
      expect(checkNeedsPreset('not_working'), isTrue);
    });

    test('every check and incident category has presets', () {
      for (final c in kSystemChecks) {
        expect(kProblemPresets[c.key], isNotEmpty, reason: c.key);
      }
      for (final c in kIncidentCategories) {
        expect(kIncidentPresets[c.key], isNotEmpty, reason: c.key);
      }
    });

    test('admin review summary: absent / late staff and problem checks', () {
      final b = bundle(
        staff: const [
          GuardDutyStaffAttendance(
              id: '1',
              dutyId: 'd',
              staffRole: 'gardener',
              status: 'absent',
              absenceReason: 'sick'),
          GuardDutyStaffAttendance(
              id: '2', dutyId: 'd', staffRole: 'sweeper', status: 'present'),
          GuardDutyStaffAttendance(
              id: '3', dutyId: 'd', staffRole: 'plumber', status: 'late'),
        ],
        checks: const [
          GuardDutySystemCheck(
              id: 'a',
              dutyId: 'd',
              checkKey: 'lift',
              status: 'problem',
              problemPreset: 'stuck'),
          GuardDutySystemCheck(
              id: 'b', dutyId: 'd', checkKey: 'water', status: 'ok'),
          GuardDutySystemCheck(
              id: 'c', dutyId: 'd', checkKey: 'cctv', status: 'not_working'),
        ],
      );
      expect(
          dutyAbsentStaff(b).map((s) => s.staffRole), ['gardener', 'plumber']);
      expect(dutyProblemChecks(b).map((c) => c.checkKey), ['lift', 'cctv']);
      expect(staffRowFor(b, 'sweeper')?.status, 'present');
      expect(checkRowFor(b, 'gate'), isNull);
      expect(findIcon(kSystemChecks, 'lift'), '🛗');
    });

    test('row parsing and duty date', () {
      final inc = GuardDutyIncident.fromRow({
        'id': 'i',
        'duty_id': 'd',
        'category': 'breakage',
        'severity': 'high',
        'photo_urls': ['data:image/jpeg;base64,AA'],
      });
      expect(inc.photoUrls, hasLength(1));
      expect(
          GuardDutyIncident.fromRow({'id': 'i', 'photo_urls': null}).photoUrls,
          isEmpty);
      expect(parseDutyDate('2026-10-12'), DateTime(2026, 10, 12));
      expect(parseDutyDate('bad'), isNull);
    });
  });

  group('geofence breach tracker', () {
    test('arms only after a fix inside, alerts once, re-arms inside', () {
      final t = GeofenceBreachTracker();
      expect(t.onFix(distanceMeters: 500, radiusMeters: 100), isNull,
          reason: 'not armed yet');
      expect(t.onLocationLost(), isNull);
      expect(t.onFix(distanceMeters: 50, radiusMeters: 100), isNull);
      expect(t.onFix(distanceMeters: 150, radiusMeters: 100),
          GeofenceBreach.outsideRadius);
      expect(t.onFix(distanceMeters: 160, radiusMeters: 100), isNull,
          reason: 'one alert per breach');
      expect(t.onLocationLost(), isNull);
      expect(t.onFix(distanceMeters: 100, radiusMeters: 100), isNull);
      expect(t.onLocationLost(), GeofenceBreach.locationDisabled);
    });
  });

  group('visitor pass', () {
    test('time slot check', () {
      expect(isWithinPassTimeSlot('10:00:00', null, null), isTrue);
      expect(isWithinPassTimeSlot('10:00:00', '09:00:00', '11:00:00'), isTrue);
      expect(isWithinPassTimeSlot('08:59:59', '09:00:00', '11:00:00'), isFalse);
      expect(isWithinPassTimeSlot('11:00:01', '09:00:00', '11:00:00'), isFalse);
      expect(isWithinPassTimeSlot('11:00:00', '09:00:00', '11:00:00'), isTrue);
    });

    test('error keys', () {
      expect(
          const PassVerifyResult.failed(PassVerifyError.outsideTimeSlot)
              .errorKey,
          'otp.outsideTimeSlot');
      expect(
          const PassVerifyResult.failed(PassVerifyError.enterSixDigit).errorKey,
          'otp.enterSixDigit');
      expect(
          const PassVerifyResult.ok(
                  VerifiedPass(guestName: 'G', flatNumber: '1', guestPhone: ''))
              .isValid,
          isTrue);
    });
  });

  test('photo compression keeps the long side at 800px as JPEG', () {
    final big = img.Image(width: 1600, height: 1200);
    final out = compressJpegBytes(Uint8List.fromList(img.encodePng(big)));
    final decoded = img.decodeJpg(out)!;
    expect(decoded.width, 800);
    expect(decoded.height, 600);
    final small = compressJpegBytes(
        Uint8List.fromList(img.encodePng(img.Image(width: 300, height: 200))));
    expect(img.decodeJpg(small)!.width, 300);
  });
}
