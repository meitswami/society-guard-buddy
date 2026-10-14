/// Complete port of `src/lib/adminPermissions.ts` (`AdminPanelPermissions`,
/// `NEW_CUSTOM_ROLE_PERMISSIONS`, `FULL_ADMIN_PERMISSIONS`, `mergeRolePermissions`,
/// `permissionsFromAdminJoin`, `isAdminTabAllowed`) including the `fixed_assets`
/// and `documents` keys, plus the seeded role templates used by the
/// `phonepe-callback` edge function. Used by the Superadmin permission matrix.
library;

/// One flag on `society_roles.permissions` — same keys and order as the web type.
enum AdminPerm {
  residentsRw('residents_rw'),
  guardsRw('guards_rw'),
  geofenceRw('geofence_rw'),
  finance('finance'),
  fixedAssets('fixed_assets'),
  donations('donations'),
  splits('splits'),
  events('events'),
  meetings('meetings'),
  documents('documents'),
  committee('committee'),
  polls('polls'),
  notifications('notifications'),
  parking('parking'),
  visitor('visitor'),
  delivery('delivery'),
  vehicle('vehicle'),
  blacklist('blacklist'),
  directory('directory'),
  quick('quick'),
  report('report'),
  logs('logs'),
  audit('audit'),
  settings('settings'),
  password('password'),
  biometric('biometric');

  const AdminPerm(this.key);

  /// JSON key stored in `society_roles.permissions`.
  final String key;

  static AdminPerm? fromKey(String key) {
    for (final p in AdminPerm.values) {
      if (p.key == key) return p;
    }
    return null;
  }
}

/// Immutable permission set (every key always present).
class RolePermissions {
  RolePermissions._(Map<AdminPerm, bool> values)
      : _values = Map.unmodifiable(values);

  factory RolePermissions.fromMap(Map<AdminPerm, bool> values) =>
      RolePermissions._(
          {for (final p in AdminPerm.values) p: values[p] ?? false});

  factory RolePermissions.all(bool value) =>
      RolePermissions._({for (final p in AdminPerm.values) p: value});

  final Map<AdminPerm, bool> _values;

  bool operator [](AdminPerm p) => _values[p] ?? false;

  RolePermissions withValue(AdminPerm p, bool value) =>
      RolePermissions._({..._values, p: value});

  /// Explicit JSON with every key (what the matrix editor writes to the DB).
  Map<String, bool> toJson() =>
      {for (final p in AdminPerm.values) p.key: this[p]};

  int get enabledCount => AdminPerm.values.where((p) => this[p]).length;

  bool sameAs(RolePermissions other) =>
      AdminPerm.values.every((p) => this[p] == other[p]);

  /// Web `FULL_ADMIN_PERMISSIONS`.
  static final RolePermissions full = RolePermissions.all(true);

  /// Web `NEW_CUSTOM_ROLE_PERMISSIONS` — roles created from Superadmin "Add" start locked down.
  static final RolePermissions newCustom = RolePermissions.fromMap(const {
    AdminPerm.finance: true,
    AdminPerm.directory: true,
    AdminPerm.password: true,
    AdminPerm.biometric: true,
  });

  /// Web `mergeRolePermissions(raw)`:
  /// - not an object → full access;
  /// - object without any boolean value → the locked-down new-role default;
  /// - otherwise full access overridden by every known boolean key.
  static RolePermissions merge(Object? raw) {
    // JS arrays are objects too: no boolean entries → locked default, otherwise full.
    if (raw is List) return raw.any((e) => e is bool) ? full : newCustom;
    if (raw is! Map) return full;
    final boolKeys = raw.entries.where((e) => e.value is bool).toList();
    if (boolKeys.isEmpty) return newCustom;
    final out = <AdminPerm, bool>{for (final p in AdminPerm.values) p: true};
    for (final p in AdminPerm.values) {
      final v = raw[p.key];
      if (v is bool) out[p] = v;
    }
    return RolePermissions._(out);
  }

  /// Web `permissionsFromAdminJoin(row)` — admins with no role get full (legacy) access.
  static RolePermissions fromAdminJoin({Object? roleId, Object? societyRoles}) {
    if (roleId == null || (roleId is String && roleId.isEmpty)) return full;
    final rel = societyRoles;
    final sr = rel is List ? (rel.isEmpty ? null : rel.first) : rel;
    if (sr is! Map || !sr.containsKey('permissions')) return full;
    final perms = sr['permissions'];
    if (perms == null) return full;
    return merge(perms);
  }
}

/// Web `AdminTab` ids (`overview`, `fixed_assets`, …) → the permission that gates them.
const Map<String, AdminPerm?> kAdminTabPermission = {
  'overview': null,
  'tour': null,
  'guards': AdminPerm.guardsRw,
  'residents': AdminPerm.residentsRw,
  'geofence': AdminPerm.geofenceRw,
  'password': AdminPerm.password,
  'biometric': AdminPerm.biometric,
  'audit': AdminPerm.audit,
  'finance': AdminPerm.finance,
  'fixed_assets': AdminPerm.fixedAssets,
  'donations': AdminPerm.donations,
  'events': AdminPerm.events,
  'meetings': AdminPerm.meetings,
  'documents': AdminPerm.documents,
  'committee': AdminPerm.committee,
  'polls': AdminPerm.polls,
  'parking': AdminPerm.parking,
  'splits': AdminPerm.splits,
  'notifications': AdminPerm.notifications,
  'visitor': AdminPerm.visitor,
  'delivery': AdminPerm.delivery,
  'vehicle': AdminPerm.vehicle,
  'blacklist': AdminPerm.blacklist,
  'directory': AdminPerm.directory,
  'quick': AdminPerm.quick,
  'report': AdminPerm.report,
  'logs': AdminPerm.logs,
  'settings': AdminPerm.settings,
};

