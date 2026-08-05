import '../core/config/env.dart';
import '../core/supabase/supabase_bootstrap.dart';

class AdminFlatService {
  Future<List<Map<String, dynamic>>> fetchFlats(String societyId) async {
    if (!Env.isConfigured) return const [];
    final rows = await SupabaseBootstrap.client
        .from('flats')
        .select(
          'id, flat_number, wing, floor, flat_type, owner_name, owner_phone, '
          'is_occupied, owner_lives_here, intercom',
        )
        .eq('society_id', societyId)
        .order('flat_number');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>?> fetchFlat(String flatId) async {
    if (!Env.isConfigured) return null;
    return await SupabaseBootstrap.client
        .from('flats')
        .select('*')
        .eq('id', flatId)
        .maybeSingle();
  }

  Future<String> upsertFlat({
    required String societyId,
    String? id,
    required String flatNumber,
    String? wing,
    String? floor,
    String? flatType,
    String? ownerName,
    String? ownerPhone,
    bool? isOccupied,
    bool? ownerLivesHere,
    String? intercom,
  }) async {
    if (!Env.isConfigured) throw StateError('Supabase not configured');

    final payload = <String, dynamic>{
      'society_id': societyId,
      'flat_number': flatNumber.trim(),
      'wing': wing?.trim().isEmpty == true ? null : wing?.trim(),
      'floor': floor?.trim().isEmpty == true ? null : floor?.trim(),
      'flat_type': flatType?.trim().isEmpty == true ? null : flatType?.trim(),
      'owner_name': ownerName?.trim().isEmpty == true ? null : ownerName?.trim(),
      'owner_phone': _normalizePhone(ownerPhone),
      'is_occupied': isOccupied,
      'owner_lives_here': ownerLivesHere ?? true,
      'intercom': intercom?.trim().isEmpty == true ? null : intercom?.trim(),
    };

    if (id != null) {
      await SupabaseBootstrap.client.from('flats').update(payload).eq('id', id);
      return id;
    }

    final row = await SupabaseBootstrap.client
        .from('flats')
        .insert(payload)
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<void> deleteFlat(String flatId) async {
    if (!Env.isConfigured) return;

    final residents = await SupabaseBootstrap.client
        .from('resident_users')
        .select('id')
        .eq('flat_id', flatId)
        .limit(1);
    if ((residents as List).isNotEmpty) {
      throw StateError('Remove resident logins before deleting this flat');
    }

    await SupabaseBootstrap.client.from('members').delete().eq('flat_id', flatId);
    await SupabaseBootstrap.client.from('flats').delete().eq('id', flatId);
  }

  Future<List<Map<String, dynamic>>> fetchMembers(String flatId) async {
    if (!Env.isConfigured) return const [];
    final rows = await SupabaseBootstrap.client
        .from('members')
        .select('id, name, phone, relation, age, gender, is_primary, household_group, photo')
        .eq('flat_id', flatId)
        .order('is_primary', ascending: false)
        .order('name');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> addMember({
    required String flatId,
    required String name,
    String? phone,
    String? relation,
    int? age,
    String? gender,
    bool isPrimary = false,
  }) async {
    if (!Env.isConfigured) return;
    if (name.trim().isEmpty) throw StateError('Name is required');

    if (isPrimary) {
      await SupabaseBootstrap.client
          .from('members')
          .update({'is_primary': false})
          .eq('flat_id', flatId)
          .eq('is_primary', true);
    }

    await SupabaseBootstrap.client.from('members').insert({
      'flat_id': flatId,
      'name': name.trim(),
      'phone': _normalizePhone(phone),
      'relation': relation?.trim().isEmpty == true ? null : relation?.trim(),
      'age': age,
      'gender': gender?.trim().isEmpty == true ? null : gender?.trim(),
      'is_primary': isPrimary,
      'household_group': 'default',
    });
  }

  Future<void> updateMember({
    required String id,
    required String name,
    String? phone,
    String? relation,
    int? age,
    String? gender,
    bool? isPrimary,
    required String flatId,
  }) async {
    if (!Env.isConfigured) return;
    if (name.trim().isEmpty) throw StateError('Name is required');

    if (isPrimary == true) {
      await SupabaseBootstrap.client
          .from('members')
          .update({'is_primary': false})
          .eq('flat_id', flatId)
          .eq('is_primary', true);
    }

    await SupabaseBootstrap.client.from('members').update({
      'name': name.trim(),
      'phone': _normalizePhone(phone),
      'relation': relation?.trim().isEmpty == true ? null : relation?.trim(),
      'age': age,
      'gender': gender?.trim().isEmpty == true ? null : gender?.trim(),
      if (isPrimary != null) 'is_primary': isPrimary,
    }).eq('id', id);
  }

  Future<void> deleteMember(String id) async {
    if (!Env.isConfigured) return;
    await SupabaseBootstrap.client.from('members').delete().eq('id', id);
  }

  Future<List<Map<String, dynamic>>> fetchResidentUsers(String flatId) async {
    if (!Env.isConfigured) return const [];
    final rows = await SupabaseBootstrap.client
        .from('resident_users')
        .select('id, name, phone, flat_number')
        .eq('flat_id', flatId)
        .order('name');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  String? _normalizePhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) return null;
    final normalized = phone.replaceAll(RegExp(r'\D'), '');
    if (normalized.length < 10) return null;
    return normalized.length > 10
        ? normalized.substring(normalized.length - 10)
        : normalized;
  }
}
