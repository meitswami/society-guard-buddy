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
    final flatIdSet = <String>{
      for (final r in raw)
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

    return raw.map((r) {
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
