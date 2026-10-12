import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/admin/events/logic/split_math.dart';

/// Port of `src/lib/flatHeadcountSplit.ts` behaviour (expected values produced by the web code).
void main() {
  const members = [
    FlatMemberRow(flatId: 'f1', name: 'A', age: 40, relation: 'self'),
    FlatMemberRow(flatId: 'f1', name: 'B', age: 38, relation: 'wife'),
    FlatMemberRow(flatId: 'f1', name: 'C', age: 10, relation: 'son'),
    FlatMemberRow(flatId: 'f2', name: 'D', relation: 'Daughter'),
    FlatMemberRow(flatId: 'f2', name: 'E', relation: 'Grandson'),
    FlatMemberRow(flatId: 'f2', name: 'F', age: 0, relation: 'father'),
    FlatMemberRow(flatId: 'f3', name: 'G', age: 17, relation: 'self'),
    FlatMemberRow(flatId: 'f4', name: 'H', age: 25, relation: 'son'),
  ];

  group('isChildMember', () {
    test('age wins over relation when positive', () {
      expect(isChildMember(const FlatMemberRow(age: 25, relation: 'son')), isFalse);
      expect(isChildMember(const FlatMemberRow(age: 17, relation: 'self')), isTrue);
    });
    test('relation hints when age is missing or zero', () {
      expect(isChildMember(const FlatMemberRow(relation: 'Daughter')), isTrue);
      expect(isChildMember(const FlatMemberRow(relation: ' grand-daughter ')), isTrue);
      expect(isChildMember(const FlatMemberRow(relation: 'wife')), isFalse);
      expect(isChildMember(const FlatMemberRow(relation: 'granddaughter')), isTrue);
      expect(isChildMember(const FlatMemberRow(age: 0, relation: 'father')), isFalse);
      expect(isChildMember(const FlatMemberRow()), isFalse);
    });
  });

  group('headcountForFlat', () {
    test('counts adults and kids per flat (weights 1 / 0.5)', () {
      final rows = [
        for (final p in const [
          ['101', 'f1'],
          ['102', 'f2'],
          ['103', 'f3'],
          ['104', 'f4'],
          ['105', null],
          ['106', 'fx'],
        ])
          headcountForFlat(p[0]!, p[1], members, 1, 0.5),
      ];
      expect([for (final r in rows) [r.flatNumber, r.adults, r.kids, r.units]], [
        ['101', 2, 1, 2.5],
        ['102', 1, 2, 2.0],
        ['103', 0, 1, 0.5],
        ['104', 1, 0, 1.0],
        ['105', 1, 0, 1.0],
        ['106', 1, 0, 1.0],
      ]);
    });

    test('MemberIndex gives the same result as the list scan', () {
      final index = MemberIndex(members);
      for (final id in ['f1', 'f2', 'f3', 'f4', 'fx']) {
        final a = headcountForFlat('X', id, members, 1.5, 0.3);
        final b = index.headcount('X', id, 1.5, 0.3);
        expect([b.adults, b.kids, b.units], [a.adults, a.kids, a.units]);
      }
    });
  });

  group('computeHeadcountAmounts', () {
    test('distributes by weighted units with the remainder on the last flat', () {
      final rows = [
        for (final p in const [
          ['101', 'f1'],
          ['102', 'f2'],
          ['103', 'f3'],
          ['104', 'f4'],
          ['105', null],
          ['106', 'fx'],
        ])
          headcountForFlat(p[0]!, p[1], members, 1, 0.5),
      ];
      final amounts = computeHeadcountAmounts(10000, rows);
      expect([for (final a in amounts) a.amount], [3125, 2500, 625, 1250, 1250, 1250]);
      expect([for (final a in amounts) '${a.adults}/${a.kids}'], ['2/1', '1/2', '0/1', '1/0', '1/0', '1/0']);
    });

    test('custom weights and an odd total', () {
      final rows = [
        headcountForFlat('101', 'f1', members, 1.5, 0.3),
        headcountForFlat('102', 'f2', members, 1.5, 0.3),
      ];
      expect(rows.map((r) => r.units).toList(), [3.3, 2.1]);
      final amounts = computeHeadcountAmounts(777.77, rows);
      expect(amounts.map((a) => a.amount).toList(), [475.3, 302.47]);
    });

    test('no units → no amounts', () {
      expect(
        computeHeadcountAmounts(100, const [FlatHeadcount(flatNumber: '1', adults: 0, kids: 1, units: 0)]),
        isEmpty,
      );
    });
  });
}
