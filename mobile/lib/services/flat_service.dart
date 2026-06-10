import '../core/config/env.dart';
import '../core/supabase/supabase_bootstrap.dart';
import '../models/flat_row.dart';

class FlatService {
  Future<List<FlatRow>> fetchFlatsForSociety(String societyId) async {
    if (!Env.isConfigured) return const [];

    final rows = await SupabaseBootstrap.client
        .from('flats')
        .select('id, flat_number')
        .eq('society_id', societyId)
        .order('flat_number');

    return (rows as List)
        .map((r) => FlatRow.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }
}
