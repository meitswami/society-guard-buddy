import '../core/config/env.dart';
import '../core/supabase/supabase_bootstrap.dart';
import '../models/blacklist_entry.dart';

class BlacklistService {
  Future<List<BlacklistEntry>> fetchAll(String societyId) async {
    if (!Env.isConfigured) return const [];

    final rows = await SupabaseBootstrap.client
        .from('blacklist')
        .select('*')
        .eq('society_id', societyId)
        .order('added_at', ascending: false);

    return (rows as List)
        .map((r) => BlacklistEntry.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<void> addEntry({
    required String societyId,
    required String type,
    required String reason,
    required String addedBy,
    String? name,
    String? phone,
    String? vehicleNumber,
  }) async {
    if (!Env.isConfigured) return;

    await SupabaseBootstrap.client.from('blacklist').insert({
      'society_id': societyId,
      'type': type,
      'reason': reason.trim(),
      'added_by': addedBy,
      'added_at': DateTime.now().toIso8601String(),
      if (name != null && name.isNotEmpty) 'name': name.trim(),
      if (phone != null && phone.isNotEmpty) 'phone': phone.trim(),
      if (vehicleNumber != null && vehicleNumber.isNotEmpty) 'vehicle_number': vehicleNumber.trim().toUpperCase(),
    });
  }

  Future<void> removeEntry(String societyId, String id) async {
    if (!Env.isConfigured) return;

    await SupabaseBootstrap.client
        .from('blacklist')
        .delete()
        .eq('id', id)
        .eq('society_id', societyId);
  }
}
