import '../core/config/env.dart';
import '../core/supabase/supabase_bootstrap.dart';

class AdminGuardService {
  Future<void> addGuard({
    required String societyId,
    required String guardId,
    required String name,
    required String authMode,
    String? password,
    String? phone,
  }) async {
    if (!Env.isConfigured) return;

    await SupabaseBootstrap.client.from('guards').insert({
      'guard_id': guardId.trim().toUpperCase(),
      'name': name.trim(),
      'password': authMode == 'otp' ? 'OTP_AUTH' : (password ?? ''),
      'society_id': societyId,
      'auth_mode': authMode,
      'phone': phone?.trim(),
      'police_verification': 'pending',
      'kyc_alert_days': 7,
    });
  }

  Future<void> updateGuard({
    required String id,
    required String societyId,
    required String name,
    String? phone,
    String? authMode,
  }) async {
    if (!Env.isConfigured) return;

    await SupabaseBootstrap.client.from('guards').update({
      'name': name.trim(),
      if (phone != null) 'phone': phone.trim(),
      if (authMode != null) 'auth_mode': authMode,
    }).eq('id', id).eq('society_id', societyId);
  }

  Future<void> resetPassword({
    required String id,
    required String societyId,
    required String password,
  }) async {
    if (!Env.isConfigured) return;
    if (password.length < 4) throw StateError('Password must be at least 4 characters');

    await SupabaseBootstrap.client
        .from('guards')
        .update({'password': password})
        .eq('id', id)
        .eq('society_id', societyId);
  }

  Future<void> deleteGuard(String societyId, String id) async {
    if (!Env.isConfigured) return;
    await SupabaseBootstrap.client.from('guards').delete().eq('id', id).eq('society_id', societyId);
  }
}
