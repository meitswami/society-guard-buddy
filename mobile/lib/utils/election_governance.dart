enum ElectionPhase { nomination, voting, closed, applied }

const executivePosts = ['president', 'vice_president', 'secretary', 'treasurer'];
const allElectionPosts = [...executivePosts, 'committee'];

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

bool isPostOpenForNomination(Map<String, dynamic> poll, String post) {
  if (electionPhase(poll) != ElectionPhase.nomination) return false;
  final open = poll['open_posts'];
  if (open is Map) {
    final v = open[post];
    if (v == false) return false;
  }
  return true;
}

bool isVotingWindowOpen(Map<String, dynamic> poll, [DateTime? now]) {
  if (electionPhase(poll) != ElectionPhase.voting) return false;
  if (poll['is_active'] != true) return false;
  final n = (now ?? DateTime.now()).millisecondsSinceEpoch;
  final start = poll['voting_starts_at'] != null
      ? DateTime.parse(poll['voting_starts_at'] as String).millisecondsSinceEpoch
      : 0;
  final end = poll['voting_ends_at'] != null
      ? DateTime.parse(poll['voting_ends_at'] as String).millisecondsSinceEpoch
      : 9223372036854775807;
  return n >= start && n <= end;
}

String phaseBadgeLabel(ElectionPhase phase) {
  return switch (phase) {
    ElectionPhase.nomination => 'Nomination open',
    ElectionPhase.voting => 'Voting open',
    ElectionPhase.closed => 'Closed — admin review',
    ElectionPhase.applied => 'Published to committee',
  };
}

String votingWindowLabel(Map<String, dynamic> poll) {
  final start = poll['voting_starts_at'] != null
      ? DateTime.tryParse(poll['voting_starts_at'] as String)
      : null;
  final end = poll['voting_ends_at'] != null
      ? DateTime.tryParse(poll['voting_ends_at'] as String)
      : null;
  if (start == null && end == null) return 'Window not scheduled';
  String fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_month(d.month)} ${d.year}';
  if (start != null && end != null) return '${fmt(start)} → ${fmt(end)}';
  if (start != null) return 'From ${fmt(start)}';
  return 'Until ${fmt(end!)}';
}

String _month(int m) {
  const names = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return names[m];
}
