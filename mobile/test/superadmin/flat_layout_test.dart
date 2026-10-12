import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/superadmin/logic/flat_layout.dart';

/// Ports of `societyFlatRangeTrim.ts`, `societyFlatsFromLayout.ts`, `flatFloor.ts`.
void main() {
  group('buildValidFlatNumberSet', () {
    test('101–105 × 3 floors', () {
      final r = buildValidFlatNumberSet(
          totalFloors: 3, flatSeriesStart: '101', flatSeriesEnd: '105')!;
      expect(r.valid.length, 15);
      expect(r.valid.containsAll(['101', '105', '201', '305']), isTrue);
      expect(r.valid.contains('106'), isFalse);
      expect(r.floorBase, 1);
      expect(r.uStart, 1);
      expect(r.nUnits, 5);
      expect(r.maxTrimUnit, 9);
    });

    test('invalid inputs return null (JS parseInt semantics)', () {
      expect(
          buildValidFlatNumberSet(
              totalFloors: 0, flatSeriesStart: '101', flatSeriesEnd: '105'),
          isNull);
      expect(
          buildValidFlatNumberSet(
              totalFloors: 2, flatSeriesStart: '105', flatSeriesEnd: '101'),
          isNull);
      expect(
          buildValidFlatNumberSet(
              totalFloors: 2, flatSeriesStart: '101', flatSeriesEnd: '205'),
          isNull);
      expect(
          buildValidFlatNumberSet(
              totalFloors: 2, flatSeriesStart: 'A1', flatSeriesEnd: '105'),
          isNull);
      // parseInt('101a') === 101
      expect(
          buildValidFlatNumberSet(
                  totalFloors: 1,
                  flatSeriesStart: '101a',
                  flatSeriesEnd: ' 102 ')!
              .valid,
          {'101', '102'});
    });

    test('ground floor counted as 0-band (001–004)', () {
      final r = buildValidFlatNumberSet(
          totalFloors: 2, flatSeriesStart: '1', flatSeriesEnd: '4')!;
      expect(r.valid, {'1', '2', '3', '4', '101', '102', '103', '104'});
    });
  });

  group('flatRowShouldTrim', () {
    final range = buildValidFlatNumberSet(
        totalFloors: 3, flatSeriesStart: '101', flatSeriesEnd: '105')!;
    bool trim(String n, {String? wing, String? type, List<String>? blocks}) =>
        flatRowShouldTrim(
            flatNumber: n,
            wing: wing,
            flatType: type,
            range: range,
            blockNames: blocks);

    test('extra units in the same band are trimmed', () {
      expect(trim('106'), isTrue);
      expect(trim('309'), isTrue);
      expect(trim('100'), isFalse); // unit 0 < uStart
      expect(trim('310'), isFalse); // beyond maxTrimUnit
      expect(trim('150'), isFalse); // shop-like number
      expect(trim('406'), isFalse); // floor outside range
      expect(trim('105'), isFalse); // valid
      expect(trim('0105'), isFalse); // String(parseInt) is valid
    });

    test('non-residential, non-numeric and other wings are kept', () {
      expect(trim('106', type: 'shop'), isFalse);
      expect(trim('106', type: 'residential'), isTrue);
      expect(trim('G-1'), isFalse);
      expect(trim('106', wing: 'B', blocks: ['A']), isFalse);
      expect(trim('106', wing: 'a', blocks: ['A', 'B']), isTrue);
      expect(trim('106', blocks: ['A']), isTrue); // no wing + single block
      expect(trim('106', blocks: ['A', 'B']), isFalse); // ambiguous
    });

    test('flatIdsToTrim uses canTrimFlatsFromSocietyRow', () {
      const row = SocietyLayoutInput(
          totalFloors: 3,
          flatSeriesStart: '101',
          flatSeriesEnd: '105',
          blockNames: null);
      final ids = flatIdsToTrim(row, const [
        ExistingFlat(id: 'a', flatNumber: '106'),
        ExistingFlat(id: 'b', flatNumber: '101'),
        ExistingFlat(id: 'c', flatNumber: '207', flatType: null),
      ]);
      expect(ids, ['a', 'c']);
      expect(
          flatIdsToTrim(
              const SocietyLayoutInput(
                  totalFloors: null,
                  flatSeriesStart: '101',
                  flatSeriesEnd: '105',
                  blockNames: null),
              const [
                ExistingFlat(id: 'a', flatNumber: '106'),
              ]),
          isEmpty);
    });
  });

  test('floorLabelFromFlatNumber', () {
    expect(floorLabelFromFlatNumber('101'), '1st Floor');
    expect(floorLabelFromFlatNumber('A-204'), '2nd Floor');
    expect(floorLabelFromFlatNumber('699'), '6th Floor');
    expect(floorLabelFromFlatNumber('701'), isNull);
    expect(floorLabelFromFlatNumber('12'), isNull);
    expect(floorLabelFromFlatNumber(''), isNull);
  });

  group('planFlatsFromLayout', () {
    const single = SocietyLayoutInput(
        totalFloors: 2,
        flatSeriesStart: '101',
        flatSeriesEnd: '102',
        blockNames: null);

    test('single tower: creates missing, skips existing, sorted numerically',
        () {
      final plan = planFlatsFromLayout(
          's1', single, const [ExistingFlat(flatNumber: '102 ')]);
      expect(plan.error, isNull);
      expect(plan.skipped, 1);
      expect(plan.rows.map((r) => r['flat_number']), ['101', '201', '202']);
      expect(plan.rows.first, {
        'society_id': 's1',
        'flat_number': '101',
        'wing': null,
        'floor': '1st Floor',
        'flat_type': 'residential',
        'is_occupied': false,
      });
    });

    test('wings are upper-cased and generated per block', () {
      const winged = SocietyLayoutInput(
          totalFloors: 1,
          flatSeriesStart: '101',
          flatSeriesEnd: '102',
          blockNames: ['a', ' B ']);
      final plan = planFlatsFromLayout(
          's1', winged, const [ExistingFlat(flatNumber: '101', wing: 'A')]);
      expect(plan.skipped, 1);
      expect(plan.rows.map((r) => '${r['wing']}-${r['flat_number']}'),
          ['A-102', 'B-101', 'B-102']);
    });

    test('wing-mode conflict and invalid layouts', () {
      const winged = SocietyLayoutInput(
          totalFloors: 1,
          flatSeriesStart: '101',
          flatSeriesEnd: '102',
          blockNames: ['A']);
      expect(
          planFlatsFromLayout(
              's1', winged, const [ExistingFlat(flatNumber: '101')]).error,
          kWingModeConflictError);
      expect(
          planFlatsFromLayout('s1', single,
              const [ExistingFlat(flatNumber: '101', wing: 'A')]).error,
          kWingModeConflictError);
      const bad = SocietyLayoutInput(
          totalFloors: 0,
          flatSeriesStart: '101',
          flatSeriesEnd: '102',
          blockNames: null);
      expect(planFlatsFromLayout('s1', bad, const []).error,
          kInvalidFlatLayoutError);
      expect(planFlatsFromLayout('', single, const []).error,
          'Missing society id');
    });
  });

  test('chunked', () {
    expect(chunked([1, 2, 3, 4, 5], 2), [
      [1, 2],
      [3, 4],
      [5],
    ]);
    expect(chunked(<int>[], 3), isEmpty);
  });
}
