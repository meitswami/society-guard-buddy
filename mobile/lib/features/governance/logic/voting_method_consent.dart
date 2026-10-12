/// Pure parts of web `src/lib/electionVotingMethodConsent.ts`.
library;

import 'election_governance.dart';

/// Option A / B presented to members before the voting method is finalized.
class VotingMethodOption {
  const VotingMethodOption({
    required this.code,
    required this.method,
    required this.titleEn,
    required this.titleHi,
    required this.effectEn,
    required this.effectHi,
  });

  final String code;
  final String method;
  final String titleEn;
  final String titleHi;
  final String effectEn;
  final String effectHi;

  String title(bool hi) => hi ? titleHi : titleEn;
  String effect(bool hi) => hi ? effectHi : effectEn;
}

const Map<String, VotingMethodOption> votingMethodOptions = {
  VotingMethods.secretBallot: VotingMethodOption(
    code: 'A',
    method: VotingMethods.secretBallot,
    titleEn: 'Option A — Secret Ballot',
    titleHi: 'विकल्प A — गुप्त मतपत्र',
    effectEn:
        'Each eligible member casts a private ballot. Individual choices are not announced aloud. Suitable when members prefer privacy and reduced influence from open discussion during polling.',
    effectHi:
        'प्रत्येक पात्र सदस्य निजी मतपत्र डालता है। व्यक्तिगत पसंद खुले में घोषित नहीं होती। जब सदस्य मतदान के समय गोपनीयता चाहें तो उपयुक्त।',
  ),
  VotingMethods.showOfHands: VotingMethodOption(
    code: 'B',
    method: VotingMethods.showOfHands,
    titleEn: 'Option B — Show of Hands',
    titleHi: 'विकल्प B — हाथ उठाकर मतदान',
    effectEn:
        'Votes are indicated openly by show of hands (or equivalent open count). Results are visible to those present. Suitable when the meeting prefers transparency and immediate counting.',
    effectHi:
        'मत हाथ उठाकर (या समकक्ष खुली गणना से) दिखाये जाते हैं। उपस्थित सदस्यों को परिणाम तुरंत दिखते हैं। जब बैठक पारदर्शिता और तत्काल गणना चाहे तो उपयुक्त।',
  ),
};

VotingMethodOption votingMethodOption(String method) =>
    votingMethodOptions[method] ??
    votingMethodOptions[VotingMethods.secretBallot]!;

/// Row of `election_voting_method_consents`.
class VotingMethodConsentRow {
  const VotingMethodConsentRow({
    required this.id,
    required this.pollId,
    required this.memberId,
    required this.choice,
    this.memberName,
    this.flatNumber,
    this.createdAt,
  });

  final String id;
  final String pollId;
  final String memberId;
  final String choice;
  final String? memberName;
  final String? flatNumber;
  final String? createdAt;

  factory VotingMethodConsentRow.fromJson(Map<String, dynamic> j) =>
      VotingMethodConsentRow(
        id: '${j['id']}',
        pollId: '${j['poll_id']}',
        memberId: '${j['member_id']}',
        choice: '${j['choice']}',
        memberName: j['member_name'] as String?,
        flatNumber: j['flat_number'] as String?,
        createdAt: j['created_at'] as String?,
      );
}

class VotingMethodConsentTally {
  const VotingMethodConsentTally(
      {required this.secretBallot,
      required this.showOfHands,
      required this.total});

  final int secretBallot;
  final int showOfHands;
  final int total;

  int countFor(String method) =>
      method == VotingMethods.secretBallot ? secretBallot : showOfHands;
}

VotingMethodConsentTally tallyFromConsents(List<VotingMethodConsentRow> rows) {
  var secret = 0;
  var hands = 0;
  for (final r in rows) {
    if (r.choice == VotingMethods.secretBallot) {
      secret += 1;
    } else if (r.choice == VotingMethods.showOfHands) {
      hands += 1;
    }
  }
  return VotingMethodConsentTally(
      secretBallot: secret, showOfHands: hands, total: rows.length);
}

/// Leading method, or null on no consent / a tie (admin must not auto-pick).
String? leadingConsentMethod(VotingMethodConsentTally tally) {
  if (tally.total < 1) return null;
  if (tally.secretBallot == tally.showOfHands) return null;
  return tally.secretBallot > tally.showOfHands
      ? VotingMethods.secretBallot
      : VotingMethods.showOfHands;
}

/// Error shown when finalizing before every eligible member consented (web text).
String? consentIncompleteError({
  required int consentTotal,
  required int eligibleMemberCount,
  required bool allowPartial,
  bool hi = false,
}) {
  if (allowPartial || consentTotal >= eligibleMemberCount) return null;
  return hi
      ? 'सहमति अधूरी: $eligibleMemberCount पात्र सदस्यों में से $consentTotal ने सहमति दी है। सभी सदस्यों की प्रतीक्षा करें, या बैठक के प्रस्ताव पर ही प्रशासक ओवरराइड का उपयोग करें।'
      : 'Consent incomplete: $consentTotal of $eligibleMemberCount eligible members have consented. Wait for all members, or use admin override only if the meeting so resolves.';
}

/// Duplicate consent insert → friendly message (web regex `duplicate|unique|immutable`).
bool isDuplicateConsentError(String message) =>
    RegExp('duplicate|unique|immutable', caseSensitive: false)
        .hasMatch(message);
