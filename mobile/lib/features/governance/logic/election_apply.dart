/// Pure parts of web `src/lib/electionApply.ts` (publishing the formed committee).
library;

import 'election_governance.dart';
import 'election_tally.dart';

/// `poll_options` fields needed to build `committee_members` rows.
class ApplyOption {
  const ApplyOption({required this.id, required this.optionText, this.memberId, this.flatId, this.flatNumber});

  final String id;
  final String optionText;
  final String? memberId;
  final String? flatId;
  final String? flatNumber;

  factory ApplyOption.fromJson(Map<String, dynamic> j) => ApplyOption(
        id: '${j['id']}',
        optionText: (j['option_text'] ?? '').toString(),
        memberId: j['member_id'] as String?,
        flatId: j['flat_id'] as String?,
        flatNumber: j['flat_number'] as String?,
      );
}

const Map<String, String> postToCommitteePosition = {
  ElectionPosts.president: 'President',
  ElectionPosts.vicePresident: 'Vice-President',
  ElectionPosts.secretary: 'Secretary',
  ElectionPosts.treasurer: 'Treasurer',
  ElectionPosts.committee: 'Committee Member',
};

/// Member ids whose profile photos are copied onto the roster.
List<String> applyMemberIds(List<ApplyOption> options, Object? results) {
  final formation = formationRawOf(results);
  return [
    ...options.map((o) => o.memberId).whereType<String>(),
    ...formationEntries(formation, 'voluntary').map((v) => v['member_id']).whereType<String>(),
    ...formationEntries(formation, 'executive_proposed').map((e) => e['member_id']).whereType<String>(),
  ].where((s) => s.isNotEmpty).toList();
}

Map<String, dynamic> _formationInsert({
  required String societyId,
  required String pollId,
  required String termFrom,
  required String? termTo,
  required int sort,
  required Map<String, dynamic> member,
  required String selectionType,
  required Map<String, String> photoByMemberId,
}) {
  final memberId = member['member_id'] as String?;
  final photo = memberId == null ? null : photoByMemberId[memberId];
  final name = (member['name'] ?? '').toString();
  return {
    'society_id': societyId,
    'flat_id': member['flat_id'],
    'flat_number': member['flat_number'],
    'flat_owner_name': name,
    'name': name,
    'position': 'Committee Member',
    'photo': (photo == null || photo.isEmpty) ? null : photo,
    'selection_type': selectionType,
    'term_from': termFrom,
    'term_to': termTo,
    'sort_order': sort,
    'is_active': true,
    'source_poll_id': pollId,
    'source_option_id': member['option_id'],
  };
}

/// Rows inserted into `committee_members` when the formed committee is published.
List<Map<String, dynamic>> buildCommitteeInserts({
  required String societyId,
  required String pollId,
  required Map<String, dynamic> results,
  required List<ApplyOption> options,
  required String termFrom,
  required String? termTo,
  Map<String, String> photoByMemberId = const {},
}) {
  final optById = {for (final o in options) o.id: o};
  final inserts = <Map<String, dynamic>>[];
  var sort = 0;

  Map<String, dynamic> winnerRow(ElectedWinner w, String position) {
    final opt = optById[w.optionId];
    final mid = opt?.memberId;
    final photo = mid == null ? null : photoByMemberId[mid];
    return {
      'society_id': societyId,
      'flat_id': opt?.flatId,
      'flat_number': opt?.flatNumber,
      'flat_owner_name': opt?.optionText ?? w.name,
      'name': w.name,
      'position': position,
      'photo': (photo == null || photo.isEmpty) ? null : photo,
      'selection_type': 'elected',
      'term_from': termFrom,
      'term_to': termTo,
      'sort_order': sort++,
      'is_active': true,
      'source_poll_id': pollId,
      'source_option_id': w.optionId,
    };
  }

  for (final post in ElectionPosts.offices) {
    final w = ElectedWinner.fromJson(results[post]);
    if (w == null) continue;
    inserts.add(winnerRow(w, postToCommitteePosition[post] ?? post));
  }

  final committee = results[ElectionPosts.committee];
  if (committee is List) {
    for (final raw in committee) {
      final w = ElectedWinner.fromJson(raw);
      if (w == null) continue;
      inserts.add(winnerRow(w, 'Committee Member'));
    }
  }

  final formation = formationRawOf(results);
  for (final v in formationEntries(formation, 'voluntary')) {
    inserts.add(_formationInsert(
      societyId: societyId,
      pollId: pollId,
      termFrom: termFrom,
      termTo: termTo,
      sort: sort++,
      member: v,
      selectionType: 'voluntary',
      photoByMemberId: photoByMemberId,
    ));
  }
  for (final e in formationEntries(formation, 'executive_proposed')) {
    inserts.add(_formationInsert(
      societyId: societyId,
      pollId: pollId,
      termFrom: termFrom,
      termTo: termTo,
      sort: sort++,
      member: e,
      selectionType: 'executive_proposed',
      photoByMemberId: photoByMemberId,
    ));
  }
  return inserts;
}

String _pad2(int n) => n.toString().padLeft(2, '0');

/// The prior roster is retired the day before the new term starts.
String priorTermTo(String termFrom) {
  final parts = termFrom.split('-').map(int.parse).toList();
  final prior = DateTime(parts[0], parts[1], parts[2]).subtract(const Duration(days: 1));
  // Normalise across DST-less local dates by rebuilding from components.
  final d = DateTime(prior.year, prior.month, prior.day);
  return '${d.year}-${_pad2(d.month)}-${_pad2(d.day)}';
}

/// Active rows overlapping the new term (web retirement filter).
List<String> retireIdsFor(List<Map<String, dynamic>> priorRows, String termFrom) {
  return priorRows
      .where((r) {
        final fromRaw = r['term_from']?.toString();
        final toRaw = r['term_to']?.toString();
        final from = fromRaw == null || fromRaw.length < 10 ? fromRaw : fromRaw.substring(0, 10);
        final to = toRaw == null || toRaw.length < 10 ? toRaw : toRaw.substring(0, 10);
        if (from != null && from.isNotEmpty && from.compareTo(termFrom) >= 0) return false;
        if (to != null && to.isNotEmpty && to.compareTo(termFrom) < 0) return false;
        return true;
      })
      .map((r) => '${r['id']}')
      .toList();
}
