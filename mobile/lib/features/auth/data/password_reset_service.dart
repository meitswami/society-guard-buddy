import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/db.dart';
import '../../../services/society_service.dart';
import 'auth_audit.dart';
import 'login_logic.dart';

/// Account found by the reset flow (`resident_users` / `guards` / `admins` row).
class ResetAccount {
  const ResetAccount({required this.id, required this.name, this.email, this.flatNumber = '', this.flatId, this.societyId});

  final String id;
  final String name;
  final String? email;

  /// `user.flat_number || user.guard_id || ''` (web).
  final String flatNumber;
  final String? flatId;
  final String? societyId;

  bool get hasEmail => (email ?? '').trim().isNotEmpty;

  factory ResetAccount.fromRow(Map<String, dynamic> r) {
    final flat = (r['flat_number'] as String?) ?? '';
    final guardId = (r['guard_id'] as String?) ?? '';
    return ResetAccount(
      id: r['id'] as String,
      name: (r['name'] as String?) ?? '',
      email: r['email'] as String?,
      flatNumber: flat.isNotEmpty ? flat : guardId,
      flatId: r['flat_id'] as String?,
      societyId: r['society_id'] as String?,
    );
  }
}

enum ResetTokenProblem { expiredOrInvalid }

String resetUserTypeKey(ResetUserType t) => t.name;

/// Port of the Supabase work in web `PasswordResetFlow` (lookup, token, reset, ask admin).
class PasswordResetService {
  PasswordResetService({SocietyService? societies}) : _societies = societies ?? SocietyService();

  final SocietyService _societies;

  /// Web `maybeSingle()` / `single()` semantics: any PostgREST error → no data.
  static Future<Map<String, dynamic>?> _row(Future<Map<String, dynamic>?> q) async {
    try {
      final r = await q;
      return r == null ? null : Map<String, dynamic>.from(r);
    } on PostgrestException {
      return null;
    }
  }

  /// Web `requestReset` account lookup.
  Future<ResetAccount?> findAccount({
    required ResetUserType userType,
    required ResetMethod method,
    required String identifier,
    String? societyId,
  }) async {
    if (!dbReady) return null;
    final sid = (societyId ?? '').isEmpty ? null : societyId;
    Map<String, dynamic>? user;

    if (method == ResetMethod.email) {
      if (userType == ResetUserType.resident && sid != null) {
        final flatIds = await _societies.fetchSocietyFlatIds(sid);
        if (flatIds.isNotEmpty) {
          user = await _row(db.from('resident_users').select('*').eq('email', identifier).inFilter('flat_id', flatIds).maybeSingle());
        }
      } else if (userType == ResetUserType.admin && sid != null) {
        user = await _row(db.from('admins').select('*').eq('email', identifier).eq('society_id', sid).maybeSingle());
      } else if (userType == ResetUserType.guard && sid != null) {
        user = await _row(db.from('guards').select('*').eq('email', identifier).eq('society_id', sid).maybeSingle());
      } else if (userType == ResetUserType.admin) {
        user = await _row(db.from('admins').select('*').eq('email', identifier).single());
      } else {
        user = await _row(db.from('resident_users').select('*').eq('email', identifier).single());
      }
    } else if (userType == ResetUserType.resident) {
      if (sid != null) {
        user = await _societies.getResidentByPhoneInSociety(identifier, sid);
      } else {
        user = await _row(db.from('resident_users').select('*').eq('phone', identifier).single());
      }
    } else if (userType == ResetUserType.guard && sid != null) {
      final last10 = guardResetPhoneLast10(identifier);
      if (last10 != null) {
        final guards = rowsOf(await db.from('guards').select('*').eq('society_id', sid));
        for (final g in guards) {
          final phone = (g['phone'] as String?) ?? '';
          final digits = phone.replaceAll(RegExp(r'\D'), '');
          final gl10 = digits.length > 10 ? digits.substring(digits.length - 10) : digits;
          if (phone.isNotEmpty && gl10 == last10) {
            user = g;
            break;
          }
        }
      } else {
        user = await _row(
            db.from('guards').select('*').eq('guard_id', identifier.toUpperCase()).eq('society_id', sid).maybeSingle());
      }
    } else {
      var q = db.from('admins').select('*').eq('admin_id', identifier.toUpperCase());
      if (sid != null) q = q.eq('society_id', sid);
      user = await _row(q.maybeSingle());
    }

    return user == null ? null : ResetAccount.fromRow(user);
  }

