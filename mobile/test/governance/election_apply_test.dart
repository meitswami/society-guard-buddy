import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/governance/logic/election_apply.dart';

void main() {
  const options = [
    ApplyOption(id: 'P1', optionText: 'Asha Rao', memberId: 'm1', flatId: 'f1', flatNumber: 'A-1'),
    ApplyOption(id: 'C1', optionText: 'Esha', memberId: 'm5', flatId: 'f5', flatNumber: 'B-2'),
  ];
  final results = <String, dynamic>{
    'president': {'option_id': 'P1', 'name': 'Asha Rao', 'score': 3},
    'vice_president': null,
    'secretary': null,
    'treasurer': {'option_id': 'T9', 'name': 'Unknown option', 'score': 1},
    'committee': [
      {'option_id': 'C1', 'name': 'Esha', 'score': 2},
    ],
    'formation': {
      'selected_runner_up_ids': [],
      'voluntary': [
        {'key': 'vol-m7-C-3', 'name': 'Iqbal', 'flat_number': 'C-3', 'flat_id': 'f7', 'member_id': 'm7', 'source': 'voluntary'},
      ],
      'executive_proposed': [
        {'key': 'exec-1-Jai', 'name': 'Jai', 'flat_number': null, 'source': 'executive_proposed'},
      ],
    },
  };

  test('builds committee rows in office → committee → voluntary → proposed order', () {
    final rows = buildCommitteeInserts(
      societyId: 's1',
      pollId: 'poll1',
      results: results,
      options: options,
      termFrom: '2026-08-14',
      termTo: '2028-08-13',
      photoByMemberId: const {'m1': 'data:image/png;base64,AA', 'm7': ' '},
    );
    expect(rows.map((r) => r['name']), ['Asha Rao', 'Unknown option', 'Esha', 'Iqbal', 'Jai']);
    expect(rows.map((r) => r['position']), ['President', 'Treasurer', 'Committee Member', 'Committee Member', 'Committee Member']);
    expect(rows.map((r) => r['selection_type']), ['elected', 'elected', 'elected', 'voluntary', 'executive_proposed']);
    expect(rows.map((r) => r['sort_order']), [0, 1, 2, 3, 4]);

    final president = rows.first;
    expect(president['flat_id'], 'f1');
    expect(president['flat_number'], 'A-1');
    expect(president['flat_owner_name'], 'Asha Rao');
    expect(president['photo'], 'data:image/png;base64,AA');
    expect(president['source_poll_id'], 'poll1');
    expect(president['source_option_id'], 'P1');
    expect(president['term_from'], '2026-08-14');
    expect(president['term_to'], '2028-08-13');
    expect(president['is_active'], isTrue);

    final unknown = rows[1];
    expect(unknown['flat_id'], isNull);
    expect(unknown['flat_owner_name'], 'Unknown option');

    final vol = rows[3];
    expect(vol['flat_id'], 'f7');
    expect(vol['flat_number'], 'C-3');
    expect(vol['flat_owner_name'], 'Iqbal');
    expect(vol['photo'], ' ', reason: 'web keeps truthy (untrimmed) photo strings');
    expect(vol['source_option_id'], isNull);

    final exec = rows[4];
    expect(exec['flat_id'], isNull);
    expect(exec['photo'], isNull);
  });

  test('member ids gathered for photos', () {
    expect(applyMemberIds(options, results), ['m1', 'm5', 'm7']);
  });

  test('no winners → empty insert list', () {
    expect(
      buildCommitteeInserts(societyId: 's', pollId: 'p', results: const {}, options: const [], termFrom: '2026-01-01', termTo: null),
      isEmpty,
    );
  });

  test('prior roster retires the day before the new term', () {
    expect(priorTermTo('2026-08-14'), '2026-08-13');
    expect(priorTermTo('2026-03-01'), '2026-02-28');
    expect(priorTermTo('2028-03-01'), '2028-02-29');
    expect(priorTermTo('2027-01-01'), '2026-12-31');
  });

  test('retirement filter keeps rows overlapping the new term', () {
    final prior = [
      {'id': 'a', 'term_from': '2024-08-14', 'term_to': null},
      {'id': 'b', 'term_from': '2026-08-14', 'term_to': null},
      {'id': 'c', 'term_from': '2024-08-14', 'term_to': '2026-08-13'},
      {'id': 'd', 'term_from': null, 'term_to': null},
      {'id': 'e', 'term_from': '2024-08-14T00:00:00Z', 'term_to': '2026-12-31'},
    ];
    expect(retireIdsFor(prior, '2026-08-14'), ['a', 'd', 'e']);
  });
}
