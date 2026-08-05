import 'election_governance.dart';

class ElectedWinner {
  const ElectedWinner({
    required this.optionId,
    required this.name,
    required this.score,
    this.place,
    this.fromPost,
  });

  final String optionId;
  final String name;
  final int score;
  final int? place;
  final String? fromPost;

  Map<String, dynamic> toJson() => {
        'option_id': optionId,
        'name': name,
        'score': score,
        if (place != null) 'place': place,
        if (fromPost != null) 'from_post': fromPost,
      };
}

class ElectionResultsPayload {
  const ElectionResultsPayload({
    this.president,
    this.vicePresident,
    this.secretary,
    this.treasurer,
    this.committee = const [],
    this.formation = const {
      'selected_runner_up_ids': <String>[],
      'voluntary': <Map<String, dynamic>>[],
      'executive_proposed': <Map<String, dynamic>>[],
    },
    required this.talliedAt,
    this.ballotMode = 'combined',
  });

  final ElectedWinner? president;
  final ElectedWinner? vicePresident;
  final ElectedWinner? secretary;
  final ElectedWinner? treasurer;
  final List<ElectedWinner> committee;
  final Map<String, dynamic> formation;
  final String talliedAt;
  final String ballotMode;

  Map<String, dynamic> toJson() => {
        'president': president?.toJson(),
        'vice_president': vicePresident?.toJson(),
        'secretary': secretary?.toJson(),
        'treasurer': treasurer?.toJson(),
        'committee': committee.map((c) => c.toJson()).toList(),
        'formation': formation,
        'tallied_at': talliedAt,
        'ballot_mode': ballotMode,
      };
}

List<String> _asStringList(dynamic v) {
  if (v is List) return v.whereType<String>().where((s) => s.isNotEmpty).toList();
  if (v is String && v.isNotEmpty) return [v];
  return [];
}

Map<String, dynamic> _normalizeChoices(dynamic raw) {
  if (raw is! Map) return {};
  final c = Map<String, dynamic>.from(raw);
  return {
    'selected': _asStringList(c['selected']),
    'president': c['president'] is String ? c['president'] : null,
    'vice_president': c['vice_president'] is String ? c['vice_president'] : null,
    'secretary': c['secretary'] is String ? c['secretary'] : null,
    'treasurer': c['treasurer'] is String ? c['treasurer'] : null,
    'committee': _asStringList(c['committee']),
  };
}

bool _ballotHasChoices(Map<String, dynamic> choices) {
  if (_asStringList(choices['selected']).isNotEmpty) return true;
  for (final p in ['president', 'vice_president', 'secretary', 'treasurer']) {
    if (choices[p] is String && (choices[p] as String).isNotEmpty) return true;
  }
  return _asStringList(choices['committee']).isNotEmpty;
}

List<ElectedWinner> _rankedList(
  List<Map<String, dynamic>> postOpts,
  Map<String, int> scores,
  String fromPost,
) {
  final sorted = [...postOpts]
    ..sort((a, b) => (scores[b['id'] as String] ?? 0).compareTo(scores[a['id'] as String] ?? 0));
  return [
    for (var i = 0; i < sorted.length; i++)
      ElectedWinner(
        optionId: sorted[i]['id'] as String,
        name: sorted[i]['option_text'] as String? ?? '',
        score: scores[sorted[i]['id'] as String] ?? 0,
        place: i + 1,
        fromPost: fromPost,
      ),
  ];
}