/// Web `isAdminTabAllowed(tab, p)` — `splits` is also reachable with `events`.
bool isAdminTabAllowed(String tab, RolePermissions p) {
  if (tab == 'splits') return p[AdminPerm.events] || p[AdminPerm.splits];
  if (!kAdminTabPermission.containsKey(tab)) return false;
  final key = kAdminTabPermission[tab];
  if (key == null) return true;
  return p[key];
}

/// Admin tabs a role can open (overview / tour always included), in web order.
List<String> allowedAdminTabs(RolePermissions p) =>
    kAdminTabPermission.keys.where((tab) => isAdminTabAllowed(tab, p)).toList();

/// A preset shown in the permission matrix editor.
class RoleTemplate {
  const RoleTemplate(
      {required this.slug,
      required this.nameEn,
      required this.nameHi,
      required this.keys});

  final String slug;
  final String nameEn;
  final String nameHi;

  /// Keys that are `true` (all others `false`).
  final Set<AdminPerm> keys;

  RolePermissions get permissions =>
      RolePermissions.fromMap({for (final k in keys) k: true});
}

/// Seeded roles exactly as `supabase/functions/phonepe-callback` provisions them.
final List<RoleTemplate> kSeededRoleTemplates = [
  RoleTemplate(
      slug: 'admin',
      nameEn: 'Admin',
      nameHi: 'प्रशासक',
      keys: AdminPerm.values.toSet()),
  const RoleTemplate(
      slug: 'treasurer',
      nameEn: 'Treasurer',
      nameHi: 'कोषाध्यक्ष',
      keys: {
        AdminPerm.finance,
        AdminPerm.fixedAssets,
        AdminPerm.donations,
        AdminPerm.splits,
        AdminPerm.events,
        AdminPerm.notifications,
        AdminPerm.directory,
        AdminPerm.report,
        AdminPerm.password,
        AdminPerm.biometric,
      }),
  const RoleTemplate(
      slug: 'president',
      nameEn: 'President',
      nameHi: 'अध्यक्ष',
      keys: {
        AdminPerm.events,
        AdminPerm.meetings,
        AdminPerm.documents,
        AdminPerm.committee,
        AdminPerm.polls,
        AdminPerm.notifications,
        AdminPerm.parking,
        AdminPerm.directory,
        AdminPerm.report,
        AdminPerm.logs,
        AdminPerm.audit,
        AdminPerm.password,
        AdminPerm.biometric,
      }),
  const RoleTemplate(
      slug: 'vice_president',
      nameEn: 'Vice-President',
      nameHi: 'उपाध्यक्ष',
      keys: {
        AdminPerm.events,
        AdminPerm.meetings,
        AdminPerm.documents,
        AdminPerm.committee,
        AdminPerm.polls,
        AdminPerm.notifications,
        AdminPerm.parking,
        AdminPerm.directory,
        AdminPerm.report,
        AdminPerm.logs,
        AdminPerm.password,
        AdminPerm.biometric,
      }),
  const RoleTemplate(
      slug: 'secretary',
      nameEn: 'Secretary',
      nameHi: 'सचिव',
      keys: {
        AdminPerm.events,
        AdminPerm.meetings,
        AdminPerm.documents,
        AdminPerm.committee,
        AdminPerm.polls,
        AdminPerm.notifications,
        AdminPerm.directory,
        AdminPerm.password,
        AdminPerm.biometric,
      }),
];

/// Matrix sections (labels resolved in the UI).
enum PermGroup {
  people,
  finance,
  governance,
  community,
  gate,
  reports,
  account
}

const Map<PermGroup, List<AdminPerm>> kPermGroups = {
  PermGroup.people: [
    AdminPerm.residentsRw,
    AdminPerm.guardsRw,
    AdminPerm.geofenceRw
  ],
  PermGroup.finance: [
    AdminPerm.finance,
    AdminPerm.fixedAssets,
    AdminPerm.donations,
    AdminPerm.splits,
    AdminPerm.events
  ],
  PermGroup.governance: [
    AdminPerm.meetings,
    AdminPerm.documents,
    AdminPerm.committee,
    AdminPerm.polls
  ],
  PermGroup.community: [AdminPerm.notifications, AdminPerm.parking],
  PermGroup.gate: [
    AdminPerm.visitor,
    AdminPerm.delivery,
    AdminPerm.vehicle,
    AdminPerm.blacklist,
    AdminPerm.directory,
    AdminPerm.quick
  ],
  PermGroup.reports: [AdminPerm.report, AdminPerm.logs, AdminPerm.audit],
  PermGroup.account: [
    AdminPerm.settings,
    AdminPerm.password,
    AdminPerm.biometric
  ],
};
