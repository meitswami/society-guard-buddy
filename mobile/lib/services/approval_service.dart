import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/env.dart';
import '../core/supabase/supabase_bootstrap.dart';
import '../models/approval_request.dart';

class ApprovalService {
  /// Gate "Ask Permission" (web `ApprovalRequestModal`): finds the flat in this society and
  /// inserts a `pending` request. Returns the request id, or null when the flat is unknown.
  Future<String?> createVisitorRequest({
    required String societyId,
    required String flatNumber,
    required String visitorName,
    String? visitorPhone,
    required String guardId,
    required String guardName,
    String? purpose,
  }) async {
    if (!Env.isConfigured) return null;
    final flats = await SupabaseBootstrap.client
        .from('flats')
        .select('id')
        .eq('flat_number', flatNumber)
        .eq('society_id', societyId)
        .limit(1);
    if ((flats as List).isEmpty) return null;
    final flatId = (flats.first as Map)['id'] as String;
    final row = await SupabaseBootstrap.client
        .from('approval_requests')
        .insert({
          'visitor_name': visitorName,
          'visitor_phone': (visitorPhone == null || visitorPhone.isEmpty) ? null : visitorPhone,
          'flat_number': flatNumber,
          'flat_id': flatId,
          'guard_id': guardId,
          'guard_name': guardName,
          'purpose': (purpose == null || purpose.isEmpty) ? null : purpose,
          'status': 'pending',
        })
        .select('id')
        .single();
    return row['id'] as String?;
  }

  /// Current `status` of one request (polling fallback for the realtime wait).
  Future<String?> fetchRequestStatus(String requestId) async {
    if (!Env.isConfigured) return null;
    final row = await SupabaseBootstrap.client.from('approval_requests').select('status').eq('id', requestId).maybeSingle();
    return row?['status'] as String?;
  }

  /// Realtime UPDATEs of one request (web channel `approval-<id>`). Remove the returned channel
  /// with [stopWatching] when done.
  RealtimeChannel watchRequest(String requestId, void Function(String status) onStatus) {
    return SupabaseBootstrap.client
        .channel('approval-$requestId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'approval_requests',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'id', value: requestId),
          callback: (payload) {
            final status = payload.newRecord['status'];
            if (status is String) onStatus(status);
          },
        )
        .subscribe();
  }

  Future<void> stopWatching(RealtimeChannel channel) async {
    try {
      await SupabaseBootstrap.client.removeChannel(channel);
    } catch (_) {}
  }

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
