import '../core/config/env.dart';
import '../core/supabase/supabase_bootstrap.dart';
import '../models/approval_request.dart';

class ApprovalService {
  Future<List<ApprovalRequest>> fetchForFlat(String flatId) async {
    if (!Env.isConfigured) return const [];

    final rows = await SupabaseBootstrap.client
        .from('approval_requests')
        .select('*')
        .eq('flat_id', flatId)
        .order('created_at', ascending: false)
        .limit(50);

    return (rows as List)
        .map((r) => ApprovalRequest.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<int> countPending(String flatId) async {
    final all = await fetchForFlat(flatId);
    return all.where((r) => r.status == 'pending').length;
  }

  Future<void> respond({
    required String id,
    required String flatId,
    required String status,
  }) async {
    if (!Env.isConfigured) return;
    await SupabaseBootstrap.client
        .from('approval_requests')
        .update({
          'status': status,
          'responded_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id)
        .eq('flat_id', flatId);
  }
}
