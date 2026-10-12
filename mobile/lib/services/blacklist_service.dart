import '../core/config/env.dart';
import '../core/supabase/db.dart';
import '../models/blacklist_entry.dart';

/// `blacklist` table access — same queries as web `useStore` (`loadBlacklist`, `addToBlacklist`,
/// `removeFromBlacklist`).
class BlacklistService {
  /// All entries of the society, newest first.
  Future<List<BlacklistEntry>> fetchAll(String societyId) async {
    if (!Env.isConfigured) return const [];
    final rows = await db.from('blacklist').select('*').eq('society_id', societyId).order('added_at', ascending: false);
    return rowsOf(rows).map(BlacklistEntry.fromRow).toList();
  }

  /// Web `addToBlacklist` (`added_at` is filled by the database default).
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
    String? orNull(String? v) => (v == null || v.isEmpty) ? null : v;
    await db.from('blacklist').insert({
      'society_id': societyId,
      'type': type,
      'name': orNull(name),
      'phone': orNull(phone),
      'vehicle_number': orNull(vehicleNumber),
      'reason': reason,
      'added_by': addedBy,
    });
  }

  Future<void> removeEntry(String societyId, String id) async {
    if (!Env.isConfigured) return;
    await db.from('blacklist').delete().eq('id', id).eq('society_id', societyId);
  }
}
