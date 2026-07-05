import '../core/config/env.dart';
import '../core/supabase/supabase_bootstrap.dart';
import '../utils/password_generator.dart';

class AdminResidentService {
  Future<List<Map<String, dynamic>>> fetchFlats(String societyId) async {
    if (!Env.isConfigured) return const [];
    final rows = await SupabaseBootstrap.client
        .from('flats')
        .select('id, flat_number')
        .eq('society_id', societyId)
        .order('flat_number');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> addResident({
    required String flatId,
    required String flatNumber,
    required String name,
    required String phone,
    String? password,
  }) async {
    if (!Env.isConfigured) return;

    final normalized = phone.replaceAll(RegExp(r'\D'), '');
    if (normalized.length < 10) throw StateError('Enter a valid 10-digit phone');

    final existing = await SupabaseBootstrap.client
        .from('resident_users')
        .select('id')
        .eq('flat_id', flatId)
        .eq('phone', normalized)
        .maybeSingle();
    if (existing != null) throw StateError('Phone already registered for this flat');

    final flatMate = await SupabaseBootstrap.client
        .from('resident_users')
        .select('password')
        .eq('flat_id', flatId)
        .limit(1)
        .maybeSingle();
    final pwd = password?.trim().isNotEmpty == true
        ? password!.trim()
        : (flatMate?['password'] as String? ?? generateFlatPassword());

    await SupabaseBootstrap.client.from('resident_users').insert({
      'flat_id': flatId,
      'flat_number': flatNumber,
      'name': name.trim(),
      'phone': normalized.length > 10 ? normalized.substring(normalized.length - 10) : normalized,
      'password': pwd,
      'must_change_password': false,
    });
  }

  Future<void> updateResident({
    required String id,
    required String name,
    String? phone,
  }) async {
    if (!Env.isConfigured) return;

    final payload = <String, dynamic>{'name': name.trim()};
    if (phone != null) {
      final normalized = phone.replaceAll(RegExp(r'\D'), '');
      if (normalized.length < 10) throw StateError('Enter a valid phone');
      payload['phone'] = normalized.length > 10 ? normalized.substring(normalized.length - 10) : normalized;
    }

    await SupabaseBootstrap.client.from('resident_users').update(payload).eq('id', id);
  }

  Future<void> resetPassword({
    required String id,
    required String password,
  }) async {
    if (!Env.isConfigured) return;
    if (password.length < 4) throw StateError('Password must be at least 4 characters');

    await SupabaseBootstrap.client.from('resident_users').update({
      'password': password,
      'must_change_password': true,
    }).eq('id', id);
  }

  Future<void> deleteResident(String id) async {
    if (!Env.isConfigured) return;
    await SupabaseBootstrap.client.from('resident_users').delete().eq('id', id);
  }
}
