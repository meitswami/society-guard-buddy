import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/governance/logic/election_eligibility.dart';
import 'package:kutumbika_mobile/features/governance/logic/election_governance.dart';

void main() {
  group('bye-law constants', () {
    test('quorum is 3/4 rounded up (23 of 30)', () {
      expect(electionQuorumRequired(30), 23);
      expect(electionQuorumRequired(ByeLaw.apartments), ByeLaw.electionQuorumFor30);
      expect(electionQuorumRequired(4), 3);
      expect(electionQuorumRequired(5), 4);
      expect(electionQuorumRequired(0), 0);
    });

    test('MC meeting quorum is 2/3 of seven = five', () {
      expect(mcMeetingQuorumRequired(), 5);
      expect(mcMeetingQuorumRequired(ByeLaw.committeeSize), ByeLaw.mcMeetingQuorumOfSeven);
      expect(mcMeetingQuorumRequired(3), 2);
    });

    test('seven seats', () {
      expect(ByeLaw.president + ByeLaw.vicePresident + ByeLaw.secretary + ByeLaw.treasurer + ByeLaw.executiveMembers,
          ByeLaw.committeeSize);
      expect(ElectionPosts.managementCommittee, ['president', 'vice_president', 'secretary', 'treasurer', 'committee']);
      expect(minCommitteeSize, 7);
      expect(defaultTargetCommitteeSize, 7);
      expect(runnerUpPlaces, 0);
      expect(defaultOpenPosts.values.every((v) => v), isTrue);
    });

    test('post display', () {
      expect(postDisplay('vice_president'), 'Vice-President');
      expect(postDisplay('committee'), 'Executive Member');
      expect(postDisplay('committee', hi: true), 'कार्यकारिणी सदस्य');
      expect(postDisplay('unknown'), 'unknown');
    });
  });

  group('electionPhase', () {
    test('explicit phase wins', () {
      for (final p in ['nomination', 'voting', 'closed', 'applied']) {
        expect(electionPhase({'election_phase': p, 'is_active': true}).name, p);
      }
    });

    test('derived phase for legacy rows', () {
      expect(electionPhase({'is_active': true}), ElectionPhase.voting);
      expect(electionPhase({'is_active': false}), ElectionPhase.closed);
      expect(electionPhase({'is_active': false, 'election_applied_at': '2026-01-01'}), ElectionPhase.applied);
    });
  });

  group('windows', () {
    final now = DateTime.utc(2026, 10, 12, 12);
    Map<String, dynamic> poll(String phase, {Object? ns, Object? ne, Object? vs, Object? ve, bool active = true}) => {
          'election_phase': phase,
          'is_active': active,
          'nomination_starts_at': ns,
          'nomination_ends_at': ne,
          'voting_starts_at': vs,
          'voting_ends_at': ve,
        };

    test('nomination window', () {
      expect(isNominationWindowOpen(poll('nomination', ns: '2026-10-10T00:00:00Z', ne: '2026-10-13T00:00:00Z'), now), isTrue);
      expect(isNominationWindowOpen(poll('nomination', ns: '2026-10-13T00:00:00Z'), now), isFalse);
      expect(isNominationWindowOpen(poll('nomination'), now), isTrue, reason: 'no dates → always open');
      expect(isNominationWindowOpen(poll('nomination', active: false), now), isFalse);
      expect(isNominationWindowOpen(poll('voting'), now), isFalse);
      expect(isNominationWindowOpen(poll('nomination', ns: 'garbage'), now), isFalse, reason: 'NaN dates like JS');
    });

    test('post open for nomination honours open_posts', () {
      final p = {...poll('nomination'), 'open_posts': {'president': false}};
      expect(isPostOpenForNomination(p, 'president', now), isFalse);
      expect(isPostOpenForNomination(p, 'secretary', now), isTrue);
      expect(isPostOpenForNomination(poll('nomination'), 'committee', now), isTrue);
    });

    test('voting window', () {
      expect(isVotingWindowOpen(poll('voting', vs: '2026-10-12T11:00:00Z', ve: '2026-10-12T12:00:00Z'), now), isTrue);
      expect(isVotingWindowOpen(poll('voting', ve: '2026-10-12T11:59:59Z'), now), isFalse);
      expect(isVotingWindowOpen(poll('closed'), now), isFalse);
    });

    test('labels', () {
      expect(nominationWindowLabel({}), 'Nomination window not scheduled');
      expect(votingWindowLabel({}), 'Voting window not scheduled');
      final start = DateTime(2026, 10, 12, 9, 30);
      final label = votingWindowLabel({'voting_starts_at': start.toIso8601String()});
      expect(label, 'From 12 Oct 2026, 09:30 AM');
      expect(votingWindowLabel({'voting_ends_at': start.toIso8601String()}), 'Until 12 Oct 2026, 09:30 AM');
      expect(
        votingWindowLabel({'voting_starts_at': start.toIso8601String(), 'voting_ends_at': start.toIso8601String()}),
        '12 Oct 2026, 09:30 AM → 12 Oct 2026, 09:30 AM',
      );
    });

    test('phase badge', () {
      expect(phaseBadgeLabel(ElectionPhase.nomination), 'Nomination open');
      expect(phaseBadgeLabel(ElectionPhase.voting), 'Voting open');
      expect(phaseBadgeLabel(ElectionPhase.closed), 'Closed — form committee');
      expect(phaseBadgeLabel(ElectionPhase.applied), 'Published to committee');
    });
  });

  group('postsForPoll', () {
    test('open posts first then legacy posts found on options', () {
      final poll = {
        'open_posts': {'president': true, 'vice_president': false, 'secretary': true, 'treasurer': true, 'committee': true},
      };
      expect(postsForPoll(poll, ['vice_president', 'committee', 'bogus', null]),
          ['president', 'secretary', 'treasurer', 'committee', 'vice_president']);
      expect(postsForPoll({}, const []), ElectionPosts.managementCommittee);
    });
  });

  group('misc helpers', () {
    test('parseWinningVotes', () {
      expect(parseWinningVotes(null), defaultWinningVotes);
      expect(parseWinningVotes({'president': 3.7, 'committee': -1, 'extra': '2'})['president'], 3);
      expect(parseWinningVotes({'committee': -1})['committee'], 0);
      expect(parseWinningVotes({'extra': '2'})['extra'], 2);
    });

    test('toDatetimeLocalValue', () {
      expect(toDatetimeLocalValue(null), '');
      expect(toDatetimeLocalValue('bad'), '');
      final local = DateTime(2026, 1, 5, 7, 9);
      expect(toDatetimeLocalValue(local.toIso8601String()), '2026-01-05T07:09');
    });

    test('jsIsoString / utcIsoDate', () {
      expect(jsIsoString(DateTime.utc(2026, 2, 3, 4, 5, 6, 7)), '2026-02-03T04:05:06.007Z');
      expect(utcIsoDate(DateTime.utc(2026, 2, 3, 23, 59)), '2026-02-03');
    });

    test('defaultTermEndIso adds two years', () {
      expect(defaultTermEndIso('2026-08-14T00:00:00.000Z'), '2028-08-14T00:00:00.000Z');
    });

    test('voting method label', () {
      expect(votingMethodShortLabel('show_of_hands'), 'Show of Hands');
      expect(votingMethodShortLabel('secret_ballot'), 'Secret Ballot');
      expect(votingMethodShortLabel(null), 'Secret Ballot');
    });
  });

  group('eligibility', () {
    test('reason labels', () {
      expect(eligibilityReasonLabel('member_left'), 'Member has left the Society');
      expect(eligibilityReasonLabel('maintenance_arrears_over_60_days'),
          'Maintenance/common-expense arrears exceed 60 days');
      expect(eligibilityReasonLabel('something_new'), 'something_new');
      expect(eligibilityReasonLabel('member_not_found', hi: true), isNot('member_not_found'));
    });

    test('RPC payload parsing', () {
      final e = ElectionEligibility.fromRpc({
        'eligible': false,
        'reasons': ['maintenance_arrears_over_60_days'],
        'arrears': true,
        'arrears_days': 75,
      }, memberId: 'm1');
      expect(e.eligible, isFalse);
      expect(e.reasons, ['maintenance_arrears_over_60_days']);
      expect(e.arrears, isTrue);
      expect(e.isDesignatedVoter, isTrue);
      expect(e.memberId, 'm1');
      expect(e.arrearsDays, 75);
      final empty = ElectionEligibility.fromRpc(null, memberId: 'm2');
      expect(empty.eligible, isFalse);
      expect(empty.reasons, isEmpty);
    });
  });

  group('notify + proxy', () {
    test('notification copy matches the web', () {
      expect(electionNotifyTitle(ElectionNotifyEvent.nominationOpen), 'Society election — nomination open');
      expect(electionNotifyMessage(ElectionNotifyEvent.votingOpen, 'MC 2026'),
          'Cast your ballot (one vote per eligible member): MC 2026');
      expect(electionNotifyTitle(ElectionNotifyEvent.winnersPublished), 'New committee published');
    });

    test('proxy deadline is 48 hours before the meeting', () {
      final meeting = DateTime.utc(2026, 10, 20, 10);
      expect(proxyDeadline(meeting), DateTime.utc(2026, 10, 18, 10));
      expect(isProxySubmissionOnTime(DateTime.utc(2026, 10, 18, 10), meeting), isTrue);
      expect(isProxySubmissionOnTime(DateTime.utc(2026, 10, 18, 10, 1), meeting), isFalse);
    });
  });
}
