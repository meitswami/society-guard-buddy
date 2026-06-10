import '../core/config/env.dart';
import '../core/supabase/supabase_bootstrap.dart';

class SocietyRow {
  const SocietyRow({required this.id, required this.name});

  final String id;
  final String name;
}

/// Port of `src/lib/societiesLogin.ts`.
class SocietyService {
  Future<List<SocietyRow>> fetchActiveSocieties() async {
    if (!Env.isConfigured) return const [];

    final rows = await SupabaseBootstrap.client
        .from('societies')
        .select('id, name')
        .eq('is_active', true)
        .order('name');

    return (rows as List)
        .map((r) => SocietyRow(id: r['id'] as String, name: r['name'] as String))
        .toList();
  }
}
