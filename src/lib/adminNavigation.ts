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
  /** i18n key under adminNav.* */
  labelKey: string;
  keywords: string[];
  hint: string;
};

/** Modules reachable via global search with query passed into the module filter. */
export const ADMIN_SEARCH_ROUTES: AdminSearchRoute[] = [
  { tab: 'residents', labelKey: 'adminNav.residents', keywords: ['flat', 'owner', 'phone', 'member', 'resident', 'निवासी'], hint: 'Flat, owner, phone' },
  { tab: 'directory', labelKey: 'adminNav.directory', keywords: ['directory', 'contact', 'flat', 'phone', 'निर्देशिका'], hint: 'Flat, name, phone' },
  { tab: 'finance', labelKey: 'adminNav.finance', keywords: ['payment', 'receipt', 'maintenance', 'charge', 'ledger', 'txn', 'वित्त'], hint: 'Flat, charge, txn' },
  { tab: 'fixed_assets', labelKey: 'adminNav.fixedAssets', keywords: ['asset', 'fixed', 'dg', 'lift', 'gym', 'warranty', 'amc', 'equipment'], hint: 'Asset register' },
  { tab: 'report', labelKey: 'adminNav.reports', keywords: ['report', 'visitor', 'vehicle', 'ledger', 'shift', 'रिपोर्ट'], hint: 'Cross-report search' },
  { tab: 'audit', labelKey: 'adminNav.audit', keywords: ['audit', 'login', 'ip', 'log', 'ऑडिट'], hint: 'Name, ID, IP' },
  { tab: 'guards', labelKey: 'adminNav.guards', keywords: ['guard', 'kyc', 'security', 'गार्ड'], hint: 'Guard name or ID' },
  { tab: 'vehicle', labelKey: 'adminNav.vehicles', keywords: ['vehicle', 'car', 'bike', 'number plate', 'वाहन'], hint: 'Plate or owner' },
  { tab: 'visitor', labelKey: 'adminNav.visitor', keywords: ['visitor', 'guest', 'entry', 'विज़िटर'], hint: 'Visitor name or flat' },
  { tab: 'delivery', labelKey: 'adminNav.delivery', keywords: ['delivery', 'courier', 'parcel', 'डिलीवरी'], hint: 'Delivery entry' },
  { tab: 'blacklist', labelKey: 'adminNav.blacklist', keywords: ['blacklist', 'blocked', 'ब्लैकलिस्ट'], hint: 'Name or reason' },
  { tab: 'logs', labelKey: 'adminNav.logs', keywords: ['log', 'shift', 'guard log', 'लॉग'], hint: 'Guard or shift' },
  { tab: 'quick', labelKey: 'adminNav.quick', keywords: ['quick', 'entry', 'क्विक'], hint: 'Quick log search' },
  { tab: 'committee', labelKey: 'adminNav.committee', keywords: ['committee', 'mc', 'member', 'समिति'], hint: 'Flat or owner' },
  { tab: 'events', labelKey: 'adminNav.events', keywords: ['event', 'food', 'catering', 'split', 'इवेंट'], hint: 'Event expenses' },
  { tab: 'meetings', labelKey: 'adminNav.meetings', keywords: ['meeting', 'minutes', 'agenda', 'मीटिंग'], hint: 'Meeting records' },
  { tab: 'documents', labelKey: 'adminNav.documents', keywords: ['document', 'file', 'society doc', 'दस्तावेज़'], hint: 'Society documents' },
  { tab: 'polls', labelKey: 'adminNav.polls', keywords: ['poll', 'election', 'vote', 'पोल', 'चुनाव'], hint: 'Polls' },
  { tab: 'parking', labelKey: 'adminNav.parking', keywords: ['parking', 'slot', 'sticker', 'पार्किंग'], hint: 'Parking slots' },
  { tab: 'notifications', labelKey: 'adminNav.notify', keywords: ['notify', 'notification', 'broadcast', 'सूचना'], hint: 'Notifications' },
  { tab: 'donations', labelKey: 'adminNav.donations', keywords: ['donation', 'charity', 'दान'], hint: 'Donations' },
  { tab: 'geofence', labelKey: 'adminNav.geofence', keywords: ['geofence', 'location', 'gps', 'जियोफ़ेंस'], hint: 'Geofence setup' },
  { tab: 'settings', labelKey: 'adminNav.settings', keywords: ['settings', 'theme', 'language', 'सेटिंग', 'भाषा'], hint: 'App settings' },
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
  if (route.labelKey.toLowerCase().includes(q)) score += 4;
  // Match against English/Hindi keyword fragments already on the route
  const labelHint = route.labelKey.replace(/^adminNav\./, '').toLowerCase();
  if (labelHint.includes(q) || q.includes(labelHint)) score += 6;
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
