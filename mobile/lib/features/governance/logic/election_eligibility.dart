/// Pure parts of web `src/lib/electionEligibility.ts`, `electionNotify.ts` and
/// `electionProxy.ts` (deadline helpers).
library;

import 'election_governance.dart';

/// Result of the DB function `member_election_eligibility`.
class ElectionEligibility {
  const ElectionEligibility({
    required this.eligible,
    required this.reasons,
    required this.arrears,
    required this.isDesignatedVoter,
    this.memberId,
    this.flatId,
    this.asOf,
    this.arrearsDays,
  });

  final bool eligible;
  final List<String> reasons;
  final bool arrears;
  final bool isDesignatedVoter;
  final String? memberId;
  final String? flatId;
  final String? asOf;
  final int? arrearsDays;

  /// Web parsing of the RPC payload.
  factory ElectionEligibility.fromRpc(Object? data, {required String memberId}) {
    final raw = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    final reasonsRaw = raw['reasons'];
    final reasons = reasonsRaw is List ? reasonsRaw.map((e) => '$e').toList() : <String>[];
    final ad = raw['arrears_days'];
    return ElectionEligibility(
      eligible: raw['eligible'] == true,
      reasons: reasons,
      arrears: raw['arrears'] == true,
      isDesignatedVoter: raw['is_designated_voter'] != false,
      memberId: raw['member_id'] is String ? raw['member_id'] as String : memberId,
      flatId: raw['flat_id'] as String?,
      asOf: raw['as_of'] is String ? raw['as_of'] as String : null,
      arrearsDays: ad is num ? ad.toInt() : null,
    );
  }
}

/// Web `eligibilityReasonLabel` (+ Hindi).
String eligibilityReasonLabel(String reason, {bool hi = false}) {
  switch (reason) {
    case 'member_not_found':
      return hi ? 'सदस्य अभिलेख नहीं मिला' : 'Member record not found';
    case 'member_left':
      return hi ? 'सदस्य सोसायटी छोड़ चुके हैं' : 'Member has left the Society';
    case 'removal_disqualification':
      return hi
          ? 'समिति से निष्कासन (विशेष प्रस्ताव) के बाद अयोग्य'
          : 'Disqualified after committee removal (Special Resolution)';
    case 'wrong_society':
      return hi ? 'सदस्य इस सोसायटी के नहीं हैं' : 'Member does not belong to this Society';
    case 'not_designated_joint_voter':
      return hi ? 'संयुक्त स्वामित्व के नामित मतदाता नहीं' : 'Not the designated voter for joint ownership';
    case 'maintenance_arrears_over_60_days':
      return hi
          ? 'अनुरक्षण/साझा व्यय बकाया ${ByeLaw.arrearsDisqualifyDays} दिनों से अधिक'
          : 'Maintenance/common-expense arrears exceed ${ByeLaw.arrearsDisqualifyDays} days';
    default:
      return reason;
  }
}

/// Election lifecycle notification events (web `ElectionNotifyEvent`).
enum ElectionNotifyEvent { nominationOpen, votingOpen, electionClosed, winnersPublished }

/// Notification title — stored in `notifications` exactly like the web (English).
String electionNotifyTitle(ElectionNotifyEvent e) => switch (e) {
      ElectionNotifyEvent.nominationOpen => 'Society election — nomination open',
      ElectionNotifyEvent.votingOpen => 'Society election — voting open',
      ElectionNotifyEvent.electionClosed => 'Society election closed',
      ElectionNotifyEvent.winnersPublished => 'New committee published',
    };

/// Default notification message (web `defaultMessage`).
String electionNotifyMessage(ElectionNotifyEvent e, String electionTitle) => switch (e) {
      ElectionNotifyEvent.nominationOpen =>
        'Propose yourself for the 7-member Management Committee: $electionTitle',
      ElectionNotifyEvent.votingOpen => 'Cast your ballot (one vote per eligible member): $electionTitle',
      ElectionNotifyEvent.electionClosed => 'Voting has closed for: $electionTitle',
      ElectionNotifyEvent.winnersPublished =>
        'Elected Management Committee is now on the Committee roster: $electionTitle',
    };

/// Proxy submission deadline: meeting − 48 h (web `proxyDeadlineIso`).
DateTime proxyDeadline(DateTime meetingAt, [int hours = ByeLaw.proxyDeadlineHours]) =>
    meetingAt.subtract(Duration(hours: hours));

/// Web `isProxySubmissionOnTime`.
bool isProxySubmissionOnTime(DateTime submittedAt, DateTime meetingAt) =>
    !submittedAt.isAfter(proxyDeadline(meetingAt));
