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

    return (rows as List)
        .map((r) => CommitteeMember.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }
}
