/// Port of web `src/lib/electionGovernance.ts` — registered bye-laws are the
/// controlling source for the Election Module.
library;

import 'package:intl/intl.dart';

/// Election posts (DB values of `poll_options.election_post`).
abstract final class ElectionPosts {
  static const president = 'president';
  static const vicePresident = 'vice_president';
  static const secretary = 'secretary';
  static const treasurer = 'treasurer';
  static const committee = 'committee';

  /// Office posts (one winner each).
  static const offices = [president, vicePresident, secretary, treasurer];

  /// Seven Management Committee seats: President, Vice-President, Secretary,
  /// Treasurer and 3 Executive Members (`committee`).
  static const managementCommittee = [president, vicePresident, secretary, treasurer, committee];

  /// All posts that may appear on legacy elections.
  static const all = [president, vicePresident, secretary, treasurer, committee];

  /// @deprecated Prefer [managementCommittee] (bye-law 7-seat MC).
  static const threeExecutive = [president, secretary, treasurer];

  static bool isKnown(String? post) => post != null && all.contains(post);
}

enum ElectionPhase { nomination, voting, closed, applied }

/// DB value of `polls.voting_method`.
abstract final class VotingMethods {
  static const secretBallot = 'secret_ballot';
  static const showOfHands = 'show_of_hands';
  static const all = [secretBallot, showOfHands];
}

/// Registered bye-law constants (30-flat configuration, 7-member MC).
abstract final class ByeLaw {
  static const apartments = 30;
  static const committeeSize = 7;
  static const president = 1;
  static const vicePresident = 1;
  static const secretary = 1;
  static const treasurer = 1;
  static const executiveMembers = 3;
  static const termYears = 2;
  static const reElectionPermitted = true;
  static const votesPerMember = 1;
  static const proxyDeadlineHours = 48;
  static const maxProxiesPerPerson = 1;
  static const electionQuorumNumerator = 3;
  static const electionQuorumDenominator = 4;
  static const electionQuorumFor30 = 23;
  static const arrearsDisqualifyDays = 60;
  static const mcMeetingQuorumNumerator = 2;
  static const mcMeetingQuorumDenominator = 3;
  static const mcMeetingQuorumOfSeven = 5;
  static const regularMeetingNoticeClearDays = 7;
  static const firstMeetingWithinDays = 30;
  static const removalDisqualificationYears = 2;
  static const votingMethods = VotingMethods.all;
}

/// Fixed Managing Committee size (bye-laws).
const int minCommitteeSize = ByeLaw.committeeSize;

/// Target equals fixed size — no target-15 formation.
const int defaultTargetCommitteeSize = ByeLaw.committeeSize;

/// Fixed committee size alias.
const int fixedCommitteeSize = ByeLaw.committeeSize;

/// Bye-laws do not auto-seat 2nd/3rd place.
const int runnerUpPlaces = 0;

/// Default term length in years when creating an election.
const int defaultTermYears = ByeLaw.termYears;

const Map<String, bool> defaultOpenPosts = {
  ElectionPosts.president: true,
  ElectionPosts.vicePresident: true,
  ElectionPosts.secretary: true,
  ElectionPosts.treasurer: true,
  ElectionPosts.committee: true,
};

const Map<String, int> defaultWinningVotes = {
  ElectionPosts.president: 0,
  ElectionPosts.vicePresident: 0,
  ElectionPosts.secretary: 0,
  ElectionPosts.treasurer: 0,
  ElectionPosts.committee: 0,
};

const Map<String, String> postDisplayEn = {
  ElectionPosts.president: 'President',
  ElectionPosts.vicePresident: 'Vice-President',
  ElectionPosts.secretary: 'Secretary',
  ElectionPosts.treasurer: 'Treasurer',
  ElectionPosts.committee: 'Executive Member',
};

const Map<String, String> postDisplayHi = {
  ElectionPosts.president: 'अध्यक्ष',
  ElectionPosts.vicePresident: 'उपाध्यक्ष',
  ElectionPosts.secretary: 'सचिव',
  ElectionPosts.treasurer: 'कोषाध्यक्ष',
  ElectionPosts.committee: 'कार्यकारिणी सदस्य',
};

