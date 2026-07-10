import type { ElementType } from 'react';
import type { AdminTab } from '@/lib/adminPermissions';

export const ADMIN_BOTTOM_NAV_TABS: AdminTab[] = ['overview', 'audit', 'finance', 'report'];

export type AdminTabDef = {
  id: AdminTab;
  label: string;
  icon: ElementType;
  group?: string;
};

export type AdminSearchRoute = {
  tab: AdminTab;
  label: string;
  keywords: string[];
  hint: string;
};

/** Modules reachable via global search with query passed into the module filter. */
export const ADMIN_SEARCH_ROUTES: AdminSearchRoute[] = [
  { tab: 'residents', label: 'Residents', keywords: ['flat', 'owner', 'phone', 'member', 'resident'], hint: 'Flat, owner, phone' },
  { tab: 'directory', label: 'Directory', keywords: ['directory', 'contact', 'flat', 'phone'], hint: 'Flat, name, phone' },
  { tab: 'finance', label: 'Finance', keywords: ['payment', 'receipt', 'maintenance', 'charge', 'ledger', 'txn'], hint: 'Flat, charge, txn' },
  { tab: 'fixed_assets', label: 'Fixed Assets', keywords: ['asset', 'fixed', 'dg', 'lift', 'gym', 'warranty', 'amc', 'equipment'], hint: 'Asset register' },
  { tab: 'report', label: 'Reports', keywords: ['report', 'visitor', 'vehicle', 'ledger', 'shift'], hint: 'Cross-report search' },
  { tab: 'audit', label: 'Audit', keywords: ['audit', 'login', 'ip', 'log'], hint: 'Name, ID, IP' },
  { tab: 'guards', label: 'Guards', keywords: ['guard', 'kyc', 'security'], hint: 'Guard name or ID' },
  { tab: 'vehicle', label: 'Vehicles', keywords: ['vehicle', 'car', 'bike', 'number plate'], hint: 'Plate or owner' },
  { tab: 'visitor', label: 'Visitor', keywords: ['visitor', 'guest', 'entry'], hint: 'Visitor name or flat' },
  { tab: 'delivery', label: 'Delivery', keywords: ['delivery', 'courier', 'parcel'], hint: 'Delivery entry' },
  { tab: 'blacklist', label: 'Blacklist', keywords: ['blacklist', 'blocked'], hint: 'Name or reason' },
  { tab: 'logs', label: 'Logs', keywords: ['log', 'shift', 'guard log'], hint: 'Guard or shift' },
  { tab: 'quick', label: 'Quick entry', keywords: ['quick', 'entry'], hint: 'Quick log search' },
  { tab: 'committee', label: 'Committee', keywords: ['committee', 'mc', 'member'], hint: 'Flat or owner' },
  { tab: 'events', label: 'Events & food', keywords: ['event', 'food', 'catering', 'split'], hint: 'Event expenses' },
  { tab: 'meetings', label: 'Meetings', keywords: ['meeting', 'minutes', 'agenda'], hint: 'Meeting records' },
  { tab: 'documents', label: 'Documents', keywords: ['document', 'file', 'society doc'], hint: 'Society documents' },
  { tab: 'polls', label: 'Polls & Elections', keywords: ['poll', 'election', 'vote'], hint: 'Polls' },
  { tab: 'parking', label: 'Parking', keywords: ['parking', 'slot', 'sticker'], hint: 'Parking slots' },
  { tab: 'notifications', label: 'Notify', keywords: ['notify', 'notification', 'broadcast'], hint: 'Notifications' },
  { tab: 'donations', label: 'Donations', keywords: ['donation', 'charity'], hint: 'Donations' },
  { tab: 'geofence', label: 'Geofence', keywords: ['geofence', 'location', 'gps'], hint: 'Geofence setup' },
  { tab: 'settings', label: 'Settings', keywords: ['settings', 'theme', 'language'], hint: 'App settings' },
];

