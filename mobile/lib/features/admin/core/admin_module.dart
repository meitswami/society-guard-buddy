import 'package:flutter/widgets.dart';

import '../../../core/session/gate_actor.dart';
import '../../../models/session_models.dart';

/// Admin panel modules — same ids as the web `AdminTab` (`src/lib/adminPermissions.ts`).
enum AdminTab {
  overview,
  guards,
  residents,
  geofence,
  password,
  biometric,
  audit,
  finance,
  fixedAssets,
  donations,
  events,
  meetings,
  documents,
  committee,
  polls,
  parking,
  splits,
  notifications,
  visitor,
  delivery,
  vehicle,
  blacklist,
  directory,
  quick,
  report,
  logs,
  settings,
  tour,
}

/// Everything an admin module screen needs. Every admin module entry widget has the
/// constructor `const XxxModule({super.key, required this.ctx})`.
class AdminModuleContext {
  const AdminModuleContext({
    required this.session,
    required this.goTo,
    this.initialQuery,
    this.subTab,
  });

  final SessionAdmin session;

  /// Switch to another admin module (optionally pre-filling its search or sub-tab),
  /// like the web `goToTab(tab, { query, financeSubTab })`.
  final void Function(AdminTab tab, {String? query, String? subTab}) goTo;

  /// Search text handed over from the admin global search.
  final String? initialQuery;

  /// Sub-tab requested by another module (e.g. finance `receipts`).
  final String? subTab;

  String get societyId => session.societyId;
  String get societyName => session.societyName;
  String get adminId => session.admin.id;
  String get adminName => session.admin.name;

  GateActor get gateActor => GateActor.fromAdmin(session);
}

/// Signature every admin module registers with the shell.
typedef AdminModuleBuilder = Widget Function(AdminModuleContext ctx);
