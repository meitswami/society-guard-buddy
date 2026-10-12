/// Port of web `src/lib/electionTally.ts` (plurality / limited vote — never ranked)
/// plus `countFormedCommittee` from `src/lib/electionApply.ts`.
library;

import 'election_governance.dart';

/// Minimal option shape used by validation / tally (`poll_options` row).
class TallyOption {
  const TallyOption({required this.id, required this.optionText, this.electionPost});

  final String id;
  final String optionText;
  final String? electionPost;

  factory TallyOption.fromJson(Map<String, dynamic> j) => TallyOption(
        id: '${j['id']}',
        optionText: (j['option_text'] ?? '').toString(),
        electionPost: j['election_post'] as String?,
      );
}

/// One ballot row (`poll_election_ballots.choices` / legacy `rankings`).
class TallyBallot {
  const TallyBallot({this.choices, this.rankings});

  final Object? choices;

  /// @deprecated Legacy ranked/Borda ballots only.
  final Object? rankings;

  factory TallyBallot.fromJson(Map<String, dynamic> j) => TallyBallot(choices: j['choices'], rankings: j['rankings']);
}

/// Ballot validation error (English text identical to the web toast + Hindi).
class BallotError {
  const BallotError(this.en, this.hi);

  final String en;
  final String hi;

  String text(bool hindi) => hindi ? hi : en;

  @override
  String toString() => en;
}

List<String> asStringList(Object? v) {
  if (v is List) return v.whereType<String>().where((s) => s.isNotEmpty).toList();
  if (v is String && v.isNotEmpty) return [v];
  return const [];
}

/// Normalised ballot choices: `selected`, office keys and `committee` (list).
class NormalizedChoices {
  const NormalizedChoices({
    this.selected = const [],
    this.president,
    this.vicePresident,
    this.secretary,
    this.treasurer,
    this.committee = const [],
  });

  final List<String> selected;
  final String? president;
  final String? vicePresident;
  final String? secretary;
  final String? treasurer;
  final List<String> committee;

  String? office(String post) => switch (post) {
        ElectionPosts.president => president,
        ElectionPosts.vicePresident => vicePresident,
        ElectionPosts.secretary => secretary,
        ElectionPosts.treasurer => treasurer,
        _ => null,
      };

  /// True when any choice is present (web `Object.keys(normalizeChoices).some(...)`).
  bool get hasAny =>
      selected.isNotEmpty ||
      committee.isNotEmpty ||
      [president, vicePresident, secretary, treasurer].any((v) => v != null && v.isNotEmpty);
}

NormalizedChoices normalizeChoices(Object? raw) {
  if (raw is! Map) return const NormalizedChoices();
  String? str(Object? v) => v is String ? v : null;
  return NormalizedChoices(
    selected: asStringList(raw['selected']),
    president: str(raw[ElectionPosts.president]),
    vicePresident: str(raw[ElectionPosts.vicePresident]),
    secretary: str(raw[ElectionPosts.secretary]),
    treasurer: str(raw[ElectionPosts.treasurer]),
    committee: asStringList(raw[ElectionPosts.committee]),
  );
}

List<String> _postsPresent(List<TallyOption> options) {
  final have = options.map((o) => o.electionPost).whereType<String>().toSet();
  return ElectionPosts.all.where(have.contains).toList();
}

String _postWords(String post) => post.replaceFirst('_', ' ');

