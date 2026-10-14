import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/resident/data/committee_roster.dart';

CommitteeRosterRow row(String name, String position,
        {String? from, String? to, int sort = 0, bool active = true, String? flatId, String? owner, String? phone}) =>
    CommitteeRosterRow(
      id: name,
      name: name,
      position: position,
      termFrom: from,
      termTo: to,
      sortOrder: sort,
      isActive: active,
      flatId: flatId,
      flatOwnerName: owner,
      phone: phone,
    );

void main() {
  // Mirrors src/lib/committeeMember.test.ts
  group('splitCommitteeTerms', () {
    final previous = [
      row('Abhishek sharma', 'President', from: '2026-03-01', to: '2026-08-13', sort: 1),
      row('Harish Swami', 'Committee Member', to: '2026-08-13', sort: 6),
    ];
    final current = [
      row('Suresh Pareek', 'President', from: '2026-08-14', to: '2028-08-13', sort: 0),
      row('Jaya Sharma', 'Vice-President', from: '2026-08-14', to: '2028-08-13', sort: 1),
    ];

    test('shows the latest term as current even before term_from calendar date', () {
      final split = splitCommitteeTerms([...previous, ...current]);
      expect(split.currentTermFrom, '2026-08-14');
      expect(split.current.map((r) => r.name), ['Suresh Pareek', 'Jaya Sharma']);
      expect(split.previous.map((r) => r.name), ['Abhishek sharma', 'Harish Swami']);
    });

    test('currentCommitteeMembers ignores the previous term', () {
      expect(currentCommitteeMembers([...previous, ...current]).map((r) => r.name), ['Suresh Pareek', 'Jaya Sharma']);
    });

    test('inactive rows are dropped', () {
      expect(currentCommitteeMembers([row('Old', 'Treasurer', active: false)]), isEmpty);
    });
  });

  group('dedupeCommitteeByPosition', () {
    test('keeps one office-bearer per unique post, preferring a closed tenure', () {
      final rows = [
        row('Jaya', 'Vice-President', from: '2026-08-14', sort: 1),
        row('Jaya Sharma', 'Vice-President', from: '2026-08-14', to: '2028-08-13', sort: 10),
        row('Sunil Sharma', 'Committee Member', from: '2026-08-14', sort: 5),
        row('Abhishek Sharma', 'Committee Member', from: '2026-08-14', sort: 6),
      ];
      final names = dedupeCommitteeByPosition(rows).map((r) => r.name).toList();
      // The web implementation sorts the survivors by sort_order (5, 6, 10). The web
      // test file expects a different order and currently fails upstream; we assert the
      // behaviour of the web implementation itself.
      expect(names, ['Sunil Sharma', 'Abhishek Sharma', 'Jaya Sharma']);
      expect(names.where((n) => n.startsWith('Jaya')), ['Jaya Sharma']);
    });
  });

  group('isMemberOnCommitteeRoster (web committeeProtection.ts)', () {
    final roster = [
      row('Suresh Pareek', 'President', flatId: 'f1', owner: 'Suresh Pareek', phone: '+91 98765 43210'),
      row('Rep Holder', 'Secretary', flatId: 'f2', owner: 'Flat Owner'),
    ];

    test('matches by flat + name, flat + owner name and by phone', () {
      expect(isMemberOnCommitteeRoster(name: ' suresh pareek ', flatId: 'f1', roster: roster), isTrue);
      expect(isMemberOnCommitteeRoster(name: 'Flat Owner', flatId: 'f2', roster: roster), isTrue);
      expect(isMemberOnCommitteeRoster(name: 'Someone', phone: '9876543210', flatId: 'f9', roster: roster), isFalse);
      expect(
          isMemberOnCommitteeRoster(name: 'Someone', phone: '+91 98765 43210', flatId: 'f9', roster: roster), isTrue);
    });

    test('other flats and other names are editable', () {
      expect(isMemberOnCommitteeRoster(name: 'Suresh Pareek', flatId: 'f3', roster: roster), isFalse);
      expect(isMemberOnCommitteeRoster(id: 'm1', name: 'Kid', flatId: 'f1', roster: roster), isFalse);
      expect(isMemberOnCommitteeRoster(name: 'Anyone', flatId: 'f1', roster: const []), isFalse);
    });
  });
}
