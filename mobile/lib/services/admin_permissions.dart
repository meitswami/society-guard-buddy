/// Port of `src/lib/adminPermissions.ts` (feature flags stored on `society_roles.permissions`).
class AdminPanelPermissions {
  const AdminPanelPermissions({
    this.residentsRw = true,
    this.guardsRw = true,
    this.geofenceRw = true,
    this.finance = true,
    this.fixedAssets = true,
    this.donations = true,
    this.splits = true,
    this.events = true,
    this.meetings = true,
    this.documents = true,
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
  final bool fixedAssets;
  final bool donations;
  final bool splits;
  final bool events;
  final bool meetings;
  final bool documents;
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

  /// Web `FULL_ADMIN_PERMISSIONS` (admins without a role).
  static const full = AdminPanelPermissions();

  /// Web `NEW_CUSTOM_ROLE_PERMISSIONS` (new roles start locked down).
  static const newCustomRole = AdminPanelPermissions(
    residentsRw: false,
    guardsRw: false,
    geofenceRw: false,
    finance: true,
    fixedAssets: false,
    donations: false,
    splits: false,
    events: false,
    meetings: false,
    documents: false,
    committee: false,
    polls: false,
    notifications: false,
    parking: false,
    visitor: false,
    delivery: false,
    vehicle: false,
    blacklist: false,
    directory: true,
    quick: false,
    report: false,
    logs: false,
    audit: false,
    settings: false,
    password: true,
    biometric: true,
  );

  static const keys = [
    'residents_rw', 'guards_rw', 'geofence_rw', 'finance', 'fixed_assets', 'donations', 'splits', 'events',
    'meetings', 'documents', 'committee', 'polls', 'notifications', 'parking', 'visitor', 'delivery', 'vehicle',
    'blacklist', 'directory', 'quick', 'report', 'logs', 'audit', 'settings', 'password', 'biometric',
  ];

  Map<String, bool> toJson() => {
        'residents_rw': residentsRw,
        'guards_rw': guardsRw,
        'geofence_rw': geofenceRw,
        'finance': finance,
        'fixed_assets': fixedAssets,
        'donations': donations,
        'splits': splits,
        'events': events,
        'meetings': meetings,
        'documents': documents,
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

  bool flag(String key) => toJson()[key] ?? false;

  /// Web `mergeRolePermissions`: no boolean keys → locked-down custom role;
  /// otherwise full access overridden by the stored booleans.
  factory AdminPanelPermissions.fromJson(Map<String, dynamic>? json) {
    if (json == null) return AdminPanelPermissions.full;
    final hasBool = json.values.any((v) => v is bool);
    if (!hasBool) return AdminPanelPermissions.newCustomRole;
    bool b(String k) => json[k] is bool ? json[k] as bool : true;
    return AdminPanelPermissions(
      residentsRw: b('residents_rw'),
      guardsRw: b('guards_rw'),
      geofenceRw: b('geofence_rw'),
      finance: b('finance'),
      fixedAssets: b('fixed_assets'),
      donations: b('donations'),
      splits: b('splits'),
      events: b('events'),
      meetings: b('meetings'),
      documents: b('documents'),
      committee: b('committee'),
      polls: b('polls'),
      notifications: b('notifications'),
      parking: b('parking'),
      visitor: b('visitor'),
      delivery: b('delivery'),
      vehicle: b('vehicle'),
      blacklist: b('blacklist'),
      directory: b('directory'),
      quick: b('quick'),
      report: b('report'),
      logs: b('logs'),
      audit: b('audit'),
      settings: b('settings'),
      password: b('password'),
      biometric: b('biometric'),
    );
  }

  /// Web `permissionsFromAdminJoin`: admins with no `role_id` get full access (legacy).
  static AdminPanelPermissions fromAdminJoin(Map<String, dynamic> row) {
    final roleId = row['role_id'];
    if (roleId == null) return AdminPanelPermissions.full;
    final rel = row['society_roles'];
    final sr = rel is List ? (rel.isNotEmpty ? rel.first : null) : rel;
    if (sr is! Map || !sr.containsKey('permissions')) return AdminPanelPermissions.full;
    final perms = sr['permissions'];
    if (perms == null) return AdminPanelPermissions.full;
    if (perms is Map) return AdminPanelPermissions.fromJson(Map<String, dynamic>.from(perms));
    return AdminPanelPermissions.full;
  }
}