/// Validate one member's ballot choices (web `validateElectionChoices`).
BallotError? validateElectionChoices(
  List<TallyOption> options,
  Object? choicesRaw,
  bool separateOfficeVotes, {
  int committeeSeats = 3,
  int maxMarks = 7,
}) {
  final choices = normalizeChoices(choicesRaw);
  final byId = {for (final o in options) o.id: o};
  final openPosts = _postsPresent(options);

  if (separateOfficeVotes) {
    for (final post in openPosts) {
      if (post == ElectionPosts.committee) {
        final picks = choices.committee;
        if (picks.isEmpty && options.any((o) => o.electionPost == ElectionPosts.committee)) {
          return const BallotError('Select Executive Member candidate(s)', 'कार्यकारिणी सदस्य अभ्यर्थी चुनें');
        }
        if (picks.length > committeeSeats) {
          return BallotError(
            'Select at most $committeeSeats Executive Member(s)',
            'अधिकतम $committeeSeats कार्यकारिणी सदस्य चुनें',
          );
        }
        final seen = <String>{};
        for (final id in picks) {
          final opt = byId[id];
          if (opt == null || opt.electionPost != ElectionPosts.committee) {
            return const BallotError('Invalid Executive Member selection', 'कार्यकारिणी सदस्य का अमान्य चयन');
          }
          if (!seen.add(id)) {
            return const BallotError('Duplicate Executive Member selection', 'कार्यकारिणी सदस्य का दोहरा चयन');
          }
        }
        continue;
      }
      final pick = choices.office(post);
      if (pick == null || pick.isEmpty) {
        return BallotError(
          'Select one candidate for ${_postWords(post)}',
          '${postDisplay(post, hi: true)} हेतु एक अभ्यर्थी चुनें',
        );
      }
      final opt = byId[pick];
      if (opt == null || opt.electionPost != post) {
        return BallotError(
          'Invalid selection for ${_postWords(post)}',
          '${postDisplay(post, hi: true)} हेतु अमान्य चयन',
        );
      }
    }
    return null;
  }

  final selected = choices.selected;
  if (selected.isEmpty) {
    return const BallotError('Select at least one nominee on your ballot', 'अपने मतपत्र पर कम-से-कम एक नामांकित चुनें');
  }
  if (selected.length > maxMarks) {
    return BallotError(
      'Select at most $maxMarks nominees (one vote per member)',
      'अधिकतम $maxMarks नामांकित चुनें (प्रति सदस्य एक मत)',
    );
  }
  final seen = <String>{};
  for (final id in selected) {
    if (!byId.containsKey(id)) return const BallotError('Invalid nominee on ballot', 'मतपत्र पर अमान्य नामांकित');
    if (!seen.add(id)) return const BallotError('Duplicate selection on ballot', 'मतपत्र पर दोहरा चयन');
  }
  return null;
}

/// @deprecated Ranked ballots are no longer used (web `validateElectionRankings`).
BallotError? validateElectionRankings(List<TallyOption> options, Object? rankings) {
  if (options.isEmpty) return const BallotError('No candidates', 'कोई अभ्यर्थी नहीं');
  return const BallotError(
    'Ranked ballots are no longer used. Refresh and cast a simple ballot.',
    'क्रमांकित मतपत्र अब उपयोग नहीं होते। रीफ़्रेश करें और सामान्य मतपत्र डालें।',
  );
}

class ElectedWinner {
  const ElectedWinner({required this.optionId, required this.name, required this.score, this.place, this.fromPost});

  final String optionId;
  final String name;
  final int score;
  final int? place;
  final String? fromPost;

