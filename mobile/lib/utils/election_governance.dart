/// Registered bye-laws — controlling source for the Election Module.
library;

enum ElectionPhase { nomination, voting, closed, applied }

/// Bye-law constants (30-flat / 7-member Management Committee configuration).
class ByeLaw {
  static const apartments = 30;
  static const committeeSize = 7;
  static const termYears = 2;
  static const proxyDeadlineHours = 48;
  static const maxProxiesPerPerson = 1;
  static const electionQuorumNumerator = 3;
  static const electionQuorumDenominator = 4;
  static const electionQuorumFor30 = 23;
  static const arrearsDisqualifyDays = 60;
  static const mcMeetingQuorumOfSeven = 5;
  static const regularMeetingNoticeClearDays = 7;
  static const firstMeetingWithinDays = 30;
  static const removalDisqualificationYears = 2;
}

/// Seven Management Committee posts under the bye-laws.
const managementCommitteePosts = [
  'president',
  'vice_president',
  'secretary',
  'treasurer',
  'committee',
];

/// @Deprecated Prefer [managementCommitteePosts].
const threeExecutivePosts = ['president', 'secretary', 'treasurer'];

/// Fixed Managing Committee size (bye-laws).
const minCommitteeSize = ByeLaw.committeeSize;

/// Target equals fixed size — no target-15 formation.
const defaultTargetCommitteeSize = ByeLaw.committeeSize;

/// Bye-laws do not auto-seat 2nd/3rd place.
const runnerUpPlaces = 0;

const defaultTermYears = ByeLaw.termYears;

/// Legacy + current posts that may appear on older elections.
const executivePosts = managementCommitteePosts;
const allElectionPosts = [
  'president',
  'vice_president',
  'secretary',
  'treasurer',
  'committee',
];

const defaultOpenPosts = {
  'president': true,
  'vice_president': true,
  'secretary': true,
  'treasurer': true,
  'committee': true,
};

const postDisplay = {
  'president': 'President',
  'vice_president': 'Vice-President',
  'secretary': 'Secretary',
  'treasurer': 'Treasurer',
  'committee': 'Executive Member',
};

int electionQuorumRequired(int memberCount) =>
    ((memberCount * ByeLaw.electionQuorumNumerator) / ByeLaw.electionQuorumDenominator).ceil();

int mcMeetingQuorumRequired([int committeeSize = ByeLaw.committeeSize]) =>
    ((committeeSize * 2) / 3).ceil();

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
  return managementCommitteePosts.contains(post);
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
  final out = <String, int>{
    'president': 0,
    'vice_president': 0,
    'secretary': 0,
    'treasurer': 0,
    'committee': 0,
  };
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
