import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/auth/data/login_geofence.dart';
import 'package:kutumbika_mobile/features/auth/data/login_logic.dart';
import 'package:kutumbika_mobile/features/public/data/society_signup_service.dart';

void main() {
  test('superadmin entry only on desktop-wide screens', () {
    expect(showSuperadminEntryForWidth(1023), isFalse);
    expect(showSuperadminEntryForWidth(1024), isTrue);
  });

  test('biometric button visibility (web showBiometric)', () {
    bool show({bool supported = true, String society = 's', bool sa = false, LoginRole? role = LoginRole.guard, String flat = ''}) =>
        showBiometricLogin(deviceSupported: supported, societyId: society, superadminMode: sa, role: role, flatId: flat);
    expect(show(), isTrue);
    expect(show(supported: false), isFalse);
    expect(show(society: ''), isFalse);
    expect(show(sa: true), isFalse);
    expect(show(role: null), isFalse);
    expect(show(role: LoginRole.resident), isFalse);
    expect(show(role: LoginRole.resident, flat: 'f'), isTrue);
  });

  test('role keys', () {
    expect(loginRoleFromKey('admin'), LoginRole.admin);
    expect(loginRoleFromKey(''), isNull);
  });

  group('describeOtpError (web formatFirebaseAuthError)', () {
    test('known codes with or without auth/ prefix', () {
      expect(describeOtpError('auth/invalid-verification-code').en, 'Invalid code.');
      expect(describeOtpError('too-many-requests').en, 'Too many attempts. Try again later.');
      expect(describeOtpError('session-expired').en, 'Code expired. Request a new one.');
      expect(describeOtpError('session-missing').en, 'Session expired. Tap Resend OTP.');
    });
    test('unknown code shows message + code; empty code is generic', () {
      expect(describeOtpError('weird', message: 'Boom').en, 'Boom (weird)');
      expect(describeOtpError('weird').en, 'Something went wrong (weird).');
      expect(describeOtpError(null).en, 'Something went wrong. Try again.');
    });
  });

  group('password reset rules', () {
    test('identifier sanitising', () {
      expect(sanitizeResetIdentifier(method: ResetMethod.phone, userType: ResetUserType.resident, input: '98-765 43210 1'), '9876543210');
      expect(sanitizeResetIdentifier(method: ResetMethod.phone, userType: ResetUserType.guard, input: '987654321099'), '9876543210');
      expect(sanitizeResetIdentifier(method: ResetMethod.phone, userType: ResetUserType.guard, input: 'g001'), 'G001');
      expect(sanitizeResetIdentifier(method: ResetMethod.email, userType: ResetUserType.guard, input: 'a@b.in'), 'a@b.in');
    });
    test('guard lookup by phone needs 10 digits', () {
      expect(guardResetPhoneLast10('+91 98765 43210'), '9876543210');
      expect(guardResetPhoneLast10('G001'), isNull);
    });
    test('code is 6 digits', () {
      final c = generateResetCode(Random(3));
      expect(c.length, 6);
      expect(int.parse(c) >= 100000, isTrue);
    });
    test('validation order', () {
      expect(validateResetInput(token: '1', expectedToken: '2', newPassword: 'abcd', confirmPassword: 'abcd'),
          ResetPasswordProblem.invalidCode);
      expect(validateResetInput(token: '1', expectedToken: '1', newPassword: 'abc', confirmPassword: 'abc'), ResetPasswordProblem.tooShort);
      expect(
          validateResetInput(token: '1', expectedToken: '1', newPassword: 'abcd', confirmPassword: 'abce'), ResetPasswordProblem.mismatch);
      expect(validateResetInput(token: '1', expectedToken: '1', newPassword: 'abcd', confirmPassword: 'abcd'), isNull);
    });
    test('admin notification message (English, as web)', () {
      expect(
        buildResetRequestMessage(userName: 'Asha', userType: 'resident', flatNumber: 'A-101', identifier: '9876543210'),
        "Asha (resident, Flat A-101) is requesting a password reset. They don't have an email set. "
        'Please reset their password from the admin panel.',
      );
      expect(
          buildResetRequestMessage(userName: 'X', userType: 'admin', flatNumber: '', identifier: 'ADMIN'), contains('(admin, ID: ADMIN)'));
    });
  });

  test('geofence distance rule', () {
    const fence = GeofenceRow(latitude: 28.6139, longitude: 77.2090, radiusMeters: 100);
    expect(evaluateGeofence(latitude: 28.6139, longitude: 77.2090, fence: fence).ok, isTrue);
    final far = evaluateGeofence(latitude: 28.6239, longitude: 77.2090, fence: fence);
    expect(far.ok, isFalse);
    expect(far.reason, GeofenceBlockReason.outside);
    expect(far.distanceM!, greaterThan(1000));
  });

  group('society signup', () {
    test('canSubmit needs name, phone, admin id and password', () {
      expect(const SocietySignupDraft(societyName: 'A', contactPhone: '9', adminId: 'AD', adminPassword: 'x').canSubmit, isTrue);
      expect(const SocietySignupDraft(societyName: 'A', contactPhone: ' ', adminId: 'AD', adminPassword: 'x').canSubmit, isFalse);
    });
    test('body trims required fields', () {
      final b =
          const SocietySignupDraft(societyName: ' A ', contactPhone: ' 9 ', adminId: ' AD ', adminPassword: ' pw ', city: ' C ').toBody();
      expect(b['society_name'], 'A');
      expect(b['contact_phone'], '9');
      expect(b['admin_id'], 'AD');
      expect(b['admin_password'], 'pw');
      expect(b['city'], ' C ');
    });
    test('status title and terminal states', () {
      expect(signupStatusTitle('pending').key, 'signup.successPending');
      expect(signupStatusTitle('paid').key, 'signup.successPending');
      expect(signupStatusTitle('provisioned').key, 'signup.successDone');
      expect(signupStatusTitle('failed').literal, 'FAILED');
      expect(signupStatusTitle('').key, 'signup.successProvisioning');
      expect(signupStatusIsTerminal('cancelled'), isTrue);
      expect(signupStatusIsTerminal('pending'), isFalse);
    });
    test('pending signup json', () {
      const p = PendingSocietySignup(signupId: 'id', token: 't', redirectUrl: 'u');
      expect(PendingSocietySignup.fromJson(p.toJson())!.signupId, 'id');
      expect(PendingSocietySignup.fromJson({'signupId': '', 'token': 't'}), isNull);
    });
  });
}
