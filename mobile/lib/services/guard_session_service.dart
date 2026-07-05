import '../core/config/env.dart';
import '../core/session/app_session.dart';
import '../core/supabase/supabase_bootstrap.dart';
import '../models/guard_session.dart';

class GuardSessionService {
  Future<String?> startShift({
    required String societyId,
    required GuardSession guard,
  }) async {
    if (!Env.isConfigured) return null;

    final row = await SupabaseBootstrap.client
        .from('guard_shifts')
        .insert({
          'guard_id': guard.guardId,
          'guard_name': guard.name,
          'login_time': DateTime.now().toIso8601String(),
          'society_id': societyId,
        })
        .select('id')
        .single();

    final shiftId = row['id'] as String;
    await AppSession.write({
      'role': 'guard',
      'societyId': societyId,
      'shiftId': shiftId,
      'guardId': guard.guardId,
    });
    return shiftId;
  }

  Future<GuardSession?> restoreSession({
    required String societyId,
    required String shiftId,
    required String guardId,
  }) async {
    if (!Env.isConfigured) return null;

    final shift = await SupabaseBootstrap.client
        .from('guard_shifts')
        .select('id, guard_id, login_time, logout_time')
        .eq('id', shiftId)
        .maybeSingle();

    if (shift == null || shift['logout_time'] != null) return null;

    final guardRow = await SupabaseBootstrap.client
        .from('guards')
        .select('*')
        .eq('guard_id', guardId)
        .eq('society_id', societyId)
        .maybeSingle();

    if (guardRow == null) return null;

    return GuardSession(
      guardId: guardRow['guard_id'] as String,
      name: guardRow['name'] as String,
      password: guardRow['password'] as String,
      loginTime: shift['login_time'] as String?,
    );
  }

  Future<void> endShift(String shiftId) async {
    if (!Env.isConfigured) return;
    await SupabaseBootstrap.client
        .from('guard_shifts')
        .update({'logout_time': DateTime.now().toIso8601String()})
        .eq('id', shiftId);
    await AppSession.clear();
  }
}
