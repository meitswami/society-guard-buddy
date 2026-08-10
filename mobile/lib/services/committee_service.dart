import '../core/config/env.dart';
import '../core/supabase/supabase_bootstrap.dart';
import '../models/committee_member.dart';

class CommitteeService {
  Future<List<CommitteeMember>> fetchActive(String societyId) async {
    if (!Env.isConfigured) return const [];

    final rows = await SupabaseBootstrap.client
        .from('committee_members')
        .select('*')
        .eq('society_id', societyId)
        .eq('is_active', true)
        .order('sort_order')
        .order('name');

    final raw = (rows as List).cast<Map<String, dynamic>>();
    final today = DateTime.now();
    final todayStr =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final effective = raw.where((r) {
      final from = (r['term_from'] as String?)?.substring(0, 10);
      final to = (r['term_to'] as String?)?.substring(0, 10);
      if (from != null && from.compareTo(todayStr) > 0) return false;
      if (to != null && to.compareTo(todayStr) < 0) return false;
      return true;
    }).toList();

    final flatIdSet = <String>{
      for (final r in effective)
        if (r['flat_id'] is String) r['flat_id'] as String,
    };

    final live = <String, String>{};
    if (flatIdSet.isNotEmpty) {
      final memRows = await SupabaseBootstrap.client
          .from('members')
          .select('flat_id, name, photo')
          .inFilter('flat_id', flatIdSet.toList());
      for (final m in (memRows as List).cast<Map<String, dynamic>>()) {
        final photo = (m['photo'] as String?)?.trim();
        final name = (m['name'] as String?)?.trim();
        final flatId = m['flat_id'] as String?;
        if (photo == null || photo.isEmpty || name == null || name.isEmpty || flatId == null) continue;
        live['$flatId|$name'] = photo;
      }
    }

    return effective.map((r) {
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
    }).toList();
  }
}
