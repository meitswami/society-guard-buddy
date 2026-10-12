import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/auth/data/login_logic.dart';
import 'package:kutumbika_mobile/services/resident_login_service.dart';

GuardLoginRow _g(String id, {String? phone, String? mode}) =>
    GuardLoginRow(id: 'db-$id', guardId: id, name: 'Guard $id', password: 'pw', phone: phone, authMode: mode);

void main() {
  group('normalizeLoginPhone (web residentLoginOnboarding)', () {
    test('last 10 digits / digits only', () {
      expect(normalizeLoginPhone('+91 98765-43210'), '9876543210');
      expect(normalizeLoginPhone('919876543210'), '9876543210');
      expect(normalizeLoginPhone('98765'), '98765');
      expect(normalizeLoginPhone(''), '');
    });
  });

  group('phone input boxes keep the first 10 digits', () {
    test('phoneInputDigits', () {
      expect(phoneInputDigits('98a76-54 3210 99'), '9876543210');
      expect(phoneInputDigits('12'), '12');
    });
    test('credential identifier: resident phone normalised, ids trimmed', () {
      expect(credentialIdentifier(LoginRole.resident, ' +91 98765 43210 '), '9876543210');
      expect(credentialIdentifier(LoginRole.guard, ' g001 '), 'g001');
    });
  });

  group('classifyGuardOtpCandidates (web findGuardForOtpLogin)', () {
    test('short phone → not found', () {
      final r = classifyGuardOtpCandidates([_g('G1', phone: '98765', mode: 'otp')], '98765');
      expect(r, isA<GuardOtpNotFound>().having((x) => x.reason, 'reason', GuardOtpFailureReason.notFound));
    });
    test('match on last 10 digits with otp mode', () {
      final r = classifyGuardOtpCandidates(
        [_g('G1', phone: '+91 9876543210', mode: 'password'), _g('G2', phone: '09876543210', mode: 'otp')],
        '9876543210',
      );
      expect(r, isA<GuardOtpFound>().having((x) => x.guard.guardId, 'guardId', 'G2'));
    });
    test('phone registered but password mode', () {
      final r = classifyGuardOtpCandidates([_g('G1', phone: '9876543210', mode: 'password')], '9876543210');
      expect(r, isA<GuardOtpNotFound>().having((x) => x.reason, 'reason', GuardOtpFailureReason.passwordMode));
    });
    test('no guard with this phone', () {
      final r = classifyGuardOtpCandidates([_g('G1', phone: null, mode: 'otp')], '9876543210');
      expect(r, isA<GuardOtpNotFound>().having((x) => x.reason, 'reason', GuardOtpFailureReason.notFound));
    });
  });
}
