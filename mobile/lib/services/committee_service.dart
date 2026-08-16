import '../core/config/env.dart';
import '../core/supabase/supabase_bootstrap.dart';
import '../models/committee_member.dart';

class CommitteeRoster {
  const CommitteeRoster({required this.current, required this.previous});

  final List<CommitteeMember> current;
  final List<CommitteeMember> previous;

  bool get hasPrevious => previous.isNotEmpty;
}

const _uniquePosts = {
  'president',
  'vice-president',
  'secretary',
  'treasurer',
  'cultural secretary',
};

class CommitteeService {
  Future<List<CommitteeMember>> fetchActive(String societyId) async {
    final roster = await fetchRoster(societyId);
    return roster.current;
  }

  Future<CommitteeRoster> fetchRoster(String societyId) async {
    if (!Env.isConfigured) {
      return const CommitteeRoster(current: [], previous: []);
    }

    final rows = await SupabaseBootstrap.client
        .from('committee_members')
        .select('*')
        .eq('society_id', societyId)
        .eq('is_active', true)
        .order('sort_order')
        .order('name');

    final raw = (rows as List).cast<Map<String, dynamic>>();
    String? latestFrom;
    for (final r in raw) {
      final from = (r['term_from'] as String?)?.substring(0, 10);
      if (from != null && (latestFrom == null || from.compareTo(latestFrom) > 0)) {
        latestFrom = from;
      }
    }

    final currentRaw = <Map<String, dynamic>>[];
    final previousRaw = <Map<String, dynamic>>[];
    for (final r in raw) {
      final from = (r['term_from'] as String?)?.substring(0, 10);
      final to = (r['term_to'] as String?)?.substring(0, 10);
      final isCurrent = latestFrom == null
          ? true
          : from != null
              ? from.compareTo(latestFrom) >= 0
              : !(to != null && to.compareTo(latestFrom) < 0);
      if (isCurrent) {
        currentRaw.add(r);
      } else {
        previousRaw.add(r);
      }
    }

    final currentDeduped = _dedupeByPosition(currentRaw);
    final live = await _livePhotos([...currentDeduped, ...previousRaw]);

    return CommitteeRoster(
      current: currentDeduped.map((r) => _toMember(r, live)).toList(),
      previous: previousRaw.map((r) => _toMember(r, live)).toList(),
    );
  }

  List<Map<String, dynamic>> _dedupeByPosition(List<Map<String, dynamic>> rows) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final r in rows) {
      final pos = (r['position'] as String? ?? '').trim().toLowerCase();
      final name = (r['name'] as String? ?? '').trim().toLowerCase();
      final key = _uniquePosts.contains(pos) ? pos : '$pos|$name';
      groups.putIfAbsent(key, () => []).add(r);
    }
    final out = <Map<String, dynamic>>[];
    for (final list in groups.values) {
      list.sort((a, b) {
        final aTo = a['term_to'] == null ? 0 : 1;
        final bTo = b['term_to'] == null ? 0 : 1;
        if (aTo != bTo) return bTo - aTo;
        final aName = (a['name'] as String? ?? '').length;
        final bName = (b['name'] as String? ?? '').length;
        if (aName != bName) return bName - aName;
        return ((a['sort_order'] as num?)?.toInt() ?? 0) - ((b['sort_order'] as num?)?.toInt() ?? 0);
      });
      out.add(list.first);
    }
    out.sort((a, b) {
      final sa = (a['sort_order'] as num?)?.toInt() ?? 0;
      final sb = (b['sort_order'] as num?)?.toInt() ?? 0;
      if (sa != sb) return sa - sb;
      return (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? '');
    });
    return out;
  }

  Future<Map<String, String>> _livePhotos(List<Map<String, dynamic>> raw) async {
    final flatIdSet = <String>{
      for (final r in raw)
        if (r['flat_id'] is String) r['flat_id'] as String,
    };
    if (flatIdSet.isEmpty) return const {};

    final memRows = await SupabaseBootstrap.client
        .from('members')
        .select('flat_id, name, photo')
        .inFilter('flat_id', flatIdSet.toList());
    final live = <String, String>{};
    for (final m in (memRows as List).cast<Map<String, dynamic>>()) {
      final photo = (m['photo'] as String?)?.trim();
      final name = (m['name'] as String?)?.trim();
      final flatId = m['flat_id'] as String?;
      if (photo == null || photo.isEmpty || name == null || name.isEmpty || flatId == null) continue;
      live['$flatId|$name'] = photo;
    }
    return live;
  }

  CommitteeMember _toMember(Map<String, dynamic> r, Map<String, String> live) {
    final member = CommitteeMember.fromRow(r);
    final flatId = r['flat_id'] as String?;
    final livePhoto = flatId != null ? live['$flatId|${member.name}'] : null;
    if (livePhoto == null) return member;
    return CommitteeMember(
      id: member.id,
      name: member.name,
      position: member.position,
      flatNumber: member.flatNumber,
      phone: member.phone,
      photo: livePhoto,
      repName: member.repName,
      repPhone: member.repPhone,
      repPhoto: member.repPhoto,
      showRepresentative: member.showRepresentative,
      termFrom: member.termFrom,
      termTo: member.termTo,
    );
  }
}
