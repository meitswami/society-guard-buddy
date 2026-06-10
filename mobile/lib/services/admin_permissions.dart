/// Port of `src/lib/adminPermissions.ts`.
class AdminPanelPermissions {
  const AdminPanelPermissions({
    this.residentsRw = true,
    this.guardsRw = true,
    this.geofenceRw = true,
    this.finance = true,
    this.donations = true,
    this.splits = true,
    this.events = true,
    this.meetings = true,
    this.committee = true,
    this.polls = true,
    this.notifications = true,
    this.parking = true,
    this.visitor = true,
    this.delivery = true,
    this.vehicle = true,
    this.blacklist = true,
    this.directory = true,
    this.quick = true,
    this.report = true,
    this.logs = true,
    this.audit = true,
    this.settings = true,
    this.password = true,
    this.biometric = true,
  });

  final bool residentsRw;
  final bool guardsRw;
  final bool geofenceRw;
  final bool finance;
  final bool donations;
  final bool splits;
  final bool events;
  final bool meetings;
  final bool committee;
  final bool polls;
  final bool notifications;
  final bool parking;
  final bool visitor;
  final bool delivery;
  final bool vehicle;
  final bool blacklist;
  final bool directory;
  final bool quick;
  final bool report;
  final bool logs;
  final bool audit;
  final bool settings;
  final bool password;
  final bool biometric;

  static const full = AdminPanelPermissions();

  Map<String, dynamic> toJson() => {
        'residents_rw': residentsRw,
        'guards_rw': guardsRw,
        'geofence_rw': geofenceRw,
        'finance': finance,
        'donations': donations,
        'splits': splits,
        'events': events,
        'meetings': meetings,
        'committee': committee,
        'polls': polls,
        'notifications': notifications,
        'parking': parking,
        'visitor': visitor,
        'delivery': delivery,
        'vehicle': vehicle,
        'blacklist': blacklist,
        'directory': directory,
        'quick': quick,
        'report': report,
        'logs': logs,
        'audit': audit,
        'settings': settings,
        'password': password,
        'biometric': biometric,
      };

  factory AdminPanelPermissions.fromJson(Map<String, dynamic>? json) {
    if (json == null) return AdminPanelPermissions.full;
    bool b(String k, bool fallback) =>
        json[k] is bool ? json[k] as bool : fallback;
    return AdminPanelPermissions(
      residentsRw: b('residents_rw', false),
      guardsRw: b('guards_rw', false),
      geofenceRw: b('geofence_rw', false),
      finance: b('finance', false),
      donations: b('donations', false),
      splits: b('splits', false),
      events: b('events', false),
      meetings: b('meetings', false),
      committee: b('committee', false),
      polls: b('polls', false),
      notifications: b('notifications', false),
      parking: b('parking', false),
      visitor: b('visitor', false),
      delivery: b('delivery', false),
      vehicle: b('vehicle', false),
      blacklist: b('blacklist', false),
      directory: b('directory', true),
      quick: b('quick', false),
      report: b('report', false),
      logs: b('logs', false),
      audit: b('audit', false),
      settings: b('settings', false),
      password: b('password', true),
      biometric: b('biometric', true),
    );
  }

  static AdminPanelPermissions fromAdminJoin(Map<String, dynamic> row) {
    final roleId = row['role_id'];
    if (roleId == null) return AdminPanelPermissions.full;
    final rel = row['society_roles'];
    final sr = rel is List ? (rel.isNotEmpty ? rel.first : null) : rel;
    if (sr is! Map || !sr.containsKey('permissions')) {
      return AdminPanelPermissions.full;
    }
    final perms = sr['permissions'];
    if (perms == null) return AdminPanelPermissions.full;
    if (perms is Map<String, dynamic>) {
      return AdminPanelPermissions.fromJson(perms);
    }
    return AdminPanelPermissions.full;
  }
}
