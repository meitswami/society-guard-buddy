enum ElectionPhase { nomination, voting, closed, applied }

/// Posts for new society elections.
const threeExecutivePosts = ['president', 'secretary', 'treasurer'];

/// Minimum Managing Committee size after formation (charter).
const minCommitteeSize = 7;

/// Society default target Managing Committee size (charter).
const defaultTargetCommitteeSize = 15;

/// How many unelected places (2nd, 3rd) from each executive post may join the committee.
const runnerUpPlaces = 2;

/// Legacy + current posts that may appear on older elections.
const executivePosts = threeExecutivePosts;
const allElectionPosts = [
  'president',
  'vice_president',
  'secretary',
  'treasurer',
  'committee',
];

const defaultOpenPosts = {
  'president': true,
  'secretary': true,
  'treasurer': true,
  'vice_president': false,
  'committee': false,
};

const postDisplay = {
  'president': 'President',
  'vice_president': 'Vice-President',
  'secretary': 'Secretary',
  'treasurer': 'Treasurer',
  'committee': 'Committee member',
};

ElectionPhase electionPhase(Map<String, dynamic> poll) {
  final p = poll['election_phase'] as String?;
  switch (p) {
    case 'nomination':
      return ElectionPhase.nomination;
    case 'voting':
      return ElectionPhase.voting;
    case 'closed':
      return ElectionPhase.closed;
    case 'applied':
      return ElectionPhase.applied;
  }
  final active = poll['is_active'] as bool? ?? false;
  if (!active && poll['election_applied_at'] != null) return ElectionPhase.applied;
  if (!active) return ElectionPhase.closed;
  return ElectionPhase.voting;
}

bool _inWindow(dynamic startsAt, dynamic endsAt, DateTime now) {
  final n = now.millisecondsSinceEpoch;
  final start = startsAt != null ? DateTime.parse(startsAt as String).millisecondsSinceEpoch : 0;
  final end = endsAt != null
      ? DateTime.parse(endsAt as String).millisecondsSinceEpoch
      : 9223372036854775807;
  return n >= start && n <= end;
}

bool isNominationWindowOpen(Map<String, dynamic> poll, [DateTime? now]) {
  if (electionPhase(poll) != ElectionPhase.nomination) return false;
  if (poll['is_active'] != true) return false;
  return _inWindow(poll['nomination_starts_at'], poll['nomination_ends_at'], now ?? DateTime.now());
}

bool isPostOpenForNomination(Map<String, dynamic> poll, String post) {
  if (!isNominationWindowOpen(poll)) return false;
  final open = poll['open_posts'];
  if (open is Map) {
    final v = open[post];
    if (v == false) return false;
  }
  return threeExecutivePosts.contains(post);
}

bool isVotingWindowOpen(Map<String, dynamic> poll, [DateTime? now]) {
  if (electionPhase(poll) != ElectionPhase.voting) return false;
  if (poll['is_active'] != true) return false;
  return _inWindow(poll['voting_starts_at'], poll['voting_ends_at'], now ?? DateTime.now());
}

String phaseBadgeLabel(ElectionPhase phase) {
  return switch (phase) {
    ElectionPhase.nomination => 'Nomination open',
    ElectionPhase.voting => 'Voting open',
    ElectionPhase.closed => 'Closed — admin review',
    ElectionPhase.applied => 'Published to committee',
  };
}

String _windowLabel(dynamic startsAt, dynamic endsAt, String empty) {
  final start = startsAt != null ? DateTime.tryParse(startsAt as String) : null;
  final end = endsAt != null ? DateTime.tryParse(endsAt as String) : null;
  if (start == null && end == null) return empty;
  String fmt(DateTime d) => '${d.day.toString().padLeft(2, '0')} ${_month(d.month)} ${d.year}';
  if (start != null && end != null) return '${fmt(start)} → ${fmt(end)}';
  if (start != null) return 'From ${fmt(start)}';
  return 'Until ${fmt(end!)}';
}

String nominationWindowLabel(Map<String, dynamic> poll) {
  return _windowLabel(
    poll['nomination_starts_at'],
    poll['nomination_ends_at'],
    'Nomination window not scheduled',
  );
}

String votingWindowLabel(Map<String, dynamic> poll) {
  return _windowLabel(
    poll['voting_starts_at'],
    poll['voting_ends_at'],
    'Voting window not scheduled',
  );
}

Map<String, int> parseWinningVotes(dynamic raw) {
  final out = <String, int>{'president': 0, 'secretary': 0, 'treasurer': 0};
  if (raw is! Map) return out;
  for (final e in raw.entries) {
    final n = e.value;
    if (n is num && n >= 0) out[e.key.toString()] = n.toInt();
  }
  return out;
}

String _month(int m) {
  const names = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return names[m];
}
