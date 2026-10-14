import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/resident/data/member_rules.dart';

void main() {
  group('memberCategories (web memberCategories.ts)', () {
    test('household relations may log in; staff may not', () {
      for (final r in [
        'owner',
        'Spouse',
        ' son ',
        'DAUGHTER',
        'father',
        'mother',
        'family',
        'brother',
        'sister',
        'tenant'
      ]) {
        expect(allowsResidentLogin(r), isTrue, reason: r);
      }
      for (final r in ['cook', 'maid', 'driver', 'others', 'other', 'plumber', '', null]) {
        expect(allowsResidentLogin(r), isFalse, reason: '$r');
        expect(isRestrictedMemberCategory(r), isTrue, reason: '$r');
      }
    });

    test('tenant can log in but cannot be primary', () {
      expect(allowsResidentLogin('tenant'), isTrue);
      expect(allowsPrimaryMember('tenant'), isFalse);
      expect(allowsPrimaryMember('Owner'), isTrue);
      expect(allowsPrimaryMember('cook'), isFalse);
      expect(isRestrictedMemberCategory('tenant'), isFalse);
    });

    test('service relations (web SERVICE_TYPES lower-case match)', () {
      expect(isServiceRelation('Cook'), isTrue);
      expect(isServiceRelation('mid-servant'), isTrue);
      expect(isServiceRelation('others'), isTrue);
      expect(isServiceRelation('spouse'), isFalse);
      expect(isKnownHouseholdServiceType(' Driver '), isTrue);
      expect(isKnownHouseholdServiceType('plumber'), isFalse);
    });

    test('owner / tenant household group', () {
      expect(memberHouseholdGroup(householdGroup: 'tenant', relation: 'son'), 'tenant');
      expect(memberHouseholdGroup(householdGroup: 'Owner', relation: 'tenant'), 'owner');
      expect(memberHouseholdGroup(householdGroup: 'family', relation: 'Tenant'), 'tenant');
      expect(memberHouseholdGroup(householdGroup: null, relation: 'cook'), 'owner');
    });
  });

  group('planMemberSave (web handleAddMember)', () {
    const flat = 'flat-1';

    test('requires a name and a relation / service type', () {
      expect(planMemberSave(form: const MemberFormData(relation: 'Son'), docs: const [], flatId: flat).error,
          MemberSaveError.nameRequired);
      expect(planMemberSave(form: const MemberFormData(name: 'Asha'), docs: const [], flatId: flat).error,
          MemberSaveError.relationRequired);
      expect(
          planMemberSave(form: const MemberFormData(name: 'Ramu', isServiceman: true), docs: const [], flatId: flat)
              .error,
          MemberSaveError.serviceTypeRequired);
    });

    test('committee members cannot be edited by the resident', () {
      final plan = planMemberSave(
        form: const MemberFormData(name: 'A', relation: 'Owner'),
        docs: const [],
        flatId: flat,
        editing: const {'id': 'm1', 'is_primary': false},
        editingOnCommittee: true,
      );
      expect(plan.error, MemberSaveError.onCommittee);
    });

    test('primary must stay an owner-household relation', () {
      const primary = {'id': 'm1', 'is_primary': true};
      expect(
        planMemberSave(
                form: const MemberFormData(name: 'A', relation: 'Tenant'),
                docs: const [],
                flatId: flat,
                editing: primary)
            .error,
        MemberSaveError.primaryMustStayOwner,
      );
      expect(
        planMemberSave(
                form: const MemberFormData(name: 'A', isServiceman: true, serviceType: 'Cook'),
                docs: const [],
                flatId: flat,
                editing: primary)
            .error,
        MemberSaveError.primaryMustStayOwner,
      );
      final ok = planMemberSave(
          form: const MemberFormData(name: 'A', relation: 'Owner'), docs: const [], flatId: flat, editing: primary);
      expect(ok.ok, isTrue);
      expect(ok.payload['is_primary'], isTrue);
    });

    test('tenant needs a photo ID and a rental agreement', () {
      const form = MemberFormData(name: 'T', relation: 'Tenant');
      expect(planMemberSave(form: form, docs: const [], flatId: flat).error, MemberSaveError.tenantPhotoIdRequired);
      final withId = [const MemberDocDraft(kind: 'photo_id', type: 'aadhaar', front: 'data:x')];
      expect(planMemberSave(form: form, docs: withId, flatId: flat).error, MemberSaveError.tenantRentalRequired);
      final full = [...withId, const MemberDocDraft(kind: 'tenant_doc', type: 'rental_agreement', front: 'data:y')];
      final plan = planMemberSave(form: form, docs: full, flatId: flat);
      expect(plan.ok, isTrue);
      expect(plan.isTenant, isTrue);
      expect(plan.restricted, isFalse);
      expect(plan.payload['household_group'], 'tenant');
      expect(plan.payload['id_photo_front'], 'data:x');
    });

    test('restricted categories need a photo ID (profile photo counts)', () {
      const cook = MemberFormData(name: 'Ramu', isServiceman: true, serviceType: 'Cook');
      expect(planMemberSave(form: cook, docs: const [], flatId: flat).error, MemberSaveError.restrictedPhotoIdRequired);
      final plan = planMemberSave(
          form: cook.copyWith(photo: 'data:face', policeVerification: 'pending'), docs: const [], flatId: flat);
      expect(plan.ok, isTrue);
      expect(plan.restricted, isTrue);
      expect(plan.payload['relation'], 'cook');
      expect(plan.payload['id_photo_front'], 'data:face');
      expect(plan.payload['police_verification'], 'pending');
    });

    test('legacy id_photo_front on the edited row satisfies the photo ID rule', () {
      final plan = planMemberSave(
        form: const MemberFormData(name: 'Ramu', isServiceman: true, serviceType: 'Maid'),
        docs: const [],
        flatId: flat,
        editing: const {'id': 'm2', 'is_primary': false, 'id_photo_front': 'data:old'},
      );
      expect(plan.ok, isTrue);
    });

    test('relation normalisation: Others → others, custom staff label', () {
      final others = planMemberSave(
        form: const MemberFormData(name: 'O', relation: 'Others', photo: 'data:p'),
        docs: const [],
        flatId: flat,
      );
      expect(others.payload['relation'], 'others');
      final custom = planMemberSave(
        form: const MemberFormData(
            name: 'P', isServiceman: true, serviceType: 'Others', customServiceType: 'Plumber', photo: 'data:p'),
        docs: const [],
        flatId: flat,
      );
      expect(custom.payload['relation'], 'plumber');
      final blankCustom = planMemberSave(
        form: const MemberFormData(name: 'P', isServiceman: true, serviceType: 'Others', photo: 'data:p'),
        docs: const [],
        flatId: flat,
      );
      expect(blankCustom.payload['relation'], 'others');
    });

    test('family members clear the restricted columns and parse age', () {
      final plan = planMemberSave(
        form: const MemberFormData(
            name: ' Asha ', relation: 'Daughter', age: '12', gender: 'female', phone: '9876543210', spouseName: 'x'),
        docs: const [],
        flatId: flat,
        myHouseholdGroup: 'owner',
      );
      expect(plan.ok, isTrue);
      expect(plan.payload['name'], 'Asha');
      expect(plan.payload['age'], 12);
      expect(plan.payload['gender'], 'female');
      expect(plan.payload['phone'], '9876543210');
      expect(plan.payload['household_group'], 'owner');
      expect(plan.payload['spouse_name'], isNull);
      expect(plan.payload['id_photo_front'], isNull);
      expect(plan.payload['is_primary'], isFalse);
    });

    test('a tenant household adds members to the tenant group', () {
      final plan = planMemberSave(
        form: const MemberFormData(name: 'Kid', relation: 'Son'),
        docs: const [],
        flatId: flat,
        myHouseholdGroup: 'tenant',
      );
      expect(plan.payload['household_group'], 'tenant');
    });
  });

  group('login cleanup + staff vehicles', () {
    test('logins removed when phone changes or member becomes restricted', () {
      expect(loginPhonesToRemove(previousPhone: '111', newPhone: '111', restricted: false), isEmpty);
      expect(loginPhonesToRemove(previousPhone: '111', newPhone: '222', restricted: false), ['111']);
      expect(loginPhonesToRemove(previousPhone: '111', newPhone: '', restricted: false), ['111']);
      expect(loginPhonesToRemove(previousPhone: '111', newPhone: '111', restricted: true), ['111']);
      expect(loginPhonesToRemove(previousPhone: null, newPhone: '333', restricted: true), ['333']);
      expect(loginPhonesToRemove(previousPhone: null, newPhone: '333', restricted: false), isEmpty);
    });

    test('staff vehicle row (web syncResidentStaffVehicle)', () {
      expect(
        staffVehicleRow(
            form: const MemberFormData(name: 'R'), societyId: 's', flatId: 'f', flatNumber: '101', memberId: 'm'),
        isNull,
      );
      final row = staffVehicleRow(
        form: const MemberFormData(name: 'Ramu', vehicleName: 'Activa'),
        societyId: 's',
        flatId: 'f',
        flatNumber: '101',
        memberId: 'm',
      )!;
      expect(row['vehicle_number'], 'N/A');
      expect(row['vehicle_type'], 'other');
      expect(row['vehicle_display_name'], 'Activa');
      expect(row['vehicle_color'], isNull);
      expect(row['member_id'], 'm');
      expect(row['resident_name'], 'Ramu');
    });
  });

  group('edit seed (web startEditMember)', () {
    test('service member', () {
      final f = memberFormFromRow(const {'name': 'Ramu', 'relation': 'cook', 'gender': 'Male', 'age': 40});
      expect(f.isServiceman, isTrue);
      expect(f.serviceType, 'Cook');
      expect(f.gender, 'male');
      expect(f.age, '40');
    });

    test('family member and unknown relations', () {
      expect(memberFormFromRow(const {'name': 'A', 'relation': 'tenant'}).relation, 'Tenant');
      final fam = memberFormFromRow(const {'name': 'B', 'relation': 'family'});
      expect(fam.isServiceman, isFalse);
      expect(fam.relation, 'Family');
      expect(relationOptionsFor(editingPrimary: false, currentRelation: fam.relation), contains('Family'));
      final plumber = memberFormFromRow(const {'name': 'C', 'relation': 'plumber'});
      expect(plumber.isServiceman, isTrue);
      expect(plumber.serviceType, 'Others');
      expect(plumber.customServiceType, 'plumber');
      expect(memberFormFromRow(const {'name': 'D', 'relation': 'others'}).serviceType, 'Others');
      expect(memberFormFromRow(const {'name': 'E', 'gender': 'unknown'}).gender, '');
    });

    test('primary members only see owner-household relations', () {
      final opts = relationOptionsFor(editingPrimary: true);
      expect(opts, isNot(contains('Tenant')));
      expect(opts, isNot(contains('Others')));
      expect(opts, contains('Owner'));
    });
  });

  test('member documents: only typed docs with an image are saved', () {
    final rows = memberDocumentRows('m', const [
      MemberDocDraft(kind: 'photo_id', type: 'aadhaar', front: 'f'),
      MemberDocDraft(kind: 'photo_id', type: 'pan'),
      MemberDocDraft(kind: 'tenant_doc', type: 'rental_agreement', back: 'b'),
    ]);
    expect(rows.length, 2);
    expect(rows.first,
        {'member_id': 'm', 'doc_kind': 'photo_id', 'doc_type': 'aadhaar', 'front_url': 'f', 'back_url': null});
    expect(MemberDocDraft.fromRow(const {'doc_kind': null, 'doc_type': null}).kind, 'photo_id');
    expect(MemberDocDraft.fromRow(const {'doc_kind': 'photo_id'}, defaultType: 'aadhaar').type, 'aadhaar');
  });

  test('member subtitle', () {
    expect(memberSubtitle(relation: 'cook', age: 34, gender: 'female', phone: '98'), '🧹 cook · 34y · female · 📱98');
    expect(memberSubtitle(relation: 'son', age: null), 'son');
    expect(memberSubtitle(relation: 'son', age: 0), 'son');
  });
}