/// Display name of a post (English like the web `POST_DISPLAY`, Hindi `POST_DISPLAY_HI`).
String postDisplay(String post, {bool hi = false}) =>
    (hi ? postDisplayHi[post] : postDisplayEn[post]) ?? post;

/// Minimum members that must be represented for election quorum (3/4, rounded up).
int electionQuorumRequired(int memberCount) =>
    ((memberCount * ByeLaw.electionQuorumNumerator) / ByeLaw.electionQuorumDenominator).ceil();

/// Ordinary Management Committee meeting quorum (2/3 of roster size).
int mcMeetingQuorumRequired([int committeeSize = ByeLaw.committeeSize]) =>
    ((committeeSize * ByeLaw.mcMeetingQuorumNumerator) / ByeLaw.mcMeetingQuorumDenominator).ceil();

ElectionPhase? _phaseFromString(Object? raw) => switch (raw) {
      'nomination' => ElectionPhase.nomination,
      'voting' => ElectionPhase.voting,
      'closed' => ElectionPhase.closed,
      'applied' => ElectionPhase.applied,
      _ => null,
    };

/// Web `electionPhase(poll)`; [poll] is a `polls` row (JSON map).
ElectionPhase electionPhase(Map<String, dynamic> poll) {
  final p = _phaseFromString(poll['election_phase']);
  if (p != null) return p;
  final active = poll['is_active'] == true;
  final applied = poll['election_applied_at'];
  if (!active && applied != null && applied.toString().isNotEmpty) return ElectionPhase.applied;
  if (!active) return ElectionPhase.closed;
  return ElectionPhase.voting;
}

String electionPhaseValue(ElectionPhase p) => p.name;

int? _epochMs(Object? iso) {
  if (iso == null) return null;
  final s = iso.toString();
  if (s.isEmpty) return null;
  return DateTime.tryParse(s)?.millisecondsSinceEpoch ?? -1;
}

bool _inWindow(Object? startsAt, Object? endsAt, int now) {
  final start = _epochMs(startsAt);
  final end = _epochMs(endsAt);
  // JS `new Date(invalid).getTime()` is NaN → every comparison is false.
  if (start == -1 || end == -1) return false;
  final s = start ?? 0;
  final e = end ?? 9007199254740991; // Number.MAX_SAFE_INTEGER
  return now >= s && now <= e;
}

bool isNominationWindowOpen(Map<String, dynamic> poll, [DateTime? now]) {
  if (electionPhase(poll) != ElectionPhase.nomination || poll['is_active'] != true) return false;
  return _inWindow(
    poll['nomination_starts_at'],
    poll['nomination_ends_at'],
    (now ?? DateTime.now()).millisecondsSinceEpoch,
  );
}

Map<String, dynamic> _openPostsOf(Map<String, dynamic> poll) {
  final raw = poll['open_posts'];
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return Map<String, dynamic>.from(defaultOpenPosts);
}

bool isPostOpenForNomination(Map<String, dynamic> poll, String post, [DateTime? now]) {
  if (!isNominationWindowOpen(poll, now)) return false;
  return _openPostsOf(poll)[post] != false;
}

bool isVotingWindowOpen(Map<String, dynamic> poll, [DateTime? now]) {
  if (electionPhase(poll) != ElectionPhase.voting || poll['is_active'] != true) return false;
  return _inWindow(
    poll['voting_starts_at'],
    poll['voting_ends_at'],
    (now ?? DateTime.now()).millisecondsSinceEpoch,
  );
}

final _windowFmt = DateFormat('dd MMM yyyy, hh:mm a', 'en_US');

/// `en-IN` style `12 Oct 2026, 09:30 AM` in local time.
String formatElectionInstant(DateTime d) => _windowFmt.format(d.toLocal());

String _windowLabel(Object? startsAt, Object? endsAt, String empty, bool hi) {
  final start = startsAt == null ? null : DateTime.tryParse(startsAt.toString());
  final end = endsAt == null ? null : DateTime.tryParse(endsAt.toString());
  if (start == null && end == null) return empty;
  if (start != null && end != null) return '${formatElectionInstant(start)} → ${formatElectionInstant(end)}';
  if (start != null) return hi ? '${formatElectionInstant(start)} से' : 'From ${formatElectionInstant(start)}';
  return hi ? '${formatElectionInstant(end!)} तक' : 'Until ${formatElectionInstant(end!)}';
}

