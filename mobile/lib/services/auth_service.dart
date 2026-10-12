import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/env.dart';
import '../core/supabase/supabase_bootstrap.dart';
import '../models/admin_user.dart';
import '../models/guard_session.dart';
import '../models/resident_user.dart';
import '../utils/phone_utils.dart';
import 'admin_permissions.dart';

class AuthFailure implements Exception {
  AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Password-based login mirroring web `UnifiedLoginPage.handleCredentialLogin`.
///
/// The `find*` methods return null when the web query returns no row (`maybeSingle()`
/// without data, including the "several rows" case); the older `login*` methods throw
/// [AuthFailure] instead and are kept for existing callers.
class AuthService {
  SupabaseClient get _db => SupabaseBootstrap.client;

  static AdminUser adminFromRow(Map<String, dynamic> map) => AdminUser(
        id: map['id'] as String,
        name: (map['name'] as String?) ?? '',
        adminId: map['admin_id'] as String,
        societyId: map['society_id'] as String?,
        permissions: AdminPanelPermissions.fromAdminJoin(map),
      );

  static GuardDbRow guardFromRow(Map<String, dynamic> map) => GuardDbRow(
        dbId: map['id'] as String,
        societyId: map['society_id'] as String?,
        session: GuardSession(
          guardId: map['guard_id'] as String,
          name: (map['name'] as String?) ?? '',
          password: (map['password'] as String?) ?? '',
        ),
      );

