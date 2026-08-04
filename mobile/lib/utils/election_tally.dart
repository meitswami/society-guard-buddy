import 'election_governance.dart';

typedef ElectionRankings = Map<String, Map<String, int>>;

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

class VacantPost {
  const VacantPost({
    required this.reason,
    required this.topScore,
    required this.required,
  });

  final String reason;
  final int topScore;
  final int required;

  Map<String, dynamic> toJson() => {
        'reason': reason,
        'top_score': topScore,
        'required': required,
      };
}

class ElectionResultsPayload {
  const ElectionResultsPayload({
    this.president,
    this.vicePresident,
    this.secretary,
    this.treasurer,
    this.committee = const [],
    this.runnersUp = const {},
    this.vacant = const {},
    this.formation = const {
      'selected_runner_up_ids': <String>[],
      'voluntary': <Map<String, dynamic>>[],
      'executive_proposed': <Map<String, dynamic>>[],
    },
    required this.talliedAt,
  });

  final ElectedWinner? president;
  final ElectedWinner? vicePresident;
  final ElectedWinner? secretary;
  final ElectedWinner? treasurer;
  final List<ElectedWinner> committee;
  final Map<String, List<ElectedWinner>> runnersUp;
  final Map<String, VacantPost> vacant;
  final Map<String, dynamic> formation;
  final String talliedAt;

  Map<String, dynamic> toJson() => {
        'president': president?.toJson(),
        'vice_president': vicePresident?.toJson(),
        'secretary': secretary?.toJson(),
        'treasurer': treasurer?.toJson(),
        'committee': committee.map((c) => c.toJson()).toList(),
        if (runnersUp.isNotEmpty)
          'runners_up': runnersUp.map(
            (k, v) => MapEntry(k, v.map((e) => e.toJson()).toList()),
          ),
        if (vacant.isNotEmpty) 'vacant': vacant.map((k, v) => MapEntry(k, v.toJson())),
        'formation': formation,
        'tallied_at': talliedAt,
      };
}

int _pointsForRank(int rank, int m) {
  if (m <= 0 || rank < 1 || rank > m) return 0;
  return m - rank + 1;
}

