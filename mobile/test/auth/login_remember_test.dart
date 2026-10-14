import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/services/login_remember.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('LoginRemember.normalizePhone (web normalizePhone)', () {
    test('keeps last 10 digits of longer numbers', () {
      expect(LoginRemember.normalizePhone('+91 98765 43210'), '9876543210');
      expect(LoginRemember.normalizePhone('0919876543210'), '9876543210');
    });
    test('keeps partial digits and drops empty input', () {
      expect(LoginRemember.normalizePhone('98-76'), '9876');
      expect(LoginRemember.normalizePhone('abc'), isNull);
      expect(LoginRemember.normalizePhone(''), isNull);
      expect(LoginRemember.normalizePhone(null), isNull);
    });
  });

  group('LoginRemember.merge (web writeLoginRemember)', () {
    const prev = LoginRememberData(societyId: 's1', role: 'resident', flatId: 'f1', phone: '9876543210');

    test('keys not in the patch keep previous values', () {
      expect(LoginRemember.merge(prev, {'phone': '9999988888'}),
          const LoginRememberData(societyId: 's1', role: 'resident', flatId: 'f1', phone: '9999988888'));
    });

    test('society change clears role and flat (blank / null clears)', () {
      expect(LoginRemember.merge(prev, {'societyId': 's2', 'role': null, 'flatId': ''}),
          const LoginRememberData(societyId: 's2', phone: '9876543210'));
    });

    test('society id is trimmed; blank society clears it', () {
      expect(LoginRemember.merge(null, {'societyId': '  s3 '}).societyId, 's3');
      expect(LoginRemember.merge(prev, {'societyId': '   '}).societyId, isNull);
    });

    test('phone is normalised on write', () {
      expect(LoginRemember.merge(null, {'phone': '+91-98765-43210'}).phone, '9876543210');
    });

    test('validRole only accepts guard / admin / resident', () {
      expect(const LoginRememberData(role: 'guard').validRole, 'guard');
      expect(const LoginRememberData(role: 'superadmin').validRole, isNull);
    });
  });

  group('encode / decode', () {
    test('round trip with v: 1', () {
      const d = LoginRememberData(societyId: 's', role: 'admin');
      final raw = LoginRemember.encode(d);
      expect(raw, contains('"v":1'));
      expect(LoginRemember.decode(raw), d);
    });
    test('rejects other versions and corrupt json', () {
      expect(LoginRemember.decode('{"v":2,"societyId":"x"}'), isNull);
      expect(LoginRemember.decode('not json'), isNull);
      expect(LoginRemember.decode(null), isNull);
    });
  });

  group('storage', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('patch merges into the stored value', () async {
      await LoginRemember.patch({'societyId': 's1', 'role': 'resident', 'flatId': 'f1'});
      await LoginRemember.patch({'phone': '9876543210'});
      expect(await LoginRemember.read(), const LoginRememberData(societyId: 's1', role: 'resident', flatId: 'f1', phone: '9876543210'));
    });

    test('legacy write API still works', () async {
      await LoginRemember.write(societyId: 's1', role: 'guard', phone: '9876543210');
      await LoginRemember.write(societyId: 's2', clearRole: true, clearFlat: true);
      expect(await LoginRemember.read(), const LoginRememberData(societyId: 's2', phone: '9876543210'));
    });

    test('family tab flag is consumed once', () async {
      await LoginRemember.setOpenFamilyTab();
      expect(await LoginRemember.consumeOpenFamilyTab(), isTrue);
      expect(await LoginRemember.consumeOpenFamilyTab(), isFalse);
    });
  });
}