  /// Web `maybeSingle()` semantics: a PostgREST error (e.g. several rows) yields no data.
  /// Network errors still propagate so the UI can report a connection problem.
  static Future<Map<String, dynamic>?> _maybeRow(Future<Map<String, dynamic>?> query) async {
    try {
      final row = await query;
      return row == null ? null : Map<String, dynamic>.from(row);
    } on PostgrestException {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Unified login queries (web parity)
  // ---------------------------------------------------------------------------

  /// `admins.select('*, society_roles(permissions, slug, role_name)')` by upper-cased
  /// admin id + password + society.
  Future<AdminUser?> findAdminForLogin({
    required String societyId,
    required String adminId,
    required String password,
  }) async {
    if (!Env.isConfigured) return null;
    final row = await _maybeRow(_db
        .from('admins')
        .select('*, society_roles(permissions, slug, role_name)')
        .eq('admin_id', adminId.trim().toUpperCase())
        .eq('password', password)
        .eq('society_id', societyId)
        .maybeSingle());
    return row == null ? null : adminFromRow(row);
  }

  /// `guards.select('*')` by upper-cased guard id + password + society.
  Future<GuardDbRow?> findGuardForLogin({
    required String societyId,
    required String guardId,
    required String password,
  }) async {
    if (!Env.isConfigured) return null;
    final row = await _maybeRow(_db
        .from('guards')
        .select('*')
        .eq('guard_id', guardId.trim().toUpperCase())
        .eq('password', password)
        .eq('society_id', societyId)
        .maybeSingle());
    return row == null ? null : guardFromRow(row);
  }

  /// `resident_users` row for phone + password on the chosen flat.
  Future<ResidentUser?> findResidentForPassword({
    required String flatId,
    required String phone,
    required String password,
  }) async {
    if (!Env.isConfigured) return null;
    final row = await _maybeRow(_db
        .from('resident_users')
        .select('*')
        .eq('phone', phone)
        .eq('password', password)
        .eq('flat_id', flatId)
        .maybeSingle());
    return row == null ? null : ResidentUser.fromRow(row);
  }

  /// `resident_users.select('id, password')` for this phone on the flat (null when none).
  Future<({String id, String password})?> residentLoginOnFlat({
    required String flatId,
    required String phone,
  }) async {
    if (!Env.isConfigured) return null;
    final row = await _maybeRow(
        _db.from('resident_users').select('id, password').eq('flat_id', flatId).eq('phone', phone).maybeSingle());
    if (row == null) return null;
    return (id: row['id'] as String, password: (row['password'] as String?) ?? '');
  }

  /// True when any login of the flat uses this password (shared flat password).
  Future<bool> flatPasswordMatches({required String flatId, required String password}) async {
    if (!Env.isConfigured) return false;
    final row = await _maybeRow(
        _db.from('resident_users').select('id').eq('flat_id', flatId).eq('password', password).limit(1).maybeSingle());
    return row != null;
  }

  /// `flats.flat_number` for a flat id ('' when unknown).
  Future<String> fetchFlatNumber(String flatId) async {
    if (!Env.isConfigured) return '';
    final row = await _maybeRow(_db.from('flats').select('flat_number').eq('id', flatId).maybeSingle());
    return (row?['flat_number'] as String?) ?? '';
  }

  // ---------------------------------------------------------------------------
  // Older throwing API (kept for existing callers)
  // ---------------------------------------------------------------------------

  Future<ResidentUser> loginResident({
    required String societyId,
    required String flatId,
    required String identifier,
    required String password,
  }) async {
    if (!Env.isConfigured) {
      throw AuthFailure('Supabase not configured');
    }

    final id = normalizeLoginPhone(identifier);
    final resident = await findResidentForPassword(flatId: flatId, phone: id, password: password);
    if (resident != null) return resident;
    throw AuthFailure('Invalid phone or password');
  }

  Future<GuardSession> loginGuard({
    required String societyId,
    required String guardId,
    required String password,
  }) async {
    if (!Env.isConfigured) throw AuthFailure('Supabase not configured');
    final row = await findGuardForLogin(societyId: societyId, guardId: guardId, password: password);
    if (row == null) throw AuthFailure('Invalid guard ID or password');
    return row.session;
  }

  Future<AdminUser> loginAdmin({
    required String societyId,
    required String adminId,
    required String password,
  }) async {
    if (!Env.isConfigured) throw AuthFailure('Supabase not configured');
    final admin = await findAdminForLogin(societyId: societyId, adminId: adminId, password: password);
    if (admin == null) throw AuthFailure('Invalid admin ID or password');
    return admin;
  }

  Future<bool> validateResidentId(String residentId) async {
    if (!Env.isConfigured) return false;
    final row = await _db.from('resident_users').select('id').eq('id', residentId).maybeSingle();
    return row != null;
  }

  Future<bool> validateAdminId(String adminId) async {
    if (!Env.isConfigured) return false;
    final row = await _db.from('admins').select('id').eq('id', adminId).maybeSingle();
    return row != null;
  }

  Future<ResidentUser?> fetchResidentById(String id) async {
    if (!Env.isConfigured) return null;
    final row = await _maybeRow(_db.from('resident_users').select('*').eq('id', id).maybeSingle());
    if (row == null) return null;
    return ResidentUser.fromRow(row);
  }

  Future<String?> fetchFlatSocietyId(String flatId) async {
    if (!Env.isConfigured) return null;
    final row = await _maybeRow(_db.from('flats').select('society_id').eq('id', flatId).maybeSingle());
    return row?['society_id'] as String?;
  }

  Future<GuardDbRow?> fetchGuardByDbId(String dbId) async {
    if (!Env.isConfigured) return null;
    final row = await _maybeRow(_db.from('guards').select('*').eq('id', dbId).maybeSingle());
    if (row == null) return null;
    return guardFromRow(row);
  }

  Future<String?> fetchGuardDbId({
    required String societyId,
    required String guardId,
  }) async {
    if (!Env.isConfigured) return null;
    final row =
        await _maybeRow(_db.from('guards').select('id').eq('guard_id', guardId).eq('society_id', societyId).maybeSingle());
    return row?['id'] as String?;
  }

  Future<AdminUser?> fetchAdminById(String id) async {
    if (!Env.isConfigured) return null;
    final row =
        await _maybeRow(_db.from('admins').select('*, society_roles(permissions, slug, role_name)').eq('id', id).maybeSingle());
    if (row == null) return null;
    return adminFromRow(row);
  }
}

class GuardDbRow {
  const GuardDbRow({
    required this.dbId,
    required this.societyId,
    required this.session,
  });

  final String dbId;
  final String? societyId;
  final GuardSession session;
}
