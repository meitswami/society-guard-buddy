import '../logic/election_apply.dart';
import '../logic/election_governance.dart';
import '../logic/election_tally.dart';

String? _s(Object? v) => v == null ? null : '$v';
int _i(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
int? _iOrNull(Object? v) =>
    v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'));

/// Row of `polls` (standard polls and society elections). The raw JSON is kept
/// because the governance helpers read it directly (like the web `any` rows).
class PollRow {
  PollRow(this.raw);

  final Map<String, dynamic> raw;

  String get id => '${raw['id']}';
  String? get societyId => _s(raw['society_id']);
  String get question => (raw['question'] ?? '').toString();
  String? get description => _s(raw['description']);
  bool get isActive => raw['is_active'] == true;
  String? get createdBy => _s(raw['created_by']);
  String? get createdAt => _s(raw['created_at']);

  /// Web `normKind`.
  bool get isElection => raw['poll_kind'] == 'election';

  ElectionPhase get phase => electionPhase(raw);
  String? get electionPhaseRaw => _s(raw['election_phase']);
  String? get votingMethod => _s(raw['voting_method']);
  String? get votingMethodRecordedBy => _s(raw['voting_method_recorded_by']);
  bool get votingMethodConsentOpen => raw['voting_method_consent_open'] == true;
  bool get separateOfficeVotes => raw['separate_office_votes'] == true;
  int? get electionQuorumRequired => _iOrNull(raw['election_quorum_required']);
  int? get memberCountAtElection => _iOrNull(raw['member_count_at_election']);
  int get electionCommitteeSeats =>
      _iOrNull(raw['election_committee_seats']) ?? 0;
  int get targetCommitteeSize {
    final n = _iOrNull(raw['target_committee_size']) ?? 0;
    return n > 0 ? n : defaultTargetCommitteeSize;
  }

  String? get electionTermFrom => _s(raw['election_term_from']);
  String? get electionTermTo => _s(raw['election_term_to']);
  String? get nominationStartsAt => _s(raw['nomination_starts_at']);
  String? get nominationEndsAt => _s(raw['nomination_ends_at']);
  String? get votingStartsAt => _s(raw['voting_starts_at']);
  String? get votingEndsAt => _s(raw['voting_ends_at']);
  Object? get electionResultsRaw => raw['election_results'];
  bool get hasResults => raw['election_results'] is Map;
  Map<String, dynamic>? get electionResults => raw['election_results'] is Map
      ? Map<String, dynamic>.from(raw['election_results'] as Map)
      : null;
}

/// Row of `poll_options`.
class PollOptionRow {
  const PollOptionRow({
    required this.id,
    required this.pollId,
    required this.optionText,
    required this.votesCount,
    this.electionPost,
    this.memberId,
    this.flatId,
    this.flatNumber,
    this.nominatedBy,
    this.nominationStatement,
  });

  final String id;
  final String? pollId;
  final String optionText;
  final String? electionPost;
  final int votesCount;
  final String? memberId;
  final String? flatId;
  final String? flatNumber;
  final String? nominatedBy;
  final String? nominationStatement;

  TallyOption get tally =>
      TallyOption(id: id, optionText: optionText, electionPost: electionPost);

  ApplyOption get apply => ApplyOption(
      id: id,
      optionText: optionText,
      memberId: memberId,
      flatId: flatId,
      flatNumber: flatNumber);

  factory PollOptionRow.fromJson(Map<String, dynamic> j) => PollOptionRow(
        id: '${j['id']}',
        pollId: _s(j['poll_id']),
        optionText: (j['option_text'] ?? '').toString(),
        electionPost: _s(j['election_post']),
        votesCount: _i(j['votes_count']),
        memberId: _s(j['member_id']),
        flatId: _s(j['flat_id']),
        flatNumber: _s(j['flat_number']),
        nominatedBy: _s(j['nominated_by']),
        nominationStatement: _s(j['nomination_statement']),
      );
}

/// Row of `poll_votes` (standard polls).
class PollVoteRow {
  const PollVoteRow({
    required this.id,
    required this.pollId,
    required this.optionId,
    required this.voterId,
    required this.voterType,
    this.flatNumber,
  });

  final String id;
  final String? pollId;
  final String? optionId;
  final String voterId;
  final String voterType;
  final String? flatNumber;

  factory PollVoteRow.fromJson(Map<String, dynamic> j) => PollVoteRow(
        id: '${j['id']}',
        pollId: _s(j['poll_id']),
        optionId: _s(j['option_id']),
        voterId: (j['voter_id'] ?? '').toString(),
        voterType: (j['voter_type'] ?? '').toString(),
        flatNumber: _s(j['flat_number']),
      );
}

/// Row of `poll_election_ballots`.
class BallotRow {
  const BallotRow({
    required this.id,
    required this.pollId,
    required this.voterId,
    this.flatId,
    this.flatNumber,
    this.voterPhone,
    this.choices,
    this.rankings,
    this.ballotMethod,
  });

  final String id;
  final String pollId;
  final String voterId;
  final String? flatId;
  final String? flatNumber;
  final String? voterPhone;
  final Object? choices;
  final Object? rankings;
  final String? ballotMethod;

  TallyBallot get tally => TallyBallot(
      choices: choices ?? const <String, dynamic>{}, rankings: rankings);

  factory BallotRow.fromJson(Map<String, dynamic> j) => BallotRow(
        id: '${j['id']}',
        pollId: '${j['poll_id']}',
        voterId: (j['voter_id'] ?? '').toString(),
        flatId: _s(j['flat_id']),
        flatNumber: _s(j['flat_number']),
        voterPhone: _s(j['voter_phone']),
        choices: j['choices'],
        rankings: j['rankings'],
        ballotMethod: _s(j['ballot_method']),
      );
}

/// Row of `poll_documents`.
class PollDocumentRow {
  const PollDocumentRow({
    required this.id,
    required this.pollId,
    required this.title,
    required this.docKind,
    required this.fileUrl,
    this.societyId,
    this.fileName,
    this.mimeType,
    this.sortOrder = 0,
    this.createdBy,
    this.createdAt,
  });

  final String id;
  final String pollId;
  final String? societyId;
  final String title;
  final String docKind;
  final String fileUrl;
  final String? fileName;
  final String? mimeType;
  final int sortOrder;
  final String? createdBy;
  final String? createdAt;

  factory PollDocumentRow.fromJson(Map<String, dynamic> j) => PollDocumentRow(
        id: '${j['id']}',
        pollId: '${j['poll_id']}',
        societyId: _s(j['society_id']),
        title: (j['title'] ?? '').toString(),
        docKind: (j['doc_kind'] ?? 'other').toString(),
        fileUrl: (j['file_url'] ?? '').toString(),
        fileName: _s(j['file_name']),
        mimeType: _s(j['mime_type']),
        sortOrder: _i(j['sort_order']),
        createdBy: _s(j['created_by']),
        createdAt: _s(j['created_at']),
      );
}

/// Voter name + flat resolved from `members` / `flats`.
class VoterProfile {
  const VoterProfile({required this.name, required this.flatNumber});

  final String name;
  final String flatNumber;
}

/// Everything the polls page loads (web `PollManager.loadAll`).
class PollsBundle {
  const PollsBundle({
    this.polls = const [],
    this.options = const [],
    this.votes = const [],
    this.ballots = const [],
    this.documents = const [],
    this.voterProfiles = const {},
  });

  final List<PollRow> polls;
  final List<PollOptionRow> options;
  final List<PollVoteRow> votes;
  final List<BallotRow> ballots;
  final List<PollDocumentRow> documents;
  final Map<String, VoterProfile> voterProfiles;

  List<PollRow> get standardPolls => polls.where((p) => !p.isElection).toList();
  List<PollRow> get electionPolls => polls.where((p) => p.isElection).toList();

  /// Web `activeElections`: active, or phase other than applied.
  List<PollRow> get activeElections => electionPolls
      .where((p) =>
          p.isActive ||
          (p.electionPhaseRaw != null &&
              p.electionPhaseRaw!.isNotEmpty &&
              p.electionPhaseRaw != 'applied'))
      .toList();

  List<PollOptionRow> optionsFor(String pollId) =>
      options.where((o) => o.pollId == pollId).toList();
  List<BallotRow> ballotsFor(String pollId) =>
      ballots.where((b) => b.pollId == pollId).toList();
  List<PollVoteRow> votesFor(String pollId) =>
      votes.where((v) => v.pollId == pollId).toList();
  List<PollDocumentRow> documentsFor(String pollId) =>
      documents.where((d) => d.pollId == pollId).toList();
}

/// Identity of the person using the polls page.
class PollViewer {
  const PollViewer({
    required this.isResident,
    this.adminName = 'Admin',
    this.voterId = '',
    this.voterPhone = '',
    this.memberId = '',
    this.memberName = '',
    this.flatNumber = '',
    this.flatId = '',
  });

  final bool isResident;
  final String adminName;

  /// `resident_users.id` (web `voterId`).
  final String voterId;
  final String voterPhone;

  /// Household `members.id` matched by phone (web `myMemberRecord.id`).
  final String memberId;
  final String memberName;
  final String flatNumber;
  final String flatId;
}
