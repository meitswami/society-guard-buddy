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
}

/// Password-based login mirroring web `UnifiedLoginPage.handleCredentialLogin`.
class AuthService {
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
    final client = SupabaseBootstrap.client;

    final resident = await client
        .from('resident_users')
        .select('*')
        .eq('phone', id)
        .eq('password', password)
        .eq('flat_id', flatId)
        .maybeSingle();

    if (resident != null) {
      return ResidentUser.fromRow(Map<String, dynamic>.from(resident));
    }

    final phoneOnFlat = await client
        .from('resident_users')
        .select('id, password')
        .eq('flat_id', flatId)
        .eq('phone', id)
        .maybeSingle();

    if (phoneOnFlat != null && phoneOnFlat['password'] != password) {
      throw AuthFailure('Invalid phone or password');
    }

    final flatPassword = await client
        .from('resident_users')
        .select('id')
        .eq('flat_id', flatId)
        .eq('password', password)
        .limit(1)
        .maybeSingle();

    if (flatPassword != null) {
      throw AuthFailure('Invalid phone or password');
    }

    throw AuthFailure('Invalid phone or password');
  }

  Future<GuardSession> loginGuard({
    required String societyId,
    required String guardId,
    required String password,
  }) async {
    if (!Env.isConfigured) throw AuthFailure('Supabase not configured');

    final row = await SupabaseBootstrap.client
        .from('guards')
        .select('*')
        .eq('guard_id', guardId.trim().toUpperCase())
        .eq('password', password)
        .eq('society_id', societyId)
        .maybeSingle();

    if (row == null) throw AuthFailure('Invalid guard ID or password');

    final map = Map<String, dynamic>.from(row);
    return GuardSession(
      guardId: map['guard_id'] as String,
      name: map['name'] as String,
      password: map['password'] as String,
    );
  }

  Future<AdminUser> loginAdmin({
    required String societyId,
    required String adminId,
    required String password,
  }) async {
    if (!Env.isConfigured) throw AuthFailure('Supabase not configured');

    final row = await SupabaseBootstrap.client
        .from('admins')
        .select('*, society_roles(permissions, slug, role_name)')
        .eq('admin_id', adminId.trim().toUpperCase())
        .eq('password', password)
        .eq('society_id', societyId)
        .maybeSingle();

    if (row == null) throw AuthFailure('Invalid admin ID or password');

    final map = Map<String, dynamic>.from(row);
    return AdminUser(
      id: map['id'] as String,
      name: map['name'] as String,
      adminId: map['admin_id'] as String,
      societyId: map['society_id'] as String?,
      permissions: AdminPanelPermissions.fromAdminJoin(map),
    );
  }

  Future<bool> validateResidentId(String residentId) async {
    if (!Env.isConfigured) return false;
    final row = await SupabaseBootstrap.client
        .from('resident_users')
        .select('id')
        .eq('id', residentId)
        .maybeSingle();
    return row != null;
  }

  Future<bool> validateAdminId(String adminId) async {
    if (!Env.isConfigured) return false;
    final row = await SupabaseBootstrap.client
        .from('admins')
        .select('id')
        .eq('id', adminId)
        .maybeSingle();
    return row != null;
  }

  Future<ResidentUser?> fetchResidentById(String id) async {
    if (!Env.isConfigured) return null;
    final row = await SupabaseBootstrap.client
        .from('resident_users')
        .select('*')
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return ResidentUser.fromRow(Map<String, dynamic>.from(row));
  }

  Future<String?> fetchFlatSocietyId(String flatId) async {
    if (!Env.isConfigured) return null;
    final row = await SupabaseBootstrap.client
        .from('flats')
        .select('society_id')
        .eq('id', flatId)
        .maybeSingle();
    return row?['society_id'] as String?;
  }

  Future<GuardDbRow?> fetchGuardByDbId(String dbId) async {
    if (!Env.isConfigured) return null;
    final row = await SupabaseBootstrap.client
        .from('guards')
        .select('*')
        .eq('id', dbId)
        .maybeSingle();
    if (row == null) return null;
    final map = Map<String, dynamic>.from(row);
    return GuardDbRow(
      dbId: map['id'] as String,
      societyId: map['society_id'] as String?,
      session: GuardSession(
        guardId: map['guard_id'] as String,
        name: map['name'] as String,
        password: map['password'] as String,
      ),
    );
  }

  Future<String?> fetchGuardDbId({
    required String societyId,
    required String guardId,
  }) async {
    if (!Env.isConfigured) return null;
    final row = await SupabaseBootstrap.client
        .from('guards')
        .select('id')
        .eq('guard_id', guardId)
        .eq('society_id', societyId)
        .maybeSingle();
    return row?['id'] as String?;
  }

  Future<AdminUser?> fetchAdminById(String id) async {
    if (!Env.isConfigured) return null;
    final row = await SupabaseBootstrap.client
        .from('admins')
        .select('*, society_roles(permissions, slug, role_name)')
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    final map = Map<String, dynamic>.from(row);
    return AdminUser(
      id: map['id'] as String,
      name: map['name'] as String,
      adminId: map['admin_id'] as String,
      societyId: map['society_id'] as String?,
      permissions: AdminPanelPermissions.fromAdminJoin(map),
    );
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
