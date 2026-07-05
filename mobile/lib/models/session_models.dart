import 'admin_user.dart';
import 'guard_session.dart';
import 'resident_user.dart';

enum AppRole { guard, resident, admin, superadmin }

sealed class AppSessionState {
  const AppSessionState();
}

class SessionLoading extends AppSessionState {
  const SessionLoading();
}

class SessionUnauthenticated extends AppSessionState {
  const SessionUnauthenticated();
}

class SessionGuard extends AppSessionState {
  const SessionGuard({
    required this.societyId,
    required this.societyName,
    required this.guard,
    required this.shiftId,
  });

  final String societyId;
  final String societyName;
  final GuardSession guard;
  final String shiftId;
}

class SessionResident extends AppSessionState {
  const SessionResident({
    required this.societyId,
    required this.societyName,
    required this.resident,
  });

  final String societyId;
  final String societyName;
  final ResidentUser resident;
}

class SessionAdmin extends AppSessionState {
  const SessionAdmin({
    required this.societyId,
    required this.societyName,
    required this.admin,
  });

  final String societyId;
  final String societyName;
  final AdminUser admin;
}

class SessionSuperadmin extends AppSessionState {
  const SessionSuperadmin({
    required this.id,
    required this.name,
    required this.username,
  });

  final String id;
  final String name;
  final String username;
}
