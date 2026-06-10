import '../core/config/env.dart';
import '../core/supabase/supabase_bootstrap.dart';
import '../models/guard_session.dart';
import '../models/resident_user.dart';
import '../utils/phone_utils.dart';

class ResidentLoginFailure implements Exception {
  ResidentLoginFailure(this.message);
  final String message;
}

/// Port of web OTP post-verify flows (`societiesLogin`, `guardOtpLogin`).
class ResidentLoginService {
  Future<ResidentUser> findResidentForOtp({
    required String phone,
    required String societyId,
    required String flatId,
  }) async {
    if (!Env.isConfigured) {
      throw ResidentLoginFailure('Supabase not configured');
    }

    final normalized = normalizeLoginPhone(phone);
    final client = SupabaseBootstrap.client;

    final flatsInSoc = await client
        .from('flats')
        .select('id')
        .eq('society_id', societyId);
    final flatIds = (flatsInSoc as List).map((f) => f['id'] as String).toList();

    if (flatIds.isNotEmpty) {
      final other = await client
          .from('resident_users')
          .select('flat_id')
          .eq('phone', normalized)
          .inFilter('flat_id', flatIds)
          .maybeSingle();
      if (other != null && other['flat_id'] != flatId) {
        throw ResidentLoginFailure('This phone is registered to another flat');
      }
    }

    final resident = await client
        .from('resident_users')
        .select('*')
        .eq('phone', normalized)
        .inFilter('flat_id', flatIds)
        .maybeSingle();

    if (resident == null) {
      throw ResidentLoginFailure(
        'No resident account for this phone. Use password login or complete setup on web first.',
      );
    }

    if (resident['flat_id'] != flatId) {
      throw ResidentLoginFailure('This phone is registered to another flat');
    }

    return ResidentUser.fromRow(Map<String, dynamic>.from(resident));
  }

  Future<GuardSession> findGuardForOtp({
    required String phone,
    required String societyId,
  }) async {
    if (!Env.isConfigured) {
      throw ResidentLoginFailure('Supabase not configured');
    }

    final normalized = normalizeLoginPhone(phone);
    final rows = await SupabaseBootstrap.client
        .from('guards')
        .select('*')
        .eq('society_id', societyId);

    final withPhone = (rows as List).where((g) {
      final p = g['phone'] as String?;
      return p != null && normalizeLoginPhone(p) == normalized;
    }).toList();

    if (withPhone.isEmpty) {
      throw ResidentLoginFailure('Phone not registered for any guard');
    }

    final otpGuard = withPhone.cast<Map<String, dynamic>>().where(
      (g) => g['auth_mode'] == 'otp',
    );
    if (otpGuard.isEmpty) {
      throw ResidentLoginFailure('This guard uses ID & password login');
    }

    final g = otpGuard.first;
    return GuardSession(
      guardId: g['guard_id'] as String,
      name: g['name'] as String,
      password: g['password'] as String,
    );
  }
}