ElectionResultsPayload tallyElection({
  required List<Map<String, dynamic>> options,
  required List<Map<String, dynamic>> ballots,
  required int committeeSeats,
  Map<String, int> winningVotes = const {},
  int runnerUpPlaces = 2,
}) {
  List<Map<String, dynamic>> byPost(String post) =>
      options.where((o) => o['election_post'] == post).toList();

  Map<String, int> scoreMap(String post) {
    final postOpts = byPost(post);
    final m = postOpts.length;
    final scores = <String, int>{for (final o in postOpts) o['id'] as String: 0};
    if (m == 0) return scores;

    for (final b in ballots) {
      final rankings = b['rankings'];
      if (rankings is! Map) continue;
      final rmap = Map<String, dynamic>.from(rankings);
      final postR = rmap[post];
      if (postR is! Map) continue;
      final postRankings = Map<String, dynamic>.from(postR);
      for (final o in postOpts) {
        final id = o['id'] as String;
        final rank = postRankings[id];
        if (rank is num) {
          scores[id] = (scores[id] ?? 0) + _pointsForRank(rank.toInt(), m);
        }
      }
    }
    return scores;
  }

  final vacant = <String, VacantPost>{};

  List<ElectedWinner> rankedForPost(String post) {
    final postOpts = byPost(post);
    if (postOpts.isEmpty) return [];
    final scores = scoreMap(post);
    final ranked = [...postOpts]
      ..sort((a, b) =>
          (scores[b['id'] as String] ?? 0).compareTo(scores[a['id'] as String] ?? 0));
    return [
      for (var i = 0; i < ranked.length; i++)
        ElectedWinner(
          optionId: ranked[i]['id'] as String,
          name: ranked[i]['option_text'] as String,
          score: scores[ranked[i]['id'] as String] ?? 0,
          place: i + 1,
          fromPost: post,
        ),
    ];
  }

  ElectedWinner? resolveWinner(String post, List<ElectedWinner> ranked) {
    if (ranked.isEmpty) return null;
    final best = ranked.first;
    final required = winningVotes[post] ?? 0;
    if (required > 0 && best.score < required) {
      vacant[post] = VacantPost(
        reason: 'Top score ${best.score} below required $required',
        topScore: best.score,
        required: required,
      );
      return null;
    }
    return best;
  }

  final winners = <String, ElectedWinner?>{};
  final runnersUp = <String, List<ElectedWinner>>{};
  for (final post in ['president', 'secretary', 'treasurer', 'vice_president']) {
    final ranked = rankedForPost(post);
    final winner = resolveWinner(post, ranked);
    winners[post] = winner;
    if (['president', 'secretary', 'treasurer'].contains(post)) {
      final unelected = ranked.where((r) => winner == null || r.optionId != winner.optionId).toList();
      final slice = unelected.take(runnerUpPlaces < 0 ? 0 : runnerUpPlaces).toList();
      if (slice.isNotEmpty) runnersUp[post] = slice;
    }
  }

  final committeeOpts = byPost('committee');
  final cScores = scoreMap('committee');
  final sorted = [...committeeOpts]
    ..sort((a, b) =>
        (cScores[b['id'] as String] ?? 0).compareTo(cScores[a['id'] as String] ?? 0));
  final seats = sorted.isEmpty ? 0 : committeeSeats.clamp(0, sorted.length);
  final committee = [
    for (var i = 0; i < seats; i++)
      ElectedWinner(
        optionId: sorted[i]['id'] as String,
        name: sorted[i]['option_text'] as String,
        score: cScores[sorted[i]['id'] as String] ?? 0,
        place: i + 1,
        fromPost: 'committee',
      ),
  ];

  return ElectionResultsPayload(
    president: winners['president'],
    vicePresident: winners['vice_president'],
    secretary: winners['secretary'],
    treasurer: winners['treasurer'],
    committee: committee,
    runnersUp: runnersUp,
    vacant: vacant,
    talliedAt: DateTime.now().toIso8601String(),
  );
}

Map<String, dynamic> emptyFormationState() => {
      'selected_runner_up_ids': <String>[],
      'voluntary': <Map<String, dynamic>>[],
      'executive_proposed': <Map<String, dynamic>>[],
    };

/// Parse results JSON from polls.election_results (snake_case keys).
Map<String, dynamic>? formationOf(dynamic results) {
  if (results is! Map) return null;
  final f = results['formation'];
  if (f is Map) return Map<String, dynamic>.from(f);
  return emptyFormationState();
}

List<Map<String, dynamic>> listRunnersUpFromResults(dynamic results) {
  if (results is! Map) return [];
  final runners = results['runners_up'];
  if (runners is! Map) return [];
  final out = <Map<String, dynamic>>[];
  for (final post in threeExecutivePosts) {
    final list = runners[post];
    if (list is! List) continue;
    for (final item in list) {
      if (item is! Map) continue;
      final row = Map<String, dynamic>.from(item);
      row['from_post'] = post;
      out.add(row);
    }
  }
  return out;
}

int countFormedCommitteeFromResults(dynamic results) {
  if (results is! Map) return 0;
  var n = 0;
  for (final post in ['president', 'vice_president', 'secretary', 'treasurer']) {
    if (results[post] is Map) n += 1;
  }
  final committee = results['committee'];
  if (committee is List) n += committee.length;
  final formation = formationOf(results);
  if (formation != null) {
    final selected = formation['selected_runner_up_ids'];
    if (selected is List) n += selected.length;
    final voluntary = formation['voluntary'];
    if (voluntary is List) n += voluntary.length;
    final exec = formation['executive_proposed'];
    if (exec is List) n += exec.length;
  }
  return n;
}
