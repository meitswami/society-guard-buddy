import 'election_governance.dart';

String? validateElectionChoices(
  List<Map<String, dynamic>> options,
  Map<String, dynamic> choices, {
  required bool separateOfficeVotes,
  int committeeSeats = 3,
  int maxMarks = 7,
}) {
  final byId = {for (final o in options) o['id'] as String: o};
  List<Map<String, dynamic>> byPost(String post) =>
      options.where((o) => o['election_post'] == post).toList();

  if (separateOfficeVotes) {
    for (final post in allElectionPosts) {
      final postOpts = byPost(post);
      if (postOpts.isEmpty) continue;
      if (post == 'committee') {
        final raw = choices['committee'];
        final picks = raw is List
            ? raw.whereType<String>().toList()
            : raw is String
                ? [raw]
                : <String>[];
        if (picks.isEmpty) return 'Select Executive Member candidate(s)';
        if (picks.length > committeeSeats) {
          return 'Select at most $committeeSeats Executive Member(s)';
        }
        final seen = <String>{};
        for (final id in picks) {
          final opt = byId[id];
          if (opt == null || opt['election_post'] != 'committee') {
            return 'Invalid Executive Member selection';
          }
          if (!seen.add(id)) return 'Duplicate Executive Member selection';
        }
        continue;
      }
      final pick = choices[post];
      if (pick is! String || pick.isEmpty) {
        return 'Select one candidate for ${postDisplay[post] ?? post}';
      }
      final opt = byId[pick];
      if (opt == null || opt['election_post'] != post) {
        return 'Invalid selection for ${postDisplay[post] ?? post}';
      }
    }
    return null;
  }

  final raw = choices['selected'];
  final selected = raw is List ? raw.whereType<String>().toList() : <String>[];
  if (selected.isEmpty) return 'Select at least one nominee on your ballot';
  if (selected.length > maxMarks) {
    return 'Select at most $maxMarks nominees (one vote per member)';
  }
  final seen = <String>{};
  for (final id in selected) {
    if (!byId.containsKey(id)) return 'Invalid nominee on ballot';
    if (!seen.add(id)) return 'Duplicate selection on ballot';
  }
  return null;
}

/// @Deprecated Ranked ballots removed — use [validateElectionChoices].
String? validateElectionRankings(
  List<Map<String, dynamic>> options,
  Map<String, Map<String, int>> rankings,
) {
  if (options.isEmpty) return 'No candidates';
  return 'Ranked ballots are no longer used. Refresh and cast a simple ballot.';
}
