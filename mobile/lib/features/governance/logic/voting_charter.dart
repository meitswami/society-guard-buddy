/// Port of web `src/lib/votingCharter.ts` — society election charter keys.
/// Text resolves through the shared translations (`votingCharter.*` keys).
library;

const String votingCharterTitleKey = 'votingCharter.title';

/// Prominent resident summary (bye-law composition + voting rights).
abstract final class VotingCharterSummary {
  static const titleKey = 'votingCharter.summary.title';
  static const postsKey = 'votingCharter.summary.posts';
  static const voteRightKey = 'votingCharter.summary.voteRight';
  static const proxyKey = 'votingCharter.summary.proxy';
  static const quorumKey = 'votingCharter.summary.quorum';

  static const pointKeys = [voteRightKey, proxyKey, quorumKey];
}

class ElectionProgramStep {
  const ElectionProgramStep(
      {required this.stepKey,
      required this.detailKey,
      required this.pointKeys});

  final String stepKey;
  final String detailKey;

  /// Bye-law points shown under this step (merged charter).
  final List<String> pointKeys;
}

/// Numbered member program — charter narrative + bye-law rules in member journey order.
const List<ElectionProgramStep> electionProgramSteps = [
  ElectionProgramStep(
    stepKey: 'votingCharter.program.s1.title',
    detailKey: 'votingCharter.program.s1.detail',
    pointKeys: ['votingCharter.committee.p1', 'votingCharter.committee.p2'],
  ),
  ElectionProgramStep(
    stepKey: 'votingCharter.program.s2.title',
    detailKey: 'votingCharter.program.s2.detail',
    pointKeys: [
      'votingCharter.eligibility.p1',
      'votingCharter.eligibility.p2',
      'votingCharter.eligibility.p3',
      'votingCharter.eligibility.p4',
    ],
  ),
  ElectionProgramStep(
    stepKey: 'votingCharter.program.s3.title',
    detailKey: 'votingCharter.program.s3.detail',
    pointKeys: [
      'votingCharter.nomination.p1',
      'votingCharter.nomination.p2',
      'votingCharter.nomination.p3'
    ],
  ),
  ElectionProgramStep(
    stepKey: 'votingCharter.program.s4.title',
    detailKey: 'votingCharter.program.s4.detail',
    pointKeys: [
      'votingCharter.method.p1',
      'votingCharter.method.p2',
      'votingCharter.method.p3',
      'votingCharter.method.p4',
    ],
  ),
  ElectionProgramStep(
    stepKey: 'votingCharter.program.s5.title',
    detailKey: 'votingCharter.program.s5.detail',
    pointKeys: ['votingCharter.docs.p2', 'votingCharter.committee.p3'],
  ),
  ElectionProgramStep(
    stepKey: 'votingCharter.program.s6.title',
    detailKey: 'votingCharter.program.s6.detail',
    pointKeys: [
      'votingCharter.docs.p1',
      'votingCharter.docs.p3',
      'votingCharter.committee.p4'
    ],
  ),
];

/// @deprecated Separate rules list (kept for legacy parity with the web constant).
const List<({String headingKey, List<String> pointKeys})>
    votingCharterSections = [
  (
    headingKey: 'votingCharter.eligibility.heading',
    pointKeys: [
      'votingCharter.eligibility.p1',
      'votingCharter.eligibility.p2',
      'votingCharter.eligibility.p3',
      'votingCharter.eligibility.p4',
    ],
  ),
  (
    headingKey: 'votingCharter.nomination.heading',
    pointKeys: [
      'votingCharter.nomination.p1',
      'votingCharter.nomination.p2',
      'votingCharter.nomination.p3'
    ],
  ),
  (
    headingKey: 'votingCharter.method.heading',
    pointKeys: [
      'votingCharter.method.p1',
      'votingCharter.method.p2',
      'votingCharter.method.p3',
      'votingCharter.method.p4',
    ],
  ),
  (
    headingKey: 'votingCharter.committee.heading',
    pointKeys: [
      'votingCharter.committee.p1',
      'votingCharter.committee.p2',
      'votingCharter.committee.p3',
      'votingCharter.committee.p4',
    ],
  ),
  (
    headingKey: 'votingCharter.docs.heading',
    pointKeys: [
      'votingCharter.docs.p1',
      'votingCharter.docs.p2',
      'votingCharter.docs.p3',
      'votingCharter.docs.p4'
    ],
  ),
];

/// Every key the charter needs (for checks / PDF building).
List<String> allVotingCharterKeys() => [
      votingCharterTitleKey,
      VotingCharterSummary.titleKey,
      VotingCharterSummary.postsKey,
      ...VotingCharterSummary.pointKeys,
      'votingCharter.program.heading',
      'votingCharter.program.intro',
      'votingCharter.shareMessage',
      for (final s in electionProgramSteps) ...[
        s.stepKey,
        s.detailKey,
        ...s.pointKeys
      ],
    ];

/// Resolve charter copy for an explicit language from a static row
/// (web `charterText`: preferred language → English → Hindi → key).
String charterTextFromRow(Map<String, String>? row, String key,
    {required bool hi}) {
  if (row == null) return key;
  final preferred = (row[hi ? 'hi' : 'en'] ?? '').trim();
  if (preferred.isNotEmpty) return preferred;
  final fallback =
      ((row['en'] ?? '').isNotEmpty ? row['en']! : (row['hi'] ?? '')).trim();
  return fallback.isEmpty ? key : fallback;
}

/// `voting-charter-{lang}-{slug}-{yyyy-MM-dd}.pdf` (web `votingCharterPdfFilename`).
String votingCharterPdfFilename(String? societyName,
    {required bool hi, DateTime? now}) {
  var slug =
      (societyName == null || societyName.isEmpty ? 'society' : societyName)
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-|-$'), '');
  if (slug.length > 40) slug = slug.substring(0, 40);
  final d = (now ?? DateTime.now()).toUtc();
  final day =
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  return 'voting-charter-${hi ? 'hi' : 'en'}-${slug.isEmpty ? 'society' : slug}-$day.pdf';
}
