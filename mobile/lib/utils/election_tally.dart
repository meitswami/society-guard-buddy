typedef ElectionRankings = Map<String, Map<String, int>>;

class ElectedWinner {
  const ElectedWinner({
    required this.optionId,
    required this.name,
    required this.score,
  });

  final String optionId;
  final String name;
  final int score;

  Map<String, dynamic> toJson() => {
        'option_id': optionId,
        'name': name,
        'score': score,
      };
}

class ElectionResultsPayload {
  const ElectionResultsPayload({
    this.president,
    this.vicePresident,
    this.secretary,
    this.treasurer,
    this.committee = const [],
    required this.talliedAt,
  });

  final ElectedWinner? president;
  final ElectedWinner? vicePresident;
  final ElectedWinner? secretary;
  final ElectedWinner? treasurer;
  final List<ElectedWinner> committee;
  final String talliedAt;

  Map<String, dynamic> toJson() => {
        'president': president?.toJson(),
        'vice_president': vicePresident?.toJson(),
        'secretary': secretary?.toJson(),
        'treasurer': treasurer?.toJson(),
        'committee': committee.map((c) => c.toJson()).toList(),
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

  ElectedWinner? pickWinner(String post) {
    final postOpts = byPost(post);
    if (postOpts.isEmpty) return null;
    final scores = scoreMap(post);
    Map<String, dynamic>? best;
    var bestScore = -1;
    for (final o in postOpts) {
      final s = scores[o['id'] as String] ?? 0;
      if (s > bestScore) {
        bestScore = s;
        best = o;
      }
    }
    if (best == null) return null;
    return ElectedWinner(
      optionId: best['id'] as String,
      name: best['option_text'] as String,
      score: bestScore,
    );
  }

  final committeeOpts = byPost('committee');
  final cScores = scoreMap('committee');
  final sorted = [...committeeOpts]
    ..sort((a, b) =>
        (cScores[b['id'] as String] ?? 0).compareTo(cScores[a['id'] as String] ?? 0));
  final seats = committeeSeats.clamp(1, sorted.length);
  final committee = sorted.take(seats).map((o) {
    final id = o['id'] as String;
    return ElectedWinner(
      optionId: id,
      name: o['option_text'] as String,
      score: cScores[id] ?? 0,
    );
  }).toList();

  return ElectionResultsPayload(
    president: pickWinner('president'),
    vicePresident: pickWinner('vice_president'),
    secretary: pickWinner('secretary'),
    treasurer: pickWinner('treasurer'),
    committee: committee,
    talliedAt: DateTime.now().toIso8601String(),
  );
}
