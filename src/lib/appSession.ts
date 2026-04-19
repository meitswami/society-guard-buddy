import type { AdminPanelPermissions } from '@/lib/adminPermissions';

const KEY = 'sgb_app_session_v1';

export type PersistedResident = {
  id: string;
  name: string;
  phone: string;
  flatId: string;
  flatNumber: string;
};

export type PersistedAdmin = {
  id: string;
  name: string;
  adminId: string;
  societyId: string | null;
  permissions: AdminPanelPermissions;
};

export type PersistedSuperadmin = { id: string; name: string; username: string };

export type PersistedSessionV1 =
  | { v: 1; role: 'guard'; societyId: string; shiftId: string; guardId: string }
  | { v: 1; role: 'resident'; societyId: string; resident: PersistedResident }
  | { v: 1; role: 'admin'; societyId: string; admin: PersistedAdmin }
  | { v: 1; role: 'superadmin'; superadmin: PersistedSuperadmin };

export function readPersistedSession(): PersistedSessionV1 | null {
  try {
    const raw = localStorage.getItem(KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as PersistedSessionV1;
    if (parsed?.v !== 1 || !parsed.role) return null;
    return parsed;
  } catch {
    return null;
  }
}

export function writePersistedSession(session: PersistedSessionV1): void {
  try {
    localStorage.setItem(KEY, JSON.stringify(session));
  } catch {
    /* quota / private mode */
  }
}

export function clearPersistedSession(): void {
  try {
    localStorage.removeItem(KEY);
  } catch {
    /* ignore */
  }
}
