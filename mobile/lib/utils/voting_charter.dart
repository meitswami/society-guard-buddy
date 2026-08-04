import 'package:url_launcher/url_launcher.dart';

/// Member-facing election & committee formation charter (English for WhatsApp readability).
class VotingCharterStep {
  const VotingCharterStep({required this.title, required this.detail});
  final String title;
  final String detail;
}

class VotingCharterSection {
  const VotingCharterSection({required this.heading, required this.points});
  final String heading;
  final List<String> points;
}

const votingCharterTitle = 'Voting & Committee Formation Charter';

const votingCharterShareMessage =
    'Society Voting & Committee Formation Charter — please read the step-by-step program for the executive election and Managing Committee formation.';

const electionProgramIntro =
    'Follow these steps to understand the executive election poll and how the Managing Committee of the society is formed.';

const electionProgramSteps = <VotingCharterStep>[
  VotingCharterStep(
    title: 'Know the three executive posts',
    detail:
        'The election poll is for President, Secretary and Treasurer only. Ranked voting (Borda) decides the winner of each post.',
  ),
  VotingCharterStep(
    title: 'Nominate during the nomination window',
    detail:
        'When nominations are open, eligible members may self-nominate for any of the three posts with a short statement.',
  ),
  VotingCharterStep(
    title: 'Cast your ranked ballot',
    detail:
        'In the voting window, rank every candidate in each post (1 = highest preference). One vote per person; up to two ballots per flat when both spouses vote.',
  ),
  VotingCharterStep(
    title: 'Winners take the three posts',
    detail:
        'After tally, the highest-scoring candidate for each post is elected (if they meet any minimum winning score set by the admin).',
  ),
  VotingCharterStep(
    title: '2nd & 3rd place may join the Committee',
    detail:
        'Candidates who remain unelected in 2nd or 3rd place for President, Secretary or Treasurer may be nominated as other executive members of the Managing Committee.',
  ),
  VotingCharterStep(
    title: 'Committee size: at least 7, target 15',
    detail:
        'The Managing Committee is formed with seven or more members. The Society proposes a committee of minimum fifteen members.',
  ),
  VotingCharterStep(
    title: 'Fill remaining seats',
    detail:
        'If the committee does not reach 15 through winners and 2nd/3rd place nominations, interested members may join voluntarily. If seats still remain, the executive committee proposes names.',
  ),
  VotingCharterStep(
    title: 'Publish the full roster',
    detail:
        'When formation is complete (minimum 7), the admin publishes the roster. Members then see the full committee in the Committee module.',
  ),
];

const votingCharterSections = <VotingCharterSection>[
  VotingCharterSection(
    heading: 'Eligibility',
    points: [
      'Every registered owner and their spouse may cast one ranked ballot each.',
      'One vote per person — even if you own more than one flat, you vote only once (matched by login / phone).',
      'Up to two ballots may come from the same flat when both spouses vote separately.',
    ],
  ),
  VotingCharterSection(
    heading: 'Nomination',
    points: [
      'When the admin opens the nomination window, members may propose themselves for three executive posts: President, Secretary, or Treasurer.',
      'Each nominee must write a short statement explaining why they should be chosen or given preference.',
      'Self-nomination is only allowed inside the admin-set nomination open and close dates.',
    ],
  ),
  VotingCharterSection(
    heading: 'Voting method',
    points: [
      'Rank every candidate in each post — 1 = highest preference (maximum rating).',
      'You must rank all candidates in a post; duplicate ranks are not allowed.',
      'Scores use Borda priority points: top rank gets the highest score; the candidate with the highest total is elected if they meet the admin’s minimum winning score for that post.',
      'You may include yourself in your rankings.',
      'Voting is only allowed inside the admin-set voting open and close dates.',
    ],
  ),
  VotingCharterSection(
    heading: 'Managing Committee formation',
    points: [
      'After the three executive winners are declared, candidates placed 2nd or 3rd (unelected) for President, Secretary or Treasurer may be nominated into the Managing Committee as other executive members.',
      'The committee is formed with seven or more members. The Society proposes a minimum of fifteen members.',
      'If 15 seats are not filled by winners plus 2nd/3rd place nominations, members who volunteer may be included.',
      'If seats still remain after voluntary interest, the executive committee proposes names of members to complete the roster.',
      'The full committee appears for residents only after the admin publishes the formed roster.',
    ],
  ),
  VotingCharterSection(
    heading: 'Documents & results',
    points: [
      'Admin may attach circulars, letters, or other society/personal documents to the election; members can open them from the poll.',
      'After the voting window closes, the admin tallies results. Winners and 2nd/3rd place candidates are visible in the admin portal first.',
      'Elected and formed committee names appear in the residents’ Committee module only after the admin publishes them to the roster.',
      'This charter can be shared with all members (for example via WhatsApp).',
    ],
  ),
];

String buildVotingCharterPlainText({String? societyName}) {
  final buf = StringBuffer();
  if (societyName != null && societyName.trim().isNotEmpty) {
    buf.writeln(societyName.trim());
    buf.writeln();
  }
  buf.writeln(votingCharterTitle);
  buf.writeln();
  buf.writeln('Step-by-step program for members');
  buf.writeln(electionProgramIntro);
  buf.writeln();
  for (var i = 0; i < electionProgramSteps.length; i++) {
    final s = electionProgramSteps[i];
    buf.writeln('${i + 1}. ${s.title}');
    buf.writeln(s.detail);
    buf.writeln();
  }
  buf.writeln('Charter rules');
  buf.writeln();
  for (final sec in votingCharterSections) {
    buf.writeln(sec.heading);
    for (final p in sec.points) {
      buf.writeln('• $p');
    }
    buf.writeln();
  }
  return buf.toString().trim();
}

Future<bool> shareVotingCharterOnWhatsApp({String? societyName}) async {
  final body = '$votingCharterShareMessage\n\n${buildVotingCharterPlainText(societyName: societyName)}';
  // WhatsApp URL length limits — keep share message + full program; truncate rules if needed.
  var text = body;
  const maxLen = 3500;
  if (text.length > maxLen) {
    text = '${text.substring(0, maxLen - 20)}\n\n…(continued in app)';
  }
  final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
  if (!await canLaunchUrl(uri)) return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