  static ElectedWinner? fromJson(Object? raw) {
    if (raw is! Map || raw['option_id'] == null) return null;
    final s = raw['score'];
    final p = raw['place'];
    return ElectedWinner(
      optionId: '${raw['option_id']}',
      name: (raw['name'] ?? '').toString(),
      score: s is num ? s.round() : int.tryParse('$s') ?? 0,
      place: p is num ? p.round() : null,
      fromPost: raw['from_post'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'option_id': optionId,
        'name': name,
        'score': score,
        if (place != null) 'place': place,
        if (fromPost != null) 'from_post': fromPost,
      };
}

/// Vacancy-fill entry (`formation.voluntary` / `formation.executive_proposed`).
class FormationMember {
  const FormationMember({
    required this.key,
    required this.name,
    required this.source,
    this.flatNumber,
    this.flatId,
    this.memberId,
    this.optionId,
    this.fromPost,
    this.place,
  });

  final String key;
  final String name;
  final String? flatNumber;
  final String? flatId;
  final String? memberId;
  final String? optionId;
  final String? fromPost;
  final int? place;

  /// `voluntary` | `executive_proposed` | `runner_up` (legacy).
  final String source;

  static FormationMember? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final p = raw['place'];
    return FormationMember(
      key: '${raw['key'] ?? ''}',
      name: (raw['name'] ?? '').toString(),
      flatNumber: raw['flat_number'] as String?,
      flatId: raw['flat_id'] as String?,
      memberId: raw['member_id'] as String?,
      optionId: raw['option_id'] as String?,
      fromPost: raw['from_post'] as String?,
      place: p is num ? p.round() : null,
      source: (raw['source'] ?? 'voluntary').toString(),
    );
  }

  /// Same shape the web writes (`voluntary` carries flat/member ids, `executive_proposed` only the flat).
  Map<String, dynamic> toJson() => {
        'key': key,
        'name': name,
        'flat_number': flatNumber,
        if (flatId != null || source == 'voluntary') 'flat_id': flatId,
        if (memberId != null || source == 'voluntary') 'member_id': memberId,
        if (optionId != null) 'option_id': optionId,
        if (fromPost != null) 'from_post': fromPost,
        if (place != null) 'place': place,
        'source': source,
      };
}

/// `results.formation ?? emptyFormationState()` as a mutable JSON map.
Map<String, dynamic> formationRawOf(Object? results) {
  final f = results is Map ? results['formation'] : null;
  if (f is Map) return Map<String, dynamic>.from(f);
  return emptyFormationJson();
}

/// Raw entries of `formation.voluntary` / `formation.executive_proposed`.
List<Map<String, dynamic>> formationEntries(Map<String, dynamic> formation, String key) {
  final v = formation[key];
  if (v is! List) return [];
  return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

/// `{...results, formation: {...formation, [key]: entries}}`.
Map<String, dynamic> resultsWithFormationEntries(
  Map<String, dynamic> results,
  String key,
  List<Map<String, dynamic>> entries,
) {
  final formation = formationRawOf(results);
  return {
    ...results,
    'formation': {...formation, key: entries},
  };
}

class CommitteeFormationState {
  const CommitteeFormationState({
    this.selectedRunnerUpIds = const [],
    this.voluntary = const [],
    this.executiveProposed = const [],
  });

  /// @deprecated Not used for new elections (bye-laws forbid auto-seating runners-up).
  final List<String> selectedRunnerUpIds;
  final List<FormationMember> voluntary;
  final List<FormationMember> executiveProposed;

  static CommitteeFormationState fromJson(Object? raw) {
    if (raw is! Map) return const CommitteeFormationState();
    List<FormationMember> list(Object? v) =>
        v is List ? v.map(FormationMember.fromJson).whereType<FormationMember>().toList() : const [];
    return CommitteeFormationState(
      selectedRunnerUpIds: asStringList(raw['selected_runner_up_ids']),
      voluntary: list(raw['voluntary']),
      executiveProposed: list(raw['executive_proposed']),
    );
  }

  CommitteeFormationState copyWith({List<FormationMember>? voluntary, List<FormationMember>? executiveProposed}) =>
      CommitteeFormationState(
        selectedRunnerUpIds: selectedRunnerUpIds,
        voluntary: voluntary ?? this.voluntary,
        executiveProposed: executiveProposed ?? this.executiveProposed,
      );

  Map<String, dynamic> toJson() => {
        'selected_runner_up_ids': selectedRunnerUpIds,
        'voluntary': voluntary.map((v) => v.toJson()).toList(),
        'executive_proposed': executiveProposed.map((e) => e.toJson()).toList(),
      };
}

Map<String, dynamic> emptyFormationJson() => const CommitteeFormationState().toJson();

/// Typed read view over `polls.election_results` (the raw map is kept for persistence).
class ElectionResults {
  ElectionResults._(this.raw);

  final Map<String, dynamic> raw;

  /// Web `isResultsPayload`: object with `president` and `committee` keys.
  static bool isPayload(Object? x) => x is Map && x.containsKey('president') && x.containsKey('committee');

  static ElectionResults? tryParse(Object? raw) {
    if (raw is! Map) return null;
    return ElectionResults._(Map<String, dynamic>.from(raw));
  }

  ElectedWinner? office(String post) => ElectedWinner.fromJson(raw[post]);

  List<ElectedWinner> get committee {
    final c = raw['committee'];
    if (c is! List) return const [];
    return c.map(ElectedWinner.fromJson).whereType<ElectedWinner>().toList();
  }

  CommitteeFormationState get formation => CommitteeFormationState.fromJson(raw['formation']);

  String? get ballotMode => raw['ballot_mode'] as String?;

  String? get talliedAt => raw['tallied_at'] as String?;

  /// `{...results, formation: next}` — keeps every other key untouched.
  Map<String, dynamic> withFormation(CommitteeFormationState next) => {...raw, 'formation': next.toJson()};

  /// Legacy helper — returns [] for new tallies (runners_up never written).
  List<ElectedWinner> listRunnersUp() {
    final out = <ElectedWinner>[];
    final ru = raw['runners_up'];
    if (ru is! Map) return out;
    for (final post in ElectionPosts.offices) {
      final list = ru[post];
      if (list is! List) continue;
      for (final r in list) {
        final w = ElectedWinner.fromJson(r);
        if (w != null) {
          out.add(ElectedWinner(optionId: w.optionId, name: w.name, score: w.score, place: w.place, fromPost: post));
        }
      }
    }
    return out;
  }
}

/// Number of seats filled on the formed committee (web `countFormedCommittee`).
int countFormedCommittee(Object? results) {
  if (results is! Map) return 0;
  var n = 0;
  for (final post in ElectionPosts.offices) {
    final w = results[post];
    if (w is Map && w.containsKey('option_id')) n += 1;
  }
  final committee = results['committee'];
  if (committee is List) n += committee.length;
  final formation = results['formation'];
  if (formation is Map) {
    final v = formation['voluntary'];
    final e = formation['executive_proposed'];
    if (v is List) n += v.length;
    if (e is List) n += e.length;
  }
  return n;
}

Map<String, int> _scoreMap(
  List<String> optionIds,
  List<NormalizedChoices> ballots,
  bool Function(NormalizedChoices c, String optionId) markFor,
) {
  final scores = {for (final id in optionIds) id: 0};
  for (final c in ballots) {
    for (final id in optionIds) {
      if (markFor(c, id)) scores[id] = (scores[id] ?? 0) + 1;
    }
  }
  return scores;
}

int _rankValue(Object? v) {
  if (v is num) return v.toInt() == v ? v.toInt() : -1;
  return int.tryParse('$v') ?? -1;
}

/// Legacy ranked → one vote for rank-1 only (migration path).
Map<String, int> _legacyRankOneScores(String post, List<String> optionIds, List<TallyBallot> ballots) {
  final scores = {for (final id in optionIds) id: 0};
  for (final b in ballots) {
    if (b.choices is Map && normalizeChoices(b.choices).hasAny) continue;
    final rankings = b.rankings;
    final rmap = rankings is Map ? rankings[post] : null;
    if (rmap is! Map) continue;
    for (final id in optionIds) {
      if (_rankValue(rmap[id]) == 1) scores[id] = (scores[id] ?? 0) + 1;
    }
  }
  return scores;
}

/// Stable sort by score (descending) — JS `Array.prototype.sort` is stable.
List<ElectedWinner> _rankedList(List<TallyOption> postOpts, Map<String, int> scores, String fromPost) {
  final indexed = [for (var i = 0; i < postOpts.length; i++) (i, postOpts[i])];
  indexed.sort((a, b) {
    final d = (scores[b.$2.id] ?? 0) - (scores[a.$2.id] ?? 0);
    return d != 0 ? d : a.$1.compareTo(b.$1);
  });
  return [
    for (var i = 0; i < indexed.length; i++)
      ElectedWinner(
        optionId: indexed[i].$2.id,
        name: indexed[i].$2.optionText,
        score: scores[indexed[i].$2.id] ?? 0,
        place: i + 1,
        fromPost: fromPost,
      ),
  ];
}

/// Plurality / limited-vote tally from `choices` (web `tallyElection`).
/// Does not auto-seat 2nd/3rd place and never uses Borda ranking.
/// Returns the JSON payload stored in `polls.election_results`.
Map<String, dynamic> tallyElection(
  List<TallyOption> options,
  List<TallyBallot> ballots, {
  bool separateOfficeVotes = false,
  int committeeSeats = 3,
  DateTime? now,
}) {
  final seats = committeeSeats < 0 ? 0 : committeeSeats;
  List<TallyOption> byPost(String post) => options.where((o) => o.electionPost == post).toList();
  final normalized = ballots.map((b) => normalizeChoices(b.choices)).toList();

  final hasAnyChoices = normalized.any(
    (c) => c.selected.isNotEmpty || ElectionPosts.offices.any((p) => (c.office(p) ?? '').isNotEmpty) || c.committee.isNotEmpty,
  );

  final ballotMode = hasAnyChoices ? (separateOfficeVotes ? 'separate_office' : 'combined') : 'ranked_legacy';
  final winners = <String, ElectedWinner?>{};
  final talliedAt = jsIsoString(now ?? DateTime.now());

  Map<String, dynamic> payload(List<ElectedWinner> committee, String mode) => {
        ElectionPosts.president: winners[ElectionPosts.president]?.toJson(),
        ElectionPosts.vicePresident: winners[ElectionPosts.vicePresident]?.toJson(),
        ElectionPosts.secretary: winners[ElectionPosts.secretary]?.toJson(),
        ElectionPosts.treasurer: winners[ElectionPosts.treasurer]?.toJson(),
        ElectionPosts.committee: committee.map((c) => c.toJson()).toList(),
        'formation': emptyFormationJson(),
        'tallied_at': talliedAt,
        'ballot_mode': mode,
      };

  if (separateOfficeVotes || ballotMode == 'ranked_legacy') {
    for (final post in ElectionPosts.offices) {
      final postOpts = byPost(post);
      if (postOpts.isEmpty) {
        winners[post] = null;
        continue;
      }
      final ids = postOpts.map((o) => o.id).toList();
      final scores = hasAnyChoices
          ? _scoreMap(ids, normalized, (c, id) => c.office(post) == id)
          : _legacyRankOneScores(post, ids, ballots);
      final ranked = _rankedList(postOpts, scores, post);
      winners[post] = ranked.isEmpty ? null : ranked.first;
    }
    final committeeOpts = byPost(ElectionPosts.committee);
    final cIds = committeeOpts.map((o) => o.id).toList();
    final cScores = hasAnyChoices
        ? _scoreMap(cIds, normalized, (c, id) => c.committee.contains(id))
        : _legacyRankOneScores(ElectionPosts.committee, cIds, ballots);
    final sorted = _rankedList(committeeOpts, cScores, ElectionPosts.committee);
    final take = seats < sorted.length ? seats : sorted.length;
    return payload(sorted.take(take).toList(), ballotMode);
  }

  // Combined: each marked nominee gets one mark; seat by nominated post.
  final allIds = options.map((o) => o.id).toList();
  final scores = _scoreMap(allIds, normalized, (c, id) => c.selected.contains(id));
  for (final post in ElectionPosts.offices) {
    final postOpts = byPost(post);
    if (postOpts.isEmpty) {
      winners[post] = null;
      continue;
    }
    final ranked = _rankedList(postOpts, scores, post);
    winners[post] = ranked.isEmpty ? null : ranked.first;
  }
  final committeeOpts = byPost(ElectionPosts.committee);
  final sorted = _rankedList(committeeOpts, scores, ElectionPosts.committee);
  final take = seats < sorted.length ? seats : sorted.length;
  return payload(sorted.take(take).toList(), 'combined');
}