String nominationWindowLabel(Map<String, dynamic> poll, {bool hi = false}) => _windowLabel(
      poll['nomination_starts_at'],
      poll['nomination_ends_at'],
      hi ? 'नामांकन अवधि निर्धारित नहीं' : 'Nomination window not scheduled',
      hi,
    );

String votingWindowLabel(Map<String, dynamic> poll, {bool hi = false}) => _windowLabel(
      poll['voting_starts_at'],
      poll['voting_ends_at'],
      hi ? 'मतदान अवधि निर्धारित नहीं' : 'Voting window not scheduled',
      hi,
    );

String phaseBadgeLabel(ElectionPhase phase, {bool hi = false}) => switch (phase) {
      ElectionPhase.nomination => hi ? 'नामांकन खुला' : 'Nomination open',
      ElectionPhase.voting => hi ? 'मतदान खुला' : 'Voting open',
      ElectionPhase.closed => hi ? 'बंद — समिति गठन' : 'Closed — form committee',
      ElectionPhase.applied => hi ? 'समिति में प्रकाशित' : 'Published to committee',
    };

/// Posts shown on an election card: open posts first, then legacy posts that only
/// appear on existing options.
List<String> postsForPoll(Map<String, dynamic> poll, Iterable<String?> optionPosts) {
  final open = _openPostsOf(poll);
  final fromOpen = ElectionPosts.managementCommittee.where((p) => open[p] != false).toList();
  final fromOpts = optionPosts.whereType<String>().where(ElectionPosts.isKnown).toSet();
  final legacy = ElectionPosts.all.where((p) => fromOpts.contains(p) && !fromOpen.contains(p));
  return [...fromOpen, ...legacy];
}

Map<String, int> parseWinningVotes(Object? raw) {
  final out = Map<String, int>.from(defaultWinningVotes);
  if (raw is! Map) return out;
  raw.forEach((k, v) {
    final n = v is num ? v.toDouble() : double.tryParse('$v');
    if (n != null && n.isFinite && n >= 0) out['$k'] = n.floor();
  });
  return out;
}

String _pad2(int n) => n.toString().padLeft(2, '0');

/// `yyyy-MM-ddTHH:mm` in local time (web `toDatetimeLocalValue`).
String toDatetimeLocalValue(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '';
  return '${d.year}-${_pad2(d.month)}-${_pad2(d.day)}T${_pad2(d.hour)}:${_pad2(d.minute)}';
}

/// JS `Date.prototype.toISOString()` (UTC, millisecond precision, `Z`).
String jsIsoString(DateTime d) {
  final u = d.toUtc();
  final ms = u.millisecond.toString().padLeft(3, '0');
  final y = u.year >= 0 && u.year <= 9999 ? u.year.toString().padLeft(4, '0') : u.year.toString();
  return '$y-${_pad2(u.month)}-${_pad2(u.day)}T${_pad2(u.hour)}:${_pad2(u.minute)}:${_pad2(u.second)}.${ms}Z';
}

/// `new Date().toISOString().slice(0, 10)` — UTC calendar date like the web.
String utcIsoDate([DateTime? d]) => jsIsoString(d ?? DateTime.now()).substring(0, 10);

/// Default `term_to` = `term_from` + [years] (bye-laws: 2 years).
String defaultTermEndIso(String termFromIso, [int years = defaultTermYears]) {
  final d = DateTime.parse(termFromIso);
  final shifted = d.isUtc
      ? DateTime.utc(d.year + years, d.month, d.day, d.hour, d.minute, d.second, d.millisecond)
      : DateTime(d.year + years, d.month, d.day, d.hour, d.minute, d.second, d.millisecond);
  return jsIsoString(shifted);
}

/// `polls.voting_method` label (`Secret Ballot` / `Show of Hands`).
String votingMethodShortLabel(String? method, {bool hi = false}) {
  if (method == VotingMethods.showOfHands) return hi ? 'हाथ उठाकर' : 'Show of Hands';
  return hi ? 'गुप्त मतपत्र' : 'Secret Ballot';
}
