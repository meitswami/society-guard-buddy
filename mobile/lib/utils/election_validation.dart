import 'election_governance.dart';

String? validateElectionRankings(
  List<Map<String, dynamic>> options,
  Map<String, Map<String, int>> rankings,
) {
  List<Map<String, dynamic>> byPost(String post) =>
      options.where((o) => o['election_post'] == post).toList();

  for (final post in allElectionPosts) {
    final postOpts = byPost(post);
    if (postOpts.isEmpty) continue;
    final m = postOpts.length;
    final rmap = rankings[post] ?? {};
    final usedRanks = <int>{};

    for (final o in postOpts) {
      final id = o['id'] as String;
      final r = rmap[id];
      if (r == null) return 'Assign a rank for every $post candidate';
      if (r < 1 || r > m) return 'Invalid rank for $post';
      if (usedRanks.contains(r)) return 'Duplicate rank $r for $post';
      usedRanks.add(r);
    }
    if (usedRanks.length != m) return 'Complete all rankings for $post';
  }
  return null;
}
