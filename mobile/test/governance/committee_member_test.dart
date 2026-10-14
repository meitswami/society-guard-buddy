import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/governance/logic/committee_logic.dart';

CommitteeMemberRow row({
  required String name,
  required String position,
  String? termFrom,
  String? termTo,
  int sortOrder = 0,
  bool isActive = true,
  String? flatId,
  String? flatNumber,
  String? flatOwnerName,
  String? phone,
}) =>
    CommitteeMemberRow(
      id: name,
      societyId: 's',
      name: name,
      position: position,
      termFrom: termFrom,
      termTo: termTo,
      sortOrder: sortOrder,
      isActive: isActive,
      flatId: flatId,
      flatNumber: flatNumber,
      flatOwnerName: flatOwnerName,
      phone: phone,
      selectionType: 'elected',
    );

void main() {
  // Port of src/lib/committeeMember.test.ts
  group('splitCommitteeTerms', () {
    final previous = [
      row(
          name: 'Abhishek sharma',
          position: 'President',
          termFrom: '2026-03-01',
          termTo: '2026-08-13',
          sortOrder: 1),
      row(
          name: 'Harish Swami',
          position: 'Committee Member',
          termTo: '2026-08-13',
          sortOrder: 6),
    ];
    final current = [
      row(
          name: 'Suresh Pareek',
          position: 'President',
          termFrom: '2026-08-14',
          termTo: '2028-08-13',
          sortOrder: 0),
      row(
          name: 'Jaya Sharma',
          position: 'Vice-President',
          termFrom: '2026-08-14',
          termTo: '2028-08-13',
          sortOrder: 1),
    ];

    test('shows the latest term as current even before term_from calendar date',
        () {
      final split = splitCommitteeTerms([...previous, ...current]);
      expect(split.currentTermFrom, '2026-08-14');
      expect(
          split.current.map((r) => r.name), ['Suresh Pareek', 'Jaya Sharma']);
      expect(split.previous.map((r) => r.name),
          ['Abhishek sharma', 'Harish Swami']);
    });

    test('currentCommitteeMembers ignores the previous term', () {
      expect(
          currentCommitteeMembers([...previous, ...current]).map((r) => r.name),
          ['Suresh Pareek', 'Jaya Sharma']);
    });

    test('inactive rows are ignored and an empty roster has no current term',
        () {
      final split = splitCommitteeTerms(
          [row(name: 'X', position: 'President', isActive: false)]);
      expect(split.current, isEmpty);
      expect(split.previous, isEmpty);
      expect(split.currentTermFrom, isNull);
    });

    test(
        'rows without term_from stay current unless their term ended before the current term',
        () {
      final split = splitCommitteeTerms([
        row(name: 'A', position: 'Committee Member', termFrom: '2026-08-14'),
        row(name: 'B', position: 'Committee Member'),
        row(name: 'C', position: 'Committee Member', termTo: '2026-01-01'),
      ]);
      expect(split.current.map((r) => r.name), ['A', 'B']);
      expect(split.previous.map((r) => r.name), ['C']);
    });
  });

  group('dedupeCommitteeByPosition', () {
    test('keeps one office-bearer per unique post, preferring a closed tenure',
        () {
      final rows = [
        row(
            name: 'Jaya',
            position: 'Vice-President',
            termFrom: '2026-08-14',
            sortOrder: 1),
        row(
            name: 'Jaya Sharma',
            position: 'Vice-President',
            termFrom: '2026-08-14',
            termTo: '2028-08-13',
            sortOrder: 10),
        row(
            name: 'Sunil Sharma',
            position: 'Committee Member',
            termFrom: '2026-08-14',
            sortOrder: 5),
        row(
            name: 'Abhishek Sharma',
            position: 'Committee Member',
            termFrom: '2026-08-14',
            sortOrder: 6),
      ];
      final names = dedupeCommitteeByPosition(rows).map((r) => r.name).toList();
      // The web expectation (`['Jaya Sharma', 'Sunil Sharma', 'Abhishek Sharma']`) is stale and
      // fails against the web implementation too; the implementation (our spec) keeps the
      // closed-tenure "Jaya Sharma" row and then orders the roster by sort_order.
      expect(names, ['Sunil Sharma', 'Abhishek Sharma', 'Jaya Sharma']);
      expect(names.where((n) => n.startsWith('Jaya')), ['Jaya Sharma']);
    });

    test('non-unique posts keep different people, merge the same person', () {
      final rows = [
        row(name: 'Ravi  Kumar', position: 'Committee Member', sortOrder: 2),
        row(name: 'ravi kumar', position: 'committee member', sortOrder: 1),
        row(name: 'Meena', position: 'Committee Member', sortOrder: 3),
      ];
      expect(dedupeCommitteeByPosition(rows).length, 2);
    });

    test('equal sort order falls back to name order', () {
      final rows = [
        row(name: 'b', position: 'Committee Member'),
        row(name: 'A', position: 'Committee Member'),
      ];
      expect(dedupeCommitteeByPosition(rows).map((r) => r.name), ['A', 'b']);
    });
  });

  group('labels', () {
    test('representative detection is case-insensitive and needs both names',
        () {
      expect(committeeIsRepresentative(name: 'Ram', flatOwnerName: 'ram'),
          isFalse);
      expect(committeeIsRepresentative(name: 'Ram', flatOwnerName: 'Shyam'),
          isTrue);
      expect(
          committeeIsRepresentative(name: 'Ram', flatOwnerName: null), isFalse);
      expect(committeeIsRepresentative(name: ' ', flatOwnerName: 'Shyam'),
          isFalse);
    });

    test('display labels for owner and representative', () {
      final owner = row(
          name: 'Ram',
          position: 'President',
          flatNumber: 'A-1',
          flatOwnerName: 'Ram');
      final l1 = committeeDisplayLabels(owner);
      expect(l1.primaryName, 'Ram');
      expect(l1.subtitle, 'Flat A-1');
      expect(l1.isRepresentative, isFalse);

      final rep = row(
          name: 'Sita',
          position: 'President',
          flatNumber: 'A-1',
          flatOwnerName: 'Ram');
      final l2 = committeeDisplayLabels(rep);
      expect(l2.primaryName, 'Sita');
      expect(l2.subtitle, 'Flat A-1 · Owner: Ram');
      expect(l2.isRepresentative, isTrue);

      final noFlat = row(name: 'Sita', position: 'President');
      expect(committeeDisplayLabels(noFlat).subtitle, isNull);
    });

    test('tenure label', () {
      expect(committeeTenureLabel(termFrom: null), isNull);
      expect(
          committeeTenureLabel(
              termFrom: '2026-08-14T00:00:00Z', termTo: '2028-08-13'),
          '2026-08-14 → 2028-08-13');
      expect(committeeTenureLabel(termFrom: '2026-08-14'),
          '2026-08-14 → Until retirement');
    });

    test('selection type labels', () {
      expect(selectionTypeLabel('runner_up'), 'Runner-up (2nd/3rd)');
      expect(selectionTypeLabel('executive_proposed'), 'Executive proposed');
      expect(selectionTypeLabel(null), '—');
      expect(selectionTypeLabel('elected', hi: true), 'निर्वाचित');
      expect(CommitteeSelectionType.values.map((t) => t.value), [
        'elected',
        'nominated',
        'runner_up',
        'voluntary',
        'executive_proposed'
      ]);
    });
  });

  group('effective dates', () {
    test('isCommitteeMemberEffectiveOn', () {
      final r = row(
          name: 'A',
          position: 'President',
          termFrom: '2026-01-01',
          termTo: '2026-12-31');
      expect(isCommitteeMemberEffectiveOn(r, '2026-06-01'), isTrue);
      expect(isCommitteeMemberEffectiveOn(r, '2025-12-31'), isFalse);
      expect(isCommitteeMemberEffectiveOn(r, '2027-01-01'), isFalse);
      expect(
          isCommitteeMemberEffectiveOn(
              row(name: 'B', position: 'X', isActive: false), '2026-06-01'),
          isFalse);
      expect(filterEffectiveCommitteeMembers([r], '2026-06-01'), hasLength(1));
    });

    test('localIsoDate pads month and day', () {
      expect(localIsoDate(DateTime(2026, 3, 7)), '2026-03-07');
    });
  });

  group('form', () {
    test('validation order matches the web', () {
      String? v({
        String position = 'President',
        String flatId = 'f',
        String flatNumber = 'A-1',
        String name = 'Ram',
        String termFrom = '2026-01-01',
        String termTo = '',
        String selectionType = 'elected',
      }) =>
          validateCommitteeForm(
            position: position,
            flatId: flatId,
            flatNumber: flatNumber,
            name: name,
            termFrom: termFrom,
            termTo: termTo,
            selectionType: selectionType,
          )?.$1;
      expect(v(position: ' '), 'Position is required');
      expect(v(flatId: ''), 'Select a flat number');
      expect(v(name: ''), 'Name for this post is required');
      expect(v(termFrom: ''), 'Tenure start date (From) is required');
      expect(v(selectionType: ''), 'Select how the member was chosen');
      expect(v(termTo: '2025-12-31'),
          'Tenure end date must be on or after start date');
      expect(v(), isNull);
    });

    Map<String, dynamic> payload(
            {String name = 'Ram',
            String owner = 'Ram',
            String gender = '',
            bool rep = false}) =>
        committeeMemberPayload(
          societyId: 's',
          flatId: 'f',
          flatNumber: ' A-1 ',
          flatOwnerName: owner,
          name: name,
          position: 'President',
          phone: ' ',
          gender: gender,
          photo: '',
          showRepresentative: rep,
          repName: ' Rep ',
          repPhone: '999',
          repPhoto: 'data:x',
          sortOrder: 2,
          termFrom: '2026-01-01',
          termTo: '',
          selectionType: 'elected',
        );

    test('owner holding the post', () {
      final p = payload();
      expect(p['show_representative'], isFalse);
      expect(p['rep_name'], isNull);
      expect(p['flat_number'], 'A-1');
      expect(p['phone'], isNull);
      expect(p['term_to'], isNull);
      expect(p['is_active'], isTrue);
    });

    test('representative name differs from owner', () {
      final p = payload(name: 'Sita');
      expect(p['show_representative'], isTrue);
      expect(p['rep_name'], 'Sita');
      expect(p['rep_phone'], isNull);
    });

    test('female representative contact', () {
      final p = payload(gender: 'female', rep: true);
      expect(p['show_representative'], isTrue);
      expect(p['rep_name'], 'Rep');
      expect(p['rep_phone'], '999');
      expect(p['rep_photo'], 'data:x');
      final notFemale = payload(gender: 'male', rep: true);
      expect(notFemale['show_representative'], isFalse);
      expect(notFemale['rep_phone'], isNull);
    });
  });

  group('committee protection (committeeProtection.ts)', () {
    final roster = [
      row(
          name: 'Ram Lal',
          position: 'President',
          flatId: 'f1',
          flatOwnerName: 'Shyam Lal',
          phone: '+91 98765-43210'),
    ];

    test('matches by flat + holder name, flat + owner name, or phone', () {
      expect(
          isMemberOnCommitteeRoster(
              name: ' ram lal ', flatId: 'f1', committeeRows: roster),
          isTrue);
      expect(
          isMemberOnCommitteeRoster(
              name: 'Shyam Lal', flatId: 'f1', committeeRows: roster),
          isTrue);
      expect(
          isMemberOnCommitteeRoster(
              name: 'Other',
              phone: '9876543210',
              flatId: 'f9',
              committeeRows: roster),
          isFalse);
      expect(
          isMemberOnCommitteeRoster(
              name: 'Other',
              phone: '+91 98765 43210',
              flatId: 'f9',
              committeeRows: roster),
          isTrue);
      expect(
          isMemberOnCommitteeRoster(
              name: 'Ram Lal', flatId: 'f2', committeeRows: roster),
          isFalse);
    });
  });
}
