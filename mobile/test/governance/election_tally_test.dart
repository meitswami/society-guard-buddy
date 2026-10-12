import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/governance/logic/election_tally.dart';

const opts = [
  TallyOption(id: 'P1', optionText: 'Asha', electionPost: 'president'),
  TallyOption(id: 'P2', optionText: 'Bharat', electionPost: 'president'),
  TallyOption(id: 'V1', optionText: 'Chetan', electionPost: 'vice_president'),
  TallyOption(id: 'S1', optionText: 'Divya', electionPost: 'secretary'),
  TallyOption(id: 'C1', optionText: 'Esha', electionPost: 'committee'),
  TallyOption(id: 'C2', optionText: 'Farhan', electionPost: 'committee'),
  TallyOption(id: 'C3', optionText: 'Gita', electionPost: 'committee'),
  TallyOption(id: 'C4', optionText: 'Hari', electionPost: 'committee'),
];

TallyBallot sel(List<String> ids) => TallyBallot(choices: {'selected': ids});

void main() {
  final now = DateTime.utc(2026, 10, 12, 10, 30, 0, 123);

  group('tallyElection — combined (default bye-law ballot)', () {
    final ballots = [
      sel(['P1', 'C1', 'C2']),
      sel(['P2', 'C1', 'C3']),
      sel(['P1', 'C2', 'V1']),
    ];
    final r = tallyElection(opts, ballots, committeeSeats: 3, now: now);

    test('seats the highest marks per nominated post', () {
      expect((r['president'] as Map)['option_id'], 'P1');
      expect((r['president'] as Map)['score'], 2);
      expect((r['president'] as Map)['place'], 1);
      expect((r['president'] as Map)['from_post'], 'president');
      expect((r['vice_president'] as Map)['option_id'], 'V1');
      expect((r['secretary'] as Map)['score'], 0, reason: 'single nominee still seated with 0 marks');
      expect(r['treasurer'], isNull, reason: 'no nominee → null');
    });

    test('committee keeps top seats in stable order', () {
      final c = (r['committee'] as List).cast<Map>();
      expect(c.map((e) => e['option_id']), ['C1', 'C2', 'C3']);
      expect(c.map((e) => e['score']), [2, 2, 1]);
      expect(c.map((e) => e['place']), [1, 2, 3]);
    });

    test('payload metadata', () {
      expect(r['ballot_mode'], 'combined');
      expect(r['tallied_at'], '2026-10-12T10:30:00.123Z');
      expect(r['formation'], {'selected_runner_up_ids': [], 'voluntary': [], 'executive_proposed': []});
      expect(ElectionResults.isPayload(r), isTrue);
    });

    test('committee seats cap and zero seats', () {
      final two = tallyElection(opts, ballots, committeeSeats: 2, now: now);
      expect((two['committee'] as List).length, 2);
      final none = tallyElection(opts, ballots, committeeSeats: -1, now: now);
      expect(none['committee'], isEmpty);
    });

    test('ties keep option order (stable sort like JS)', () {
      final tie = tallyElection(opts, [sel(['P2']), sel(['P1'])], committeeSeats: 3, now: now);
      expect((tie['president'] as Map)['option_id'], 'P1');
    });
  });

  group('tallyElection — separate office votes', () {
    final ballots = [
      const TallyBallot(choices: {
        'president': 'P2',
        'vice_president': 'V1',
        'committee': ['C4', 'C3'],
      }),
      const TallyBallot(choices: {
        'president': 'P2',
        'committee': 'C4',
      }),
    ];
    final r = tallyElection(opts, ballots, separateOfficeVotes: true, committeeSeats: 3, now: now);

    test('counts each office separately', () {
      expect(r['ballot_mode'], 'separate_office');
      expect((r['president'] as Map)['option_id'], 'P2');
      expect((r['president'] as Map)['score'], 2);
      final c = (r['committee'] as List).cast<Map>();
      expect(c.map((e) => e['option_id']), ['C4', 'C3', 'C1']);
      expect(c.map((e) => e['score']), [2, 1, 0]);
    });

    test('selected marks are ignored in separate mode', () {
      final r2 = tallyElection(opts, [sel(['P1'])], separateOfficeVotes: true, now: now);
      expect((r2['president'] as Map)['score'], 0);
      expect(r2['ballot_mode'], 'separate_office');
    });
  });

  group('tallyElection — legacy ranked ballots', () {
    test('only rank-1 counts, ballot mode ranked_legacy', () {
      final ballots = [
        const TallyBallot(rankings: {
          'president': {'P1': 2, 'P2': 1},
          'committee': {'C2': 1, 'C1': 2},
        }),
        const TallyBallot(rankings: {
          'president': {'P2': 1},
        }),
      ];
      final r = tallyElection(opts, ballots, committeeSeats: 1, now: now);
      expect(r['ballot_mode'], 'ranked_legacy');
      expect((r['president'] as Map)['option_id'], 'P2');
      expect((r['president'] as Map)['score'], 2);
      expect((r['committee'] as List).single['option_id'], 'C2');
    });

    test('no ballots at all → ranked_legacy with zero scores', () {
      final r = tallyElection(opts, const [], now: now);
      expect(r['ballot_mode'], 'ranked_legacy');
      expect((r['president'] as Map)['score'], 0);
    });
  });

  group('validateElectionChoices', () {
    test('combined mode', () {
      expect(validateElectionChoices(opts, {'selected': []}, false)?.en, 'Select at least one nominee on your ballot');
      expect(
        validateElectionChoices(opts, {'selected': ['P1', 'P2', 'V1', 'S1', 'C1', 'C2', 'C3', 'C4']}, false)?.en,
        'Select at most 7 nominees (one vote per member)',
      );
      expect(validateElectionChoices(opts, {'selected': ['ZZ']}, false)?.en, 'Invalid nominee on ballot');
      expect(validateElectionChoices(opts, {'selected': ['P1', 'P1']}, false)?.en, 'Duplicate selection on ballot');
      expect(validateElectionChoices(opts, {'selected': ['P1', 'C1']}, false), isNull);
      expect(validateElectionChoices(opts, null, false)?.en, 'Select at least one nominee on your ballot');
    });

    test('separate office mode', () {
      expect(
        validateElectionChoices(opts, {'president': 'P1'}, true, committeeSeats: 3)?.en,
        'Select one candidate for vice president',
      );
      expect(
        validateElectionChoices(opts, {'president': 'V1'}, true)?.en,
        'Invalid selection for president',
      );
      final full = {'president': 'P1', 'vice_president': 'V1', 'secretary': 'S1'};
      expect(validateElectionChoices(opts, full, true)?.en, 'Select Executive Member candidate(s)');
      expect(
        validateElectionChoices(opts, {...full, 'committee': ['C1', 'C2', 'C3', 'C4']}, true)?.en,
        'Select at most 3 Executive Member(s)',
      );
      expect(validateElectionChoices(opts, {...full, 'committee': ['P1']}, true)?.en, 'Invalid Executive Member selection');
      expect(
        validateElectionChoices(opts, {...full, 'committee': ['C1', 'C1']}, true)?.en,
        'Duplicate Executive Member selection',
      );
      expect(validateElectionChoices(opts, {...full, 'committee': 'C1'}, true), isNull);
      expect(validateElectionChoices(opts, {...full, 'committee': 'C1'}, true, committeeSeats: 0)?.en,
          'Select at most 0 Executive Member(s)');
    });

    test('Hindi text is provided', () {
      expect(validateElectionChoices(opts, {'selected': []}, false)?.hi, isNotEmpty);
    });

    test('legacy ranked validation always rejects', () {
      expect(validateElectionRankings(const [], {})?.en, 'No candidates');
      expect(validateElectionRankings(opts, {})?.en, 'Ranked ballots are no longer used. Refresh and cast a simple ballot.');
    });
  });

  group('results helpers', () {
    final results = {
      'president': {'option_id': 'P1', 'name': 'Asha', 'score': 2},
      'vice_president': null,
      'secretary': {'option_id': 'S1', 'name': 'Divya', 'score': 0},
      'treasurer': null,
      'committee': [
        {'option_id': 'C1', 'name': 'Esha', 'score': 2},
      ],
      'formation': {
        'selected_runner_up_ids': [],
        'voluntary': [
          {'key': 'vol-m1-A-1', 'name': 'Iqbal', 'source': 'voluntary'},
        ],
        'executive_proposed': [
          {'key': 'exec-1', 'name': 'Jai', 'source': 'executive_proposed'},
        ],
      },
      'runners_up': {
        'president': [
          {'option_id': 'P2', 'name': 'Bharat', 'score': 1, 'place': 2},
        ],
      },
      'tallied_at': '2026-10-12T10:30:00.000Z',
    };

    test('countFormedCommittee counts offices, committee and formation', () {
      expect(countFormedCommittee(results), 5);
      expect(countFormedCommittee(null), 0);
      expect(countFormedCommittee({'committee': []}), 0);
    });

    test('typed view', () {
      final r = ElectionResults.tryParse(results)!;
      expect(r.office('president')?.name, 'Asha');
      expect(r.office('vice_president'), isNull);
      expect(r.committee.single.optionId, 'C1');
      expect(r.formation.voluntary.single.name, 'Iqbal');
      expect(r.formation.executiveProposed.single.key, 'exec-1');
      expect(r.listRunnersUp().single.fromPost, 'president');
    });

    test('formation entries keep other keys', () {
      final f = formationRawOf(results);
      final next = resultsWithFormationEntries(results, 'voluntary', [...formationEntries(f, 'voluntary'), {'key': 'k2'}]);
      expect(((next['formation'] as Map)['voluntary'] as List).length, 2);
      expect(((next['formation'] as Map)['executive_proposed'] as List).length, 1);
      expect(next['runners_up'], isNotNull);
      expect(formationRawOf({}), emptyFormationJson());
    });

    test('formation member JSON matches the web shapes', () {
      const vol = FormationMember(key: 'vol-m-A', name: 'Iqbal', source: 'voluntary', flatNumber: 'A-1');
      expect(vol.toJson(), {
        'key': 'vol-m-A',
        'name': 'Iqbal',
        'flat_number': 'A-1',
        'flat_id': null,
        'member_id': null,
        'source': 'voluntary',
      });
      const exec = FormationMember(key: 'exec-1', name: 'Jai', source: 'executive_proposed');
      expect(exec.toJson(), {'key': 'exec-1', 'name': 'Jai', 'flat_number': null, 'source': 'executive_proposed'});
    });
  });
}