/// Plurality / limited-vote tally from `choices` (not ranked/Borda).
ElectionResultsPayload tallyElection({
  required List<Map<String, dynamic>> options,
  required List<Map<String, dynamic>> ballots,
  required int committeeSeats,
  bool separateOfficeVotes = false,
  Map<String, int> winningVotes = const {},
  int runnerUpPlaces = 0,
}) {
  List<Map<String, dynamic>> byPost(String post) =>
      options.where((o) => o['election_post'] == post).toList();

  final normalized = ballots.map((b) => _normalizeChoices(b['choices'])).toList();
  final hasChoices = normalized.any(_ballotHasChoices);
  final separate = separateOfficeVotes;
  final seats = committeeSeats < 0 ? 0 : committeeSeats;

  Map<String, int> markScores(
    List<String> ids,
    bool Function(Map<String, dynamic> c, String id) mark,
  ) {
    final scores = {for (final id in ids) id: 0};
    for (final c in normalized) {
      for (final id in ids) {
        if (mark(c, id)) scores[id] = (scores[id] ?? 0) + 1;
      }
    }
    return scores;
  }

  ElectedWinner? winnerForOffice(String post) {
    final postOpts = byPost(post);
    if (postOpts.isEmpty) return null;
    final ids = postOpts.map((o) => o['id'] as String).toList();
    final scores = hasChoices
        ? (separate
            ? markScores(ids, (c, id) => c[post] == id)
            : markScores(ids, (c, id) => _asStringList(c['selected']).contains(id)))
        : <String, int>{for (final id in ids) id: 0};
    final ranked = _rankedList(postOpts, scores, post);
    return ranked.isEmpty ? null : ranked.first;
  }

  final committeeOpts = byPost('committee');
  final cIds = committeeOpts.map((o) => o['id'] as String).toList();
  final cScores = hasChoices
      ? (separate
          ? markScores(cIds, (c, id) => _asStringList(c['committee']).contains(id))
          : markScores(cIds, (c, id) => _asStringList(c['selected']).contains(id)))
      : <String, int>{for (final id in cIds) id: 0};
  final committeeSorted = _rankedList(committeeOpts, cScores, 'committee');
  final take = seats < committeeSorted.length ? seats : committeeSorted.length;

  return ElectionResultsPayload(
    president: winnerForOffice('president'),
    vicePresident: winnerForOffice('vice_president'),
    secretary: winnerForOffice('secretary'),
    treasurer: winnerForOffice('treasurer'),
    committee: committeeSorted.take(take).toList(),
    talliedAt: DateTime.now().toUtc().toIso8601String(),
    ballotMode: hasChoices ? (separate ? 'separate_office' : 'combined') : 'ranked_legacy',
  );
}

/// Legacy helper — new tallies never populate runners-up.
List<Map<String, dynamic>> listRunnersUpFromResults(dynamic results) {
  if (results is! Map) return [];
  final runners = results['runners_up'];
  if (runners is! Map) return [];
  final out = <Map<String, dynamic>>[];
  for (final post in threeExecutivePosts) {
    final list = runners[post];
    if (list is! List) continue;
    for (final r in list) {
      if (r is Map) {
        out.add({
          ...Map<String, dynamic>.from(r),
          'from_post': post,
        });
      }
    }
  }
  return out;
}

Map<String, dynamic> emptyFormationState() => {
      'selected_runner_up_ids': <String>[],
      'voluntary': <Map<String, dynamic>>[],
      'executive_proposed': <Map<String, dynamic>>[],
    };

Map<String, dynamic>? formationOf(dynamic results) {
  if (results is! Map) return null;
  final f = results['formation'];
  if (f is! Map) return emptyFormationState();
  return Map<String, dynamic>.from(f);
}

int countFormedCommitteeFromResults(dynamic results) {
  if (results is! Map) return 0;
  var n = 0;
  for (final key in ['president', 'vice_president', 'secretary', 'treasurer']) {
    if (results[key] is Map) n += 1;
  }
  final committee = results['committee'];
  if (committee is List) n += committee.length;
  final formation = formationOf(results);
  if (formation != null) {
    final vol = formation['voluntary'];
    final exec = formation['executive_proposed'];
    if (vol is List) n += vol.length;
    if (exec is List) n += exec.length;
  }
  return n;
}
