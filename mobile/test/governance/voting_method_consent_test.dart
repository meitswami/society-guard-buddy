import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/governance/logic/voting_method_consent.dart';

VotingMethodConsentRow consent(String id, String choice) =>
    VotingMethodConsentRow(
        id: id, pollId: 'p', memberId: 'm$id', choice: choice);

void main() {
  test('options A / B', () {
    expect(votingMethodOptions['secret_ballot']!.code, 'A');
    expect(votingMethodOptions['show_of_hands']!.code, 'B');
    expect(votingMethodOption('show_of_hands').titleEn,
        'Option B — Show of Hands');
    expect(votingMethodOption('secret_ballot').title(true),
        'विकल्प A — गुप्त मतपत्र');
  });

  test('tally counts each method and the total', () {
    final t = tallyFromConsents([
      consent('1', 'secret_ballot'),
      consent('2', 'show_of_hands'),
      consent('3', 'secret_ballot'),
      consent('4', 'something_else'),
    ]);
    expect(t.secretBallot, 2);
    expect(t.showOfHands, 1);
    expect(t.total, 4);
    expect(t.countFor('show_of_hands'), 1);
  });

  test('leading method — none on empty or tie', () {
    expect(leadingConsentMethod(tallyFromConsents(const [])), isNull);
    expect(
        leadingConsentMethod(tallyFromConsents(
            [consent('1', 'secret_ballot'), consent('2', 'show_of_hands')])),
        isNull);
    expect(
        leadingConsentMethod(
            tallyFromConsents([consent('1', 'show_of_hands')])),
        'show_of_hands');
    expect(
        leadingConsentMethod(
            tallyFromConsents([consent('1', 'secret_ballot')])),
        'secret_ballot');
  });

  test('finalize requires full consent unless partial is allowed', () {
    expect(
      consentIncompleteError(
          consentTotal: 3, eligibleMemberCount: 30, allowPartial: false),
      'Consent incomplete: 3 of 30 eligible members have consented. Wait for all members, or use admin override only if the meeting so resolves.',
    );
    expect(
        consentIncompleteError(
            consentTotal: 3, eligibleMemberCount: 30, allowPartial: true),
        isNull);
    expect(
        consentIncompleteError(
            consentTotal: 30, eligibleMemberCount: 30, allowPartial: false),
        isNull);
  });

  test('duplicate consent errors are recognised', () {
    expect(
        isDuplicateConsentError(
            'duplicate key value violates unique constraint'),
        isTrue);
    expect(isDuplicateConsentError('Row is IMMUTABLE'), isTrue);
    expect(isDuplicateConsentError('network down'), isFalse);
  });

  test('row parsing', () {
    final r = VotingMethodConsentRow.fromJson({
      'id': 1,
      'poll_id': 'p',
      'member_id': 'm',
      'choice': 'secret_ballot',
      'member_name': 'Ram',
      'flat_number': 'A-1',
      'created_at': '2026-01-01',
    });
    expect(r.id, '1');
    expect(r.memberName, 'Ram');
  });
}
