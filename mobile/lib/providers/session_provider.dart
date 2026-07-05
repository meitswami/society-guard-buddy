import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/session/app_session.dart';
import '../models/admin_user.dart';
import '../models/guard_session.dart';
import '../models/resident_user.dart';
import '../models/session_models.dart';
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
      await ref.read(pushNotificationServiceProvider).registerForSession(session);
      return session;
    }

    if (role == 'admin' && societyId != null) {
      final adminJson = raw['admin'] as Map<String, dynamic>?;
      if (adminJson == null) return const SessionUnauthenticated();
      final admin = AdminUser.fromJson(adminJson);
      final valid = await ref.read(authServiceProvider).validateAdminId(admin.id);
      if (!valid) {
        await AppSession.clear();
        return const SessionUnauthenticated();
      }
      final societyName = await _societyName(societyId);
      final session = SessionAdmin(
        societyId: societyId,
        societyName: societyName,
        admin: admin,
      );
      await ref.read(pushNotificationServiceProvider).registerForSession(session);
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
      await ref.read(pushNotificationServiceProvider).registerForSession(session);
      return session;
    }

    return const SessionUnauthenticated();
  }

  Future<String> _societyName(String societyId) async {
    final societies = await ref.read(societyServiceProvider).fetchActiveSocieties();
    return societies
        .where((s) => s.id == societyId)
        .map((s) => s.name)
        .firstOrNull ?? 'Your Society';
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

  Future<void> logout({String? guardShiftId}) async {
    if (guardShiftId != null) {
      await ref.read(guardSessionServiceProvider).endShift(guardShiftId);
    } else {
      await AppSession.clear();
    }
    state = const AsyncData(SessionUnauthenticated());
  }
}