export function tabUsageStorageKey(societyId: string): string {
  return `sgb_admin_tab_use_${societyId}`;
}

export function lastTabStorageKey(societyId: string): string {
  return `sgb_admin_last_tab_${societyId}`;
}

export function readTabUsage(societyId: string | null): Record<string, number> {
  if (typeof window === 'undefined' || !societyId) return {};
  try {
    return JSON.parse(localStorage.getItem(tabUsageStorageKey(societyId)) || '{}') as Record<string, number>;
  } catch {
    return {};
  }
}

export function readLastTab(societyId: string | null): AdminTab | null {
  if (typeof window === 'undefined' || !societyId) return null;
  try {
    const raw = localStorage.getItem(lastTabStorageKey(societyId));
    return raw ? (raw as AdminTab) : null;
  } catch {
    return null;
  }
}

export function recordLastTab(societyId: string | null, tab: AdminTab): void {
  if (typeof window === 'undefined' || !societyId || tab === 'overview') return;
  try {
    localStorage.setItem(lastTabStorageKey(societyId), tab);
  } catch {
    /* ignore */
  }
}

export function computeQuickAccessTabs(
  visibleTabs: AdminTabDef[],
  usageMap: Record<string, number>,
  lastTab: AdminTab | null,
): AdminTabDef[] {
  const byId = new Map(visibleTabs.map((t) => [t.id, t]));
  const candidates = visibleTabs.filter((t) => t.id !== 'overview');

  const byUsage = [...candidates].sort((a, b) => {
    const diff = (usageMap[b.id] ?? 0) - (usageMap[a.id] ?? 0);
    if (diff !== 0) return diff;
    return a.label.localeCompare(b.label, undefined, { sensitivity: 'base' });
  });

  const picked: AdminTabDef[] = [];
  const seen = new Set<AdminTab>();

  for (const tab of byUsage) {
    if (picked.length >= 6) break;
    if (seen.has(tab.id)) continue;
    picked.push(tab);
    seen.add(tab.id);
  }

  if (lastTab && lastTab !== 'overview' && !seen.has(lastTab)) {
    const last = byId.get(lastTab);
    if (last) picked.push(last);
  }

  return picked;
}

export function scoreSearchRoute(route: AdminSearchRoute, query: string): number {
  const q = query.trim().toLowerCase();
  if (!q) return 0;
  let score = 0;
  if (route.label.toLowerCase().includes(q)) score += 8;
  for (const kw of route.keywords) {
    if (kw.includes(q) || q.includes(kw)) score += 4;
    if (kw.startsWith(q) || q.startsWith(kw)) score += 2;
  }
  if (/\d/.test(q) && ['residents', 'directory', 'finance', 'report'].includes(route.tab)) score += 3;
  if (/^\d{1,3}[a-z]?$/i.test(q) && ['residents', 'directory'].includes(route.tab)) score += 5;
  return score;
}

export function findBestSearchRoute(query: string, allowedTabs: Set<AdminTab>): AdminSearchRoute | null {
  const q = query.trim();
  if (!q) return null;
  let best: AdminSearchRoute | null = null;
  let bestScore = 0;
  for (const route of ADMIN_SEARCH_ROUTES) {
    if (!allowedTabs.has(route.tab)) continue;
    const score = scoreSearchRoute(route, q);
    if (score > bestScore) {
      bestScore = score;
      best = route;
    }
  }
  return bestScore > 0 ? best : null;
}

export function searchRoutesForQuery(query: string, allowedTabs: Set<AdminTab>): AdminSearchRoute[] {
  const q = query.trim();
  if (!q) return [];
  return ADMIN_SEARCH_ROUTES
    .filter((r) => allowedTabs.has(r.tab))
    .map((r) => ({ route: r, score: scoreSearchRoute(r, q) }))
    .filter((x) => x.score > 0)
    .sort((a, b) => b.score - a.score)
    .map((x) => x.route);
}
