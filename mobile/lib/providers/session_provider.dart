import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/env.dart';
import '../core/session/app_session.dart';
import '../core/supabase/supabase_bootstrap.dart';
import '../models/admin_user.dart';
import '../models/guard_session.dart';
import '../models/resident_user.dart';
import '../models/session_models.dart';
import '../services/admin_permissions.dart';
import '../services/auth_service.dart';
import '../services/guard_session_service.dart';
import '../services/push_notification_service.dart';
import '../services/society_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final guardSessionServiceProvider =
    Provider<GuardSessionService>((ref) => GuardSessionService());
final societyServiceProvider = Provider<SocietyService>((ref) => SocietyService());
final pushNotificationServiceProvider =
    Provider<PushNotificationService>((ref) => PushNotificationService());

final sessionProvider =
    AsyncNotifierProvider<SessionNotifier, AppSessionState>(SessionNotifier.new);

class SessionNotifier extends AsyncNotifier<AppSessionState> {
  @override
  Future<AppSessionState> build() async {
    return _restore();
  }

  Future<AppSessionState> _restore() async {
    final raw = await AppSession.read();
    if (raw == null) return const SessionUnauthenticated();

    final role = raw['role'] as String?;
    final societyId = raw['societyId'] as String?;

    if (role == 'resident' && societyId != null) {
      final residentJson = raw['resident'] as Map<String, dynamic>?;
      if (residentJson == null) return const SessionUnauthenticated();
      final resident = ResidentUser.fromJson(residentJson);
      final valid = await ref.read(authServiceProvider).validateResidentId(resident.id);
      if (!valid) {
        await AppSession.clear();
        return const SessionUnauthenticated();
      }
      final societyName = await _societyName(societyId);
      final session = SessionResident(
        societyId: societyId,
        societyName: societyName,
        resident: resident,
      );
      // Push registration must not delay first authenticated frame.
      unawaited(ref.read(pushNotificationServiceProvider).registerForSession(session));
      return session;
    }

    if (role == 'superadmin') {
      final sa = raw['superadmin'] as Map<String, dynamic>?;
      final id = sa?['id'] as String?;
      if (sa == null || id == null) return const SessionUnauthenticated();
      if (Env.isConfigured) {
        try {
          final row = await SupabaseBootstrap.client.from('super_admins').select('id').eq('id', id).maybeSingle();
          if (row == null) {
            await AppSession.clear();
            return const SessionUnauthenticated();
          }
        } catch (_) {
          // Offline: keep the stored session (same as other roles' validation failures being network-only).
        }
      }
      return SessionSuperadmin(
        id: id,
        name: (sa['name'] as String?) ?? '',
        username: (sa['username'] as String?) ?? '',
      );
    }

    if (role == 'admin' && societyId != null) {
      final adminJson = raw['admin'] as Map<String, dynamic>?;
      if (adminJson == null) return const SessionUnauthenticated();
      var admin = AdminUser.fromJson(adminJson);
      final valid = await ref.read(authServiceProvider).validateAdminId(admin.id);
      if (!valid) {
        await AppSession.clear();
        return const SessionUnauthenticated();
      }
      // Like web: re-read role permissions on restore so changes by the superadmin apply.
      admin = await _refreshAdminPermissions(admin);
      await AppSession.write({'role': 'admin', 'societyId': societyId, 'admin': admin.toJson()});
      final societyName = await _societyName(societyId);
      final session = SessionAdmin(
        societyId: societyId,
        societyName: societyName,
        admin: admin,
      );
      unawaited(ref.read(pushNotificationServiceProvider).registerForSession(session));
      return session;
    }

    if (role == 'guard' && societyId != null) {
      final shiftId = raw['shiftId'] as String?;
      final guardId = raw['guardId'] as String?;
      if (shiftId == null || guardId == null) {
        return const SessionUnauthenticated();
      }
      final guard = await ref.read(guardSessionServiceProvider).restoreSession(
            societyId: societyId,
            shiftId: shiftId,
            guardId: guardId,
          );
      if (guard == null) {
        await AppSession.clear();
        return const SessionUnauthenticated();
      }
      final societyName = await _societyName(societyId);
      final session = SessionGuard(
        societyId: societyId,
        societyName: societyName,
        guard: guard,
        shiftId: shiftId,
      );
      unawaited(ref.read(pushNotificationServiceProvider).registerForSession(session));
      return session;
    }

    return const SessionUnauthenticated();
  }

  Future<AdminUser> _refreshAdminPermissions(AdminUser admin) async {
    if (!Env.isConfigured) return admin;
    try {
      final row = await SupabaseBootstrap.client
          .from('admins')
          .select('*, society_roles(permissions, slug, role_name)')
          .eq('id', admin.id)
          .maybeSingle();
      if (row == null) return admin;
      return AdminUser(
        id: admin.id,
        name: (row['name'] as String?) ?? admin.name,
        adminId: (row['admin_id'] as String?) ?? admin.adminId,
        societyId: (row['society_id'] as String?) ?? admin.societyId,
        permissions: AdminPanelPermissions.fromAdminJoin(row),
      );
    } catch (_) {
      return admin;
    }
  }

  Future<String> _societyName(String societyId) async {
    if (!Env.isConfigured) return 'Your Society';
    try {
      final row = await SupabaseBootstrap.client
          .from('societies')
          .select('name')
          .eq('id', societyId)
          .maybeSingle();
      final name = row?['name'] as String?;
      if (name != null && name.isNotEmpty) return name;
    } catch (_) {}
    return 'Your Society';
  }

  Future<void> loginResident({
    required String societyId,
    required String societyName,
    required ResidentUser resident,
  }) async {
    await AppSession.write({
      'role': 'resident',
      'societyId': societyId,
      'resident': resident.toJson(),
    });
    final session = SessionResident(
      societyId: societyId,
      societyName: societyName,
      resident: resident,
    );
    state = AsyncData(session);
    await ref.read(pushNotificationServiceProvider).registerForSession(session);
  }

  Future<void> loginAdmin({
    required String societyId,
    required String societyName,
    required AdminUser admin,
  }) async {
    await AppSession.write({
      'role': 'admin',
      'societyId': societyId,
      'admin': admin.toJson(),
    });
    final session = SessionAdmin(
      societyId: societyId,
      societyName: societyName,
      admin: admin,
    );
    state = AsyncData(session);
    await ref.read(pushNotificationServiceProvider).registerForSession(session);
  }

  Future<void> loginGuard({
    required String societyId,
    required String societyName,
    required GuardSession guard,
    required String shiftId,
  }) async {
    final session = SessionGuard(
      societyId: societyId,
      societyName: societyName,
      guard: guard,
      shiftId: shiftId,
    );
    state = AsyncData(session);
    await ref.read(pushNotificationServiceProvider).registerForSession(session);
  }

  /// Superadmin console login (web `writePersistedSession({ role: 'superadmin', superadmin })`).
  Future<void> loginSuperadmin({required String id, required String name, required String username}) async {
    await AppSession.write({
      'role': 'superadmin',
      'superadmin': {'id': id, 'name': name, 'username': username},
    });
    state = AsyncData(SessionSuperadmin(id: id, name: name, username: username));
  }

  Future<void> logout({String? guardShiftId}) async {
    if (guardShiftId != null) {
      await ref.read(guardSessionServiceProvider).endShift(guardShiftId);
    } else {
      await AppSession.clear();
    }
    state = const AsyncData(SessionUnauthenticated());
  }
}
