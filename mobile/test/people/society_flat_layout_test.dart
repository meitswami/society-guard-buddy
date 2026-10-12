import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/utils/society_flat_layout.dart';

void main() {
  group('floorLabelFromFlatNumber (web flatFloor.ts)', () {
    test('3-digit flats map to floors 1–6', () {
      expect(floorLabelFromFlatNumber('101'), '1st Floor');
      expect(floorLabelFromFlatNumber('199'), '1st Floor');
      expect(floorLabelFromFlatNumber('205'), '2nd Floor');
      expect(floorLabelFromFlatNumber('303'), '3rd Floor');
      expect(floorLabelFromFlatNumber('607'), '6th Floor');
      expect(floorLabelFromFlatNumber(' A-401 '), '4th Floor');
    });

    test('other patterns return null', () {
      expect(floorLabelFromFlatNumber(''), isNull);
      expect(floorLabelFromFlatNumber('701'), isNull);
      expect(floorLabelFromFlatNumber('1001'), isNull);
      expect(floorLabelFromFlatNumber('G1'), isNull);
      expect(floorLabelFromFlatNumber('099'), isNull);
    });
  });

  test('jsParseInt mirrors parseInt(s, 10)', () {
    expect(jsParseInt('101'), 101);
    expect(jsParseInt(' 101A '), 101);
    expect(jsParseInt('A101'), isNull);
    expect(jsParseInt(''), isNull);
    expect(jsParseInt('-5'), -5);
  });

  group('buildValidFlatNumberSet (web societyFlatRangeTrim.ts)', () {
    test('builds +100 per floor tiers', () {
      final r = buildValidFlatNumberSet(
          totalFloors: 3, flatSeriesStart: '101', flatSeriesEnd: '105')!;
      expect(r.valid.length, 15);
      expect(r.valid, containsAll(['101', '105', '201', '305']));
      expect(r.valid, isNot(contains('106')));
      expect(r.floorBase, 1);
      expect(r.uStart, 1);
      expect(r.nUnits, 5);
      expect(r.maxTrimUnit, 9);
      expect(r.sortedNumbers.first, '101');
      expect(r.sortedNumbers.last, '305');
    });

    test('ground floor counted as 1st (201–205)', () {
      final r = buildValidFlatNumberSet(
          totalFloors: 2, flatSeriesStart: '201', flatSeriesEnd: '205')!;
      expect(r.valid, containsAll(['201', '305']));
      expect(r.floorBase, 2);
    });

    test('rejects invalid ranges', () {
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
              totalFloors: 2, flatSeriesStart: '101', flatSeriesEnd: '201'),
          isNull);
      expect(
          buildValidFlatNumberSet(
              totalFloors: 2, flatSeriesStart: 'x', flatSeriesEnd: '105'),
          isNull);
    });

    test('canTrimFlatsFromSocietyRow requires all fields', () {
      expect(
        canTrimFlatsFromSocietyRow(const SocietyFlatRangeInput(
            totalFloors: null, flatSeriesStart: '101', flatSeriesEnd: '105')),
        isNull,
      );
      expect(
        canTrimFlatsFromSocietyRow(const SocietyFlatRangeInput(
            totalFloors: 2, flatSeriesStart: ' ', flatSeriesEnd: '105')),
        isNull,
      );
      expect(
        canTrimFlatsFromSocietyRow(const SocietyFlatRangeInput(
                totalFloors: 2, flatSeriesStart: '101', flatSeriesEnd: '105'))!
            .valid
            .length,
        10,
      );
      expect(
          layoutFromSocietyRow({
            'total_floors': 2,
            'flat_series_start': '101',
            'flat_series_end': '102'
          })!
              .valid
              .length,
          4);
    });
  });

  group('flatRowShouldTrim', () {
    final range = buildValidFlatNumberSet(
        totalFloors: 3, flatSeriesStart: '101', flatSeriesEnd: '105')!;
    bool trim(String n,
            {String? wing,
            String? type = 'residential',
            List<String>? blocks}) =>
        flatRowShouldTrim(
            flatNumber: n,
            wing: wing,
            flatType: type,
            range: range,
            blockNames: blocks);

    test('removes near extras on configured tiers', () {
      expect(trim('106'), isTrue);
      expect(trim('209'), isTrue);
      expect(trim('306'), isTrue);
    });

    test('keeps valid, far units, other tiers and non-numeric', () {
      expect(trim('105'), isFalse);
      expect(trim('150'), isFalse);
      expect(trim('110'), isFalse);
      expect(trim('406'), isFalse);
      expect(trim('006'), isFalse);
      expect(trim('Shop-1'), isFalse);
      expect(trim('106A'), isFalse);
    });

    test('flat_type and wing rules', () {
      expect(trim('106', type: 'commercial'), isFalse);
      expect(trim('106', type: null), isTrue);
      expect(trim('106', type: ''), isFalse);
      expect(trim('106', wing: 'A', blocks: ['A', 'B']), isTrue);
      expect(trim('106', wing: 'c', blocks: ['A', 'B']), isFalse);
      expect(trim('106', wing: null, blocks: ['A', 'B']), isFalse);
      expect(trim('106', wing: null, blocks: ['A']), isTrue);
      expect(trim('106', wing: 'Z', blocks: []), isTrue);
    });
  });

  group('planFlatsFromLayout (web societyFlatsFromLayout.ts)', () {
    const single = SocietyFlatRangeInput(
        totalFloors: 2, flatSeriesStart: '101', flatSeriesEnd: '103');

    test('single tower generates unwinged rows with floor labels', () {
      final plan =
          planFlatsFromLayout(societyId: 's1', row: single, existing: const []);
      expect(plan.error, isNull);
      expect(plan.skipped, 0);
      expect(plan.rows.map((r) => r['flat_number']).toList(),
          ['101', '102', '103', '201', '202', '203']);
      expect(plan.rows.first, {
        'society_id': 's1',
        'flat_number': '101',
        'wing': null,
        'floor': '1st Floor',
        'flat_type': 'residential',
        'is_occupied': false,
      });
    });

    test('is idempotent and counts skipped', () {
      final plan = planFlatsFromLayout(
        societyId: 's1',
        row: single,
        existing: const [
          ExistingFlatKey(' 101 ', null),
          ExistingFlatKey('202', '')
        ],
      );
      expect(plan.skipped, 2);
      expect(plan.rows.length, 4);
    });

    test('multi-wing repeats numbers per wing (upper-cased)', () {
      final plan = planFlatsFromLayout(
        societyId: 's1',
        row: const SocietyFlatRangeInput(
            totalFloors: 1,
            flatSeriesStart: '101',
            flatSeriesEnd: '102',
            blockNames: ['a', ' B ']),
        existing: const [ExistingFlatKey('101', 'A')],
      );
      expect(plan.rows.map((r) => '${r['wing']}-${r['flat_number']}').toList(),
          ['A-102', 'B-101', 'B-102']);
      expect(plan.skipped, 1);
    });

    test('halts on wing mode conflict', () {
      final plan = planFlatsFromLayout(
        societyId: 's1',
        row: const SocietyFlatRangeInput(
            totalFloors: 1,
            flatSeriesStart: '101',
            flatSeriesEnd: '102',
            blockNames: ['A']),
        existing: const [ExistingFlatKey('101', null)],
      );
      expect(plan.error, kWingModeConflictError);
      expect(plan.rows, isEmpty);
    });

    test('invalid layout / missing society', () {
      expect(
        planFlatsFromLayout(
          societyId: 's1',
          row: const SocietyFlatRangeInput(
              totalFloors: 0, flatSeriesStart: '101', flatSeriesEnd: '102'),
          existing: const [],
        ).error,
        kInvalidLayoutError,
      );
      expect(
          planFlatsFromLayout(societyId: '', row: single, existing: const [])
              .error,
          'Missing society id');
    });
  });

  test('parseBlockNamesCsv', () {
    expect(parseBlockNamesCsv('A, B;;C ,'), ['A', 'B', 'C']);
    expect(parseBlockNamesCsv('  '), isEmpty);
    expect(wingKey(' b '), 'B');
    expect(layoutWings(null), [null]);
    expect(layoutWings(['a', ' ']), ['A']);
  });
}
