import 'package:flutter/widgets.dart';

import '../../models/session_models.dart';
import 'data/superadmin_models.dart';
import 'data/superadmin_repository.dart';

/// Shared console state — the web `SuperadminDashboard` keeps `societies`, `roles`,
/// `admins` and `selectedSociety` at the top level and every tab reads them.
class SuperadminConsole extends ChangeNotifier {
  SuperadminConsole({required this.session, this.repo = const SuperadminRepository()});

  final SessionSuperadmin session;
  final SuperadminRepository repo;

  List<SocietyRow> societies = const [];
  List<SocietyRoleRow> roles = const [];
  List<AdminRow> admins = const [];

  /// Web `selectedSociety` (dropdown above the tabs).
  String selectedSocietyId = '';

  bool loaded = false;
  bool loading = false;
  bool loadFailed = false;
  bool _disposed = false;

  /// Web `loadAll()`: societies / roles / admins in parallel; a failed query keeps the old list.
  Future<void> loadAll() async {
    loading = true;
    _notify();
    final d = await repo.loadAll();
    if (_disposed) return;
    if (d.societies != null) societies = d.societies!;
    if (d.roles != null) roles = d.roles!;
    if (d.admins != null) admins = d.admins!;
    loadFailed = d.societies == null && d.roles == null && d.admins == null;
    if (societies.isEmpty) {
      selectedSocietyId = '';
    } else if (selectedSocietyId.isEmpty || !societies.any((s) => s.id == selectedSocietyId)) {
      selectedSocietyId = societies.first.id;
    }
    loaded = true;
    loading = false;
    _notify();
  }

  void selectSociety(String id) {
    if (id == selectedSocietyId) return;
    selectedSocietyId = id;
    _notify();
  }

  SocietyRow? societyById(String? id) {
    if (id == null) return null;
    for (final s in societies) {
      if (s.id == id) return s;
    }
    return null;
  }

  SocietyRow? get selectedSociety => societyById(selectedSocietyId);

  SocietyRoleRow? roleById(String? id) {
    if (id == null) return null;
    for (final r in roles) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Web `roles.filter(r => r.society_id === id)`.
  List<SocietyRoleRow> rolesFor(String? societyId) =>
      roles.where((r) => societyId != null && r.societyId == societyId).toList();

  /// Web `filteredAdmins` (all admins when no society is selected).
  List<AdminRow> adminsFor(String? societyId) =>
      (societyId == null || societyId.isEmpty) ? admins : admins.where((a) => a.societyId == societyId).toList();

  int adminsUsingRole(String roleId) => admins.where((a) => a.roleId == roleId).length;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Makes the [SuperadminConsole] available to the tabs below the shell.
class SuperadminScope extends InheritedNotifier<SuperadminConsole> {
  const SuperadminScope({super.key, required SuperadminConsole console, required super.child}) : super(notifier: console);

  /// Rebuilds the caller when the console changes.
  static SuperadminConsole of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SuperadminScope>()!.notifier!;

  /// Reads without subscribing (callbacks).
  static SuperadminConsole read(BuildContext context) =>
      (context.getElementForInheritedWidgetOfExactType<SuperadminScope>()!.widget as SuperadminScope).notifier!;
}
