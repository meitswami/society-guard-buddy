import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/admin/people/data/people_models.dart';
import 'package:kutumbika_mobile/features/admin/people/logic/residents_logic.dart';
import 'package:kutumbika_mobile/utils/member_categories.dart';
import 'package:kutumbika_mobile/utils/password_generator.dart';

void main() {
  group('member categories (web memberCategories.ts)', () {
    test('login + primary rules', () {
      for (final r in ['owner', 'Spouse', ' SON ', 'daughter', 'father', 'mother', 'family', 'brother', 'sister', 'tenant']) {
        expect(allowsResidentLogin(r), isTrue, reason: r);
      }
      expect(allowsPrimaryMember('tenant'), isFalse);
      expect(allowsPrimaryMember('owner'), isTrue);
      expect(allowsResidentLogin('cook'), isFalse);
      expect(allowsResidentLogin('other'), isFalse);
      expect(allowsResidentLogin(null), isFalse);
      expect(isRestrictedMemberCategory('maid'), isTrue);
      expect(isRestrictedMemberCategory('plumber'), isTrue);
      expect(isRestrictedMemberCategory('tenant'), isFalse);
      expect(kStaffVehicleTypes, ['car', 'cycle', 'bike', 'activa', 'auto', 'other']);
    });

    test('quick entry staff (web memberStaff.ts)', () {
      expect(isQuickEntryStaffMember(relation: 'cook', isPrimary: false), isTrue);
      expect(isQuickEntryStaffMember(relation: 'Plumber', isPrimary: false), isTrue);
      expect(isQuickEntryStaffMember(relation: 'others', isPrimary: false), isFalse);
      expect(isQuickEntryStaffMember(relation: 'tenant', isPrimary: false), isFalse);
      expect(isQuickEntryStaffMember(relation: 'cook', isPrimary: true), isFalse);
      expect(isQuickEntryStaffMember(relation: '', isPrimary: false), isFalse);
      expect(staffMemberSyntheticPhone('123e4567-e89b-12d3-a456-426614174000'), 'staff-123e4567e89b12d3');
      expect(quickEntryPhoneForMember(memberId: 'abc', phone: '+91 98765 43210'), '9876543210');
      expect(quickEntryPhoneForMember(memberId: 'abc', phone: '123'), 'staff-abc');
      expect(isKnownHouseholdServiceType(' Driver '), isTrue);
      expect(isKnownHouseholdServiceType('plumber'), isFalse);
    });
  });

  test('generateFlatPassword shape', () {
    final r = Random(7);
    for (var i = 0; i < 50; i++) {
      final p = generateFlatPassword(r);
      expect(RegExp(r'^[A-Z][a-z]+[A-Z][a-z]+[1-9]\d[@#$!&*%]$').hasMatch(p), isTrue, reason: p);
      final n = int.parse(RegExp(r'\d+').firstMatch(p)!.group(0)!);
      expect(n, inInclusiveRange(10, 99));
    }
  });

  group('validateMemberForm', () {
    test('name and relation required', () {
      expect(validateMemberForm(form: MemberFormState(), docs: []), MemberFormIssue.nameRequired);
      expect(validateMemberForm(form: MemberFormState(name: 'A', relation: ''), docs: []), MemberFormIssue.relationRequired);
      expect(validateMemberForm(form: MemberFormState(name: 'A', relation: 'son'), docs: []), isNull);
    });

    test('tenant needs photo ID and rental agreement', () {
      final f = MemberFormState(name: 'T', relation: 'tenant');
      expect(validateMemberForm(form: f, docs: []), MemberFormIssue.tenantPhotoId);
      final pid = MemberDocDraft(kind: MemberDocKind.photoId, type: 'aadhaar', front: 'data:x');
      expect(validateMemberForm(form: f, docs: [pid]), MemberFormIssue.tenantAgreement);
      final agr = MemberDocDraft(kind: MemberDocKind.tenantDoc, type: 'rental_agreement', front: 'data:y');
      expect(validateMemberForm(form: f, docs: [pid, agr]), isNull);
      // Empty-front drafts do not count.
      expect(
        validateMemberForm(form: f, docs: [MemberDocDraft(kind: MemberDocKind.photoId, type: 'pan'), agr]),
        MemberFormIssue.tenantPhotoId,
      );
    });

    test('staff need a photo ID (legacy front accepted)', () {
      final f = MemberFormState(name: 'S', relation: 'cook');
      expect(validateMemberForm(form: f, docs: []), MemberFormIssue.restrictedPhotoId);
      final legacy = PeopleMember.fromJson({'id': 'm', 'flat_id': 'f', 'name': 'S', 'id_photo_front': 'data:z'});
      expect(validateMemberForm(form: f, docs: [], editing: legacy), isNull);
      expect(validateMemberForm(form: MemberFormState(name: 'S', relation: 'cook', idPhotoFront: 'data:q'), docs: []), isNull);
    });
  });

  group('primary decision', () {
    test('first household member becomes primary', () {
      expect(
        decideIsPrimary(relation: 'owner', isEditing: false, previousWasPrimary: false, flatMemberCount: 0, primaryExists: false, formIsPrimary: false),
        isTrue,
      );
      expect(
        decideIsPrimary(relation: 'tenant', isEditing: false, previousWasPrimary: false, flatMemberCount: 0, primaryExists: false, formIsPrimary: true),
        isFalse,
      );
    });

    test('checkbox only when no primary exists', () {
      expect(showPrimaryCheckbox(relation: 'son', primaryExists: false, flatMemberCount: 2), isTrue);
      expect(showPrimaryCheckbox(relation: 'son', primaryExists: true, flatMemberCount: 2), isFalse);
      expect(showPrimaryCheckbox(relation: 'son', primaryExists: false, flatMemberCount: 0), isFalse);
      expect(
        decideIsPrimary(relation: 'son', isEditing: false, previousWasPrimary: false, flatMemberCount: 2, primaryExists: false, formIsPrimary: true),
        isTrue,
      );
      expect(
        decideIsPrimary(relation: 'son', isEditing: false, previousWasPrimary: false, flatMemberCount: 2, primaryExists: true, formIsPrimary: true),
        isFalse,
      );
    });

    test('editing keeps primary; switching to staff drops it', () {
      expect(
        decideIsPrimary(relation: 'owner', isEditing: true, previousWasPrimary: true, flatMemberCount: 3, primaryExists: true, formIsPrimary: false),
        isTrue,
      );
      expect(
        decideIsPrimary(relation: 'driver', isEditing: true, previousWasPrimary: true, flatMemberCount: 3, primaryExists: true, formIsPrimary: true),
        isFalse,
      );
    });
  });

  group('payloads', () {
    test('household member clears restricted fields', () {
      final p = buildMemberPayload(
        flatId: 'f1',
        form: MemberFormState(name: 'Ravi', phone: '9811111111', email: '  r@x.com ', relation: 'Owner', age: '42', gender: 'Male', idPhotoFront: 'data:a', spouseName: 'S'),
        docs: [],
        isPrimary: true,
      );
      expect(p['household_group'], 'owner');
      expect(p['email'], 'r@x.com');
      expect(p['age'], 42);
      expect(p['whatsapp_phone'], isNull);
      expect(p['photo'], isNull);
      expect(p['id_photo_front'], isNull);
      expect(p['spouse_name'], isNull);
      expect(p['is_primary'], isTrue);
    });

    test('tenant keeps docs; best photo ID wins over legacy', () {
      final p = buildMemberPayload(
        flatId: 'f1',
        form: MemberFormState(name: 'T', relation: 'tenant', idPhotoFront: 'legacyF', idPhotoBack: 'legacyB', policeVerification: ' verified ', dateJoining: '2026-01-01', age: 'x'),
        docs: [
          MemberDocDraft(kind: MemberDocKind.tenantDoc, type: 'rental_agreement', front: 'agr'),
          MemberDocDraft(kind: MemberDocKind.photoId, type: 'aadhaar', front: 'pidF'),
        ],
        isPrimary: false,
      );
      expect(p['household_group'], 'tenant');
      expect(p['id_photo_front'], 'pidF');
      expect(p['id_photo_back'], 'legacyB');
      expect(p['police_verification'], 'verified');
      expect(p['date_joining'], '2026-01-01');
      expect(p['date_leave'], isNull);
      expect(p['age'], isNull);
    });

    test('member document rows skip empty drafts', () {
      final rows = memberDocumentRows('m1', [
        MemberDocDraft(kind: MemberDocKind.photoId, type: 'aadhaar', front: 'f', back: ''),
        MemberDocDraft(kind: MemberDocKind.serviceDoc, type: 'id_proof'),
        MemberDocDraft(kind: MemberDocKind.tenantDoc, type: '', front: 'x'),
      ]);
      expect(rows, [
        {'member_id': 'm1', 'doc_kind': 'photo_id', 'doc_type': 'aadhaar', 'front_url': 'f', 'back_url': null},
      ]);
    });

    test('staff vehicle row', () {
      expect(
        staffVehicleRow(societyId: 's', memberId: 'm', flatId: 'f', flatNumber: '101', residentName: 'L', form: MemberFormState()),
        isNull,
      );
      final row = staffVehicleRow(
        societyId: 's',
        memberId: 'm',
        flatId: 'f',
        flatNumber: '101',
        residentName: 'L',
        form: MemberFormState(vehicleName: ' Activa '),
      )!;
      expect(row['vehicle_number'], 'N/A');
      expect(row['vehicle_type'], 'other');
      expect(row['vehicle_display_name'], 'Activa');
      expect(row['vehicle_color'], isNull);
    });
  });

  test('planNewResidentLogins reuses the flat password', () {
    final plan = planNewResidentLogins(
      latestMembers: [
        {'name': 'Owner', 'phone': '9000000001', 'relation': 'owner', 'is_primary': true},
        {'name': 'Kid', 'phone': '9000000002', 'relation': 'son', 'is_primary': false},
        {'name': 'Cook', 'phone': '9000000003', 'relation': 'cook'},
        {'name': 'NoPhone', 'phone': '', 'relation': 'spouse'},
      ],
      existingUsers: [
        {'phone': '9000000002', 'password': 'TigerMango10@'},
      ],
      flatId: 'f1',
      flatNumber: '101',
      newPassword: () => 'NEW',
    );
    expect(plan, [
      {'name': 'Owner', 'phone': '9000000001', 'flat_id': 'f1', 'flat_number': '101', 'password': 'TigerMango10@', 'must_change_password': true},
    ]);
    final fresh = planNewResidentLogins(
      latestMembers: [
        {'name': 'Kid', 'phone': '9000000002', 'relation': 'son'},
      ],
      existingUsers: const [],
      flatId: 'f1',
      flatNumber: '101',
      newPassword: () => 'NEW',
    );
    expect(fresh.single['password'], 'NEW');
    expect(fresh.single['must_change_password'], isFalse);
  });

  test('search helpers', () {
    final flats = [
      PeopleFlat.fromJson({'id': 'f1', 'flat_number': 'A-101', 'owner_name': 'Ravi', 'owner_phone': '981'}),
      PeopleFlat.fromJson({'id': 'f2', 'flat_number': '102'}),
    ];
    final members = {
      'f2': [PeopleMember.fromJson({'id': 'm', 'flat_id': 'f2', 'name': 'Zoya', 'email': 'zoya@x.com', 'relation': 'daughter'})],
    };
    List<String> s(String q) => filterAdminFlats(flats: flats, membersByFlat: members, query: q).map((f) => f.id).toList();
    expect(s('a-1'), ['f1']);
    expect(s('ravi'), ['f1']);
    expect(s('981'), ['f1']);
    expect(s('zoya@'), ['f2']);
    expect(s('daughter'), ['f2']);
    expect(adminNameHits(members['f2']!, 'zoya@'), isEmpty);
    expect(adminNameHits(members['f2']!, 'zoy').length, 1);
  });

  test('misc formatting', () {
    expect(mapGenderForAdminForm('male'), 'Male');
    expect(mapGenderForAdminForm('FEMALE'), 'Female');
    expect(mapGenderForAdminForm('x'), '');
    expect(capitalizeWords('mid-servant'), 'Mid-Servant');
    expect(capitalizeWords('owner'), 'Owner');
    final m = PeopleMember.fromJson({
      'id': 'm', 'flat_id': 'f', 'name': 'N', 'relation': 'son', 'age': 12, 'gender': 'male', 'phone': '9', 'whatsapp_phone': '8', 'email': 'e@x.com',
    });
    expect(memberDetailLine(m), 'Son · 12y · Male · 📱9 · WA 8 · e@x.com');
    final f = memberFormFrom(m);
    expect(f.gender, 'Male');
    expect(f.age, '12');
    expect(docTypesFor(MemberDocKind.tenantDoc).first.value, 'rental_agreement');
    expect(defaultDocType(MemberDocKind.serviceDoc), 'id_proof');
    expect(householdGroupForRelation(' Tenant '), 'tenant');
  });
}
