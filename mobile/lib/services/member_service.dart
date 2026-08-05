import '../core/config/env.dart';
import '../core/supabase/supabase_bootstrap.dart';
import '../models/flat_member.dart';
import '../utils/phone_utils.dart';

class MemberService {
  Future<List<FlatMember>> fetchForFlat(String flatId) async {
    if (!Env.isConfigured) return const [];

    final rows = await SupabaseBootstrap.client
        .from('members')
        .select('*')
        .eq('flat_id', flatId)
        .order('is_primary', ascending: false)
        .order('created_at');

    return (rows as List)
        .map((r) => FlatMember.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<FlatMember?> findByPhone(String flatId, String phone) async {
    final members = await fetchForFlat(flatId);
    final normalized = normalizeLoginPhone(phone);
    for (final m in members) {
      final p = m.phone;
      if (p != null && normalizeLoginPhone(p) == normalized) return m;
    }
    return null;
  }

  Future<Map<String, String>> fetchPhotosByIds(List<String> memberIds) async {
    if (!Env.isConfigured || memberIds.isEmpty) return {};
    final ids = memberIds.toSet().toList();
    final rows = await SupabaseBootstrap.client.from('members').select('id, photo').inFilter('id', ids);
    final map = <String, String>{};
    for (final row in rows as List) {
      final m = Map<String, dynamic>.from(row as Map);
      final photo = (m['photo'] as String?)?.trim();
      if (photo != null && photo.isNotEmpty) {
        map[m['id'] as String] = photo;
      }
    }
    return map;
  }

  Future<void> addMember({
    required String flatId,
    required String name,
    String? relation,
    String? phone,
    int? age,
    String? photo,
    String householdGroup = 'family',
  }) async {
    if (!Env.isConfigured) return;

    await SupabaseBootstrap.client.from('members').insert({
      'flat_id': flatId,
      'name': name.trim(),
      if (relation != null && relation.trim().isNotEmpty) 'relation': relation.trim(),
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      if (age != null) 'age': age,
      if (photo != null && photo.trim().isNotEmpty) 'photo': photo.trim(),
      'household_group': householdGroup,
      'is_primary': false,
    });
  }

  Future<void> updatePhoto({required String memberId, required String photo}) async {
    if (!Env.isConfigured) return;
    await SupabaseBootstrap.client.from('members').update({'photo': photo}).eq('id', memberId);
  }
}