  /// Inserts the `password_reset_tokens` row (30 minute expiry) and asks the
  /// `send-reset-email` edge function to mail it. Returns the generated code.
  Future<String> createResetToken({
    required ResetUserType userType,
    required ResetAccount account,
  }) async {
    final code = generateResetCode();
    final expires = DateTime.now().add(const Duration(minutes: 30)).toUtc().toIso8601String();
    await db.from('password_reset_tokens').insert({
      'user_type': resetUserTypeKey(userType),
      'user_id': account.id,
      'email': account.email,
      'token': code,
      'expires_at': expires,
    });
    try {
      await invokeFunction('send-reset-email', {
        'email': account.email,
        'code': code,
        'name': account.name,
        'userType': resetUserTypeKey(userType),
      });
    } catch (_) {
      // Web `functions.invoke` resolves with `{ error }` instead of throwing, so the screen
      // reports "Reset code sent" either way; never reveal the code in the UI.
    }
    return code;
  }

  /// Web `verifyAndReset` after the client-side checks: validates the unused token,
  /// updates the password (all flat logins for residents), marks the token used and
  /// writes the `password_reset` audit row.
  Future<ResetTokenProblem?> resetPassword({
    required ResetUserType userType,
    required String userId,
    required String token,
    required String newPassword,
    required String identifier,
    String? societyId,
  }) async {
    final tokenData = await _row(db.from('password_reset_tokens').select('*').eq('token', token).eq('used', false).single());
    final expiresAt = DateTime.tryParse((tokenData?['expires_at'] as String?) ?? '');
    if (tokenData == null || expiresAt == null || expiresAt.isBefore(DateTime.now())) {
      return ResetTokenProblem.expiredOrInvalid;
    }

    switch (userType) {
      case ResetUserType.resident:
        final resUser = await _row(db.from('resident_users').select('flat_id').eq('id', userId).single());
        final flatId = resUser?['flat_id'] as String?;
        if (flatId != null) {
          await db.from('resident_users').update({'password': newPassword}).eq('flat_id', flatId);
        }
      case ResetUserType.guard:
        await db.from('guards').update({'password': newPassword}).eq('id', userId);
      case ResetUserType.admin:
        await db.from('admins').update({'password': newPassword}).eq('id', userId);
    }

    await db.from('password_reset_tokens').update({'used': true}).eq('id', tokenData['id'] as String);
    AuthAudit.passwordReset(resetUserTypeKey(userType), userId, identifier, 'email_reset', societyId: societyId);
    return null;
  }

  /// Web `askAdminToReset`: notification for the society's admins.
  Future<void> askAdminToReset({
    required ResetUserType userType,
    required ResetAccount account,
    required String identifier,
    String? societyId,
  }) async {
    var resolved = (societyId ?? '').isEmpty ? null : societyId;
    if (userType == ResetUserType.resident && resolved == null) {
      final resUser = await _row(db.from('resident_users').select('flat_id').eq('id', account.id).single());
      final flatId = resUser?['flat_id'] as String?;
      if (flatId != null) {
        final flat = await _row(db.from('flats').select('society_id').eq('id', flatId).single());
        resolved = flat?['society_id'] as String?;
      }
    }
    if (userType == ResetUserType.guard && resolved == null) {
      final g = await _row(db.from('guards').select('society_id').eq('id', account.id).single());
      resolved = g?['society_id'] as String?;
    }

    await db.from('notifications').insert({
      'title': '🔑 Password Reset Request',
      'message': buildResetRequestMessage(
        userName: account.name,
        userType: resetUserTypeKey(userType),
        flatNumber: account.flatNumber,
        identifier: identifier,
      ),
      'type': 'password_reset_request',
      'target_type': 'admin',
      'society_id': resolved,
    });
  }
}
