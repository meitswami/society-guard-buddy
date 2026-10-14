import '../../models/session_models.dart';

/// Who is operating a gate screen (visitor / delivery / vehicle / quick entry …).
/// The web app reuses guard pages inside the admin panel, so these screens take a
/// [GateActor] instead of a guard session.
class GateActor {
  const GateActor({
    required this.societyId,
    required this.societyName,
    required this.actorId,
    required this.actorName,
    required this.role,
    this.shiftId,
  });

  final String societyId;
  final String societyName;
  /// Guard code (e.g. `G001`) for guards, admin id for admins — stored in `guard_id` columns.
  final String actorId;
  final String actorName;
  final String role; // 'guard' | 'admin'
  final String? shiftId;

  bool get isGuard => role == 'guard';

  factory GateActor.fromGuard(SessionGuard s) => GateActor(
        societyId: s.societyId,
        societyName: s.societyName,
        actorId: s.guard.guardId,
        actorName: s.guard.name,
        role: 'guard',
        shiftId: s.shiftId,
      );

  factory GateActor.fromAdmin(SessionAdmin s) => GateActor(
        societyId: s.societyId,
        societyName: s.societyName,
        actorId: s.admin.adminId,
        actorName: s.admin.name,
        role: 'admin',
      );
}
