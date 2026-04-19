/** Feature flags for admin panel tabs (stored on society_roles.permissions JSON). */
export type AdminPanelPermissions = {
  residents_rw: boolean;
  guards_rw: boolean;
  geofence_rw: boolean;
  finance: boolean;
  donations: boolean;
  splits: boolean;
  events: boolean;
  polls: boolean;
  notifications: boolean;
  parking: boolean;
  visitor: boolean;
  delivery: boolean;
  vehicle: boolean;
  blacklist: boolean;
  directory: boolean;
  quick: boolean;
  report: boolean;
  logs: boolean;
  audit: boolean;
  settings: boolean;
  password: boolean;
  biometric: boolean;
};

/** New roles created from Superadmin "Add" start locked down until permissions are edited in DB. */
export const NEW_CUSTOM_ROLE_PERMISSIONS: AdminPanelPermissions = {
  residents_rw: false,
  guards_rw: false,
  geofence_rw: false,
  finance: false,
  donations: false,
  splits: false,
  events: false,
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
};

export const FULL_ADMIN_PERMISSIONS: AdminPanelPermissions = {
  residents_rw: true,
  guards_rw: true,
  geofence_rw: true,
  finance: true,
  donations: true,
  splits: true,
  events: true,
  polls: true,
  notifications: true,
  parking: true,
  visitor: true,
  delivery: true,
  vehicle: true,
  blacklist: true,
  directory: true,
  quick: true,
  report: true,
  logs: true,
  audit: true,
  settings: true,
  password: true,
  biometric: true,
};

const PERM_KEYS = Object.keys(FULL_ADMIN_PERMISSIONS) as (keyof AdminPanelPermissions)[];

export function mergeRolePermissions(raw: unknown): AdminPanelPermissions {
  if (!raw || typeof raw !== 'object') return { ...FULL_ADMIN_PERMISSIONS };
  const o = raw as Record<string, unknown>;
  const boolKeys = Object.keys(o).filter((k) => typeof o[k] === 'boolean');
  if (boolKeys.length === 0) return { ...NEW_CUSTOM_ROLE_PERMISSIONS };
  const out = { ...FULL_ADMIN_PERMISSIONS };
  for (const k of PERM_KEYS) {
    if (typeof o[k] === 'boolean') out[k] = o[k];
  }
  return out;
}

/** Admins with no role_id get full access (legacy). */
export function permissionsFromAdminJoin(row: {
  role_id?: string | null;
  society_roles?: unknown;
}): AdminPanelPermissions {
  if (!row.role_id) return { ...FULL_ADMIN_PERMISSIONS };
  const rel = row.society_roles;
  const sr = Array.isArray(rel) ? rel[0] : rel;
  if (!sr || typeof sr !== 'object' || !('permissions' in sr)) return { ...FULL_ADMIN_PERMISSIONS };
  const perms = (sr as { permissions?: unknown }).permissions;
  if (perms === undefined || perms === null) return { ...FULL_ADMIN_PERMISSIONS };
  return mergeRolePermissions(perms);
}

export type AdminTab =
  | 'overview'
  | 'guards'
  | 'residents'
  | 'geofence'
  | 'password'
  | 'biometric'
  | 'audit'
  | 'finance'
  | 'donations'
  | 'events'
  | 'polls'
  | 'parking'
  | 'splits'
  | 'notifications'
  | 'visitor'
  | 'delivery'
  | 'vehicle'
  | 'blacklist'
  | 'directory'
  | 'quick'
  | 'report'
  | 'logs'
  | 'settings'
  | 'tour';

const TAB_PERM: Record<AdminTab, keyof AdminPanelPermissions | null> = {
  overview: null,
  tour: null,
  guards: 'guards_rw',
  residents: 'residents_rw',
  geofence: 'geofence_rw',
  password: 'password',
  biometric: 'biometric',
  audit: 'audit',
  finance: 'finance',
  donations: 'donations',
  events: 'events',
  polls: 'polls',
  parking: 'parking',
  splits: 'splits',
  notifications: 'notifications',
  visitor: 'visitor',
  delivery: 'delivery',
  vehicle: 'vehicle',
  blacklist: 'blacklist',
  directory: 'directory',
  quick: 'quick',
  report: 'report',
  logs: 'logs',
  settings: 'settings',
};

export function isAdminTabAllowed(tab: AdminTab, p: AdminPanelPermissions): boolean {
  const key = TAB_PERM[tab];
  if (key === null) return true;
  return !!p[key];
}
