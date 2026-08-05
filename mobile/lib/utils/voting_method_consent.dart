/// Option A / B presented to members before voting method is finalized.
library;

typedef ElectionVotingMethod = String;

const votingMethodSecretBallot = 'secret_ballot';
const votingMethodShowOfHands = 'show_of_hands';

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
  final ElectionVotingMethod method;
  final String titleEn;
  final String titleHi;
  final String effectEn;
  final String effectHi;
}

const votingMethodOptions = {
  votingMethodSecretBallot: VotingMethodOption(
    code: 'A',
    method: votingMethodSecretBallot,
    titleEn: 'Option A — Secret Ballot',
    titleHi: 'विकल्प A — गुप्त मतपत्र',
    effectEn:
        'Each eligible member casts a private ballot. Individual choices are not announced aloud. Suitable when members prefer privacy and reduced influence from open discussion during polling.',
    effectHi:
        'प्रत्येक पात्र सदस्य निजी मतपत्र डालता है। व्यक्तिगत पसंद खुले में घोषित नहीं होती। जब सदस्य मतदान के समय गोपनीयता चाहें तो उपयुक्त।',
  ),
  votingMethodShowOfHands: VotingMethodOption(
    code: 'B',
    method: votingMethodShowOfHands,
    titleEn: 'Option B — Show of Hands',
    titleHi: 'विकल्प B — हाथ उठाकर मतदान',
    effectEn:
        'Votes are indicated openly by show of hands (or equivalent open count). Results are visible to those present. Suitable when the meeting prefers transparency and immediate counting.',
    effectHi:
        'मत हाथ उठाकर (या समकक्ष खुली गणना से) दिखाये जाते हैं। उपस्थित सदस्यों को परिणाम तुरंत दिखते हैं। जब बैठक पारदर्शिता और तत्काल गणना चाहे तो उपयुक्त।',
  ),
};

class VotingMethodConsentRow {
  const VotingMethodConsentRow({
    required this.id,
    required this.pollId,
    required this.memberId,
    required this.choice,
    this.memberName,
    this.flatNumber,
    required this.createdAt,
  });

  final String id;
  final String pollId;
  final String memberId;
  final ElectionVotingMethod choice;
  final String? memberName;
  final String? flatNumber;
  final String createdAt;

  factory VotingMethodConsentRow.fromRow(Map<String, dynamic> r) => VotingMethodConsentRow(
        id: r['id'] as String,
        pollId: r['poll_id'] as String,
        memberId: r['member_id'] as String,
        choice: r['choice'] as String,
        memberName: r['member_name'] as String?,
        flatNumber: r['flat_number'] as String?,
        createdAt: r['created_at'] as String? ?? '',
      );
}

class VotingMethodConsentTally {
  const VotingMethodConsentTally({
    required this.secretBallot,
    required this.showOfHands,
    required this.total,
  });

  final int secretBallot;
  final int showOfHands;
  final int total;
}

VotingMethodConsentTally tallyFromConsents(List<VotingMethodConsentRow> rows) {
  var secretBallot = 0;
  var showOfHands = 0;
  for (final r in rows) {
    if (r.choice == votingMethodSecretBallot) {
      secretBallot += 1;
    } else if (r.choice == votingMethodShowOfHands) {
      showOfHands += 1;
    }
  }
  return VotingMethodConsentTally(
    secretBallot: secretBallot,
    showOfHands: showOfHands,
    total: rows.length,
  );
}

/// Tie → null (admin must not auto-pick).
ElectionVotingMethod? leadingConsentMethod(VotingMethodConsentTally tally) {
  if (tally.total < 1) return null;
  if (tally.secretBallot == tally.showOfHands) return null;
  return tally.secretBallot > tally.showOfHands
      ? votingMethodSecretBallot
      : votingMethodShowOfHands;
}

String votingMethodLabel(ElectionVotingMethod? method, {bool hi = false}) {
  if (method == null || method.isEmpty) return hi ? 'अभी निर्धारित नहीं' : 'Not yet recorded';
  final o = votingMethodOptions[method];
  if (o == null) return method;
  return hi ? o.titleHi : o.titleEn;
}
