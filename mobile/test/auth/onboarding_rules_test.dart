import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/models/flat_member.dart';
import 'package:kutumbika_mobile/services/resident_onboarding_service.dart';

FlatMember _m(String id, {String? phone, String? relation, bool primary = false}) =>
    FlatMember(id: id, name: 'M$id', flatId: 'f', phone: phone, relation: relation, isPrimary: primary);

void main() {
  group('pickPrimaryMember', () {
    test('is_primary wins', () {
      expect(pickPrimaryMember([_m('1', relation: 'owner'), _m('2', relation: 'son', primary: true)])!.id, '2');
    });
    test('else first household member allowed as primary (not tenant / staff)', () {
      expect(pickPrimaryMember([_m('1', relation: 'tenant'), _m('2', relation: 'cook'), _m('3', relation: 'Daughter')])!.id, '3');
    });
    test('none when only tenants / staff', () {
      expect(pickPrimaryMember([_m('1', relation: 'tenant'), _m('2', relation: 'maid')]), isNull);
    });
  });

  group('decideResidentOnboarding (web completeResidentOtpOnboarding)', () {
    test('empty flat → first primary', () {
      expect(decideResidentOnboarding(members: const [], phone: '9876543210').kind, OnboardingStepKind.firstPrimary);
    });
    test('no possible primary → household not set up', () {
      expect(decideResidentOnboarding(members: [_m('1', relation: 'driver')], phone: '9876543210').kind, OnboardingStepKind.noPrimary);
    });
    test('primary already has this phone → link', () {
      final d =
          decideResidentOnboarding(members: [_m('1', relation: 'owner', primary: true, phone: '+91 98765 43210')], phone: '9876543210');
      expect(d.kind, OnboardingStepKind.linkPrimary);
      expect(d.primary!.id, '1');
    });
    test('primary without phone → ask to claim', () {
      expect(decideResidentOnboarding(members: [_m('1', relation: 'owner', primary: true, phone: '')], phone: '9876543210').kind,
          OnboardingStepKind.claimPrimary);
      expect(decideResidentOnboarding(members: [_m('1', relation: 'owner', primary: true, phone: '--')], phone: '9876543210').kind,
          OnboardingStepKind.claimPrimary);
    });
    test('primary with another phone → new household member', () {
      expect(decideResidentOnboarding(members: [_m('1', relation: 'owner', primary: true, phone: '9000000000')], phone: '9876543210').kind,
          OnboardingStepKind.newMember);
    });
  });

  group('member payloads', () {
    test('first primary is owner + primary, blank gender → null', () {
      expect(buildFirstPrimaryPayload(flatId: 'f', name: 'Asha', phone: '+919876543210', gender: ''), {
        'flat_id': 'f',
        'name': 'Asha',
        'phone': '9876543210',
        'relation': 'owner',
        'gender': null,
        'is_primary': true,
      });
    });
    test('household member has no ID photos / police status', () {
      final p =
          buildNewMemberPayload(flatId: 'f', name: 'Ravi', phone: '9876543210', relation: 'son', gender: 'Male', idPhotoFront: 'data:x');
      expect(p['id_photo_front'], isNull);
      expect(p['police_verification'], isNull);
      expect(p['is_primary'], isFalse);
    });
    test('staff member carries ID photos and police status (default pending)', () {
      final p = buildNewMemberPayload(
          flatId: 'f', name: 'Sita', phone: '9876543210', relation: 'maid', gender: 'Female', idPhotoFront: 'data:a', idPhotoBack: '');
      expect(p['id_photo_front'], 'data:a');
      expect(p['id_photo_back'], isNull);
      expect(p['police_verification'], 'pending');
    });
  });

  test('flat password format: Animal + Fruit + 2 digits + symbol', () {
    final pw = generateWebFlatPassword(Random(1));
    expect(RegExp(r'^[A-Z][a-z]+[A-Z][a-z]+\d{2}[@#$!&*%]$').hasMatch(pw), isTrue, reason: pw);
  });
}
