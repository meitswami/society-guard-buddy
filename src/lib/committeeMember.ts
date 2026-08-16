export type CommitteeSelectionType =
  | 'elected'
  | 'nominated'
  | 'runner_up'
  | 'voluntary'
  | 'executive_proposed';

export type CommitteeMemberRow = {
  id: string;
  society_id: string;
  name: string;
  position: string;
  phone: string | null;
  gender: string | null;
  photo: string | null;
  show_representative: boolean;
  rep_name: string | null;
  rep_phone: string | null;
  rep_photo: string | null;
  sort_order: number;
  is_active: boolean;
  flat_id: string | null;
  flat_number: string | null;
  flat_owner_name: string | null;
  term_from: string | null;
  term_to: string | null;
  selection_type: CommitteeSelectionType | null;
};

/** True when post holder name differs from flat owner (representative serving the post). */
export function committeeIsRepresentative(row: Pick<CommitteeMemberRow, 'name' | 'flat_owner_name'>): boolean {
  const owner = (row.flat_owner_name ?? '').trim();
  const holder = row.name.trim();
  if (!owner || !holder) return false;
  return owner.toLowerCase() !== holder.toLowerCase();
}

/** Primary label + optional subtitle for cards and lists. */
export function committeeDisplayLabels(row: CommitteeMemberRow): {
  primaryName: string;
  subtitle: string | null;
  isRepresentative: boolean;
} {
  const isRepresentative = committeeIsRepresentative(row);
  const owner = (row.flat_owner_name ?? '').trim();
  const holder = row.name.trim();
  const flatLabel = row.flat_number ? `Flat ${row.flat_number}` : null;

  if (isRepresentative) {
    return {
      primaryName: holder,
      subtitle: [flatLabel, owner ? `Owner: ${owner}` : null].filter(Boolean).join(' · ') || null,
      isRepresentative: true,
    };
  }

  return {
    primaryName: owner || holder,
    subtitle: flatLabel,
    isRepresentative: false,
  };
}

export function committeeTenureLabel(row: Pick<CommitteeMemberRow, 'term_from' | 'term_to'>): string | null {
  if (!row.term_from) return null;
  const from = row.term_from.slice(0, 10);
  const to = row.term_to?.slice(0, 10);
  return to ? `${from} → ${to}` : `${from} → Until retirement`;
}

/** Local calendar YYYY-MM-DD (society tenure is date-based, not UTC midnight). */
export function localIsoDate(d: Date = new Date()): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

export function termStartIso(row: Pick<CommitteeMemberRow, 'term_from'> | { term_from?: string | null }): string | null {
  const from = row.term_from?.slice(0, 10);
  return from || null;
}

export function latestCommitteeTermFrom<T extends { term_from?: string | null }>(rows: T[]): string | null {
  let latest: string | null = null;
  for (const r of rows) {
    const from = r.term_from?.slice(0, 10) || null;
    if (from && (!latest || from > latest)) latest = from;
  }
  return latest;
}

/** Latest elected/appointed term is "current", even if term_from is a few days in the future. */
export function isCurrentCommitteeTerm(
  row: Pick<CommitteeMemberRow, 'term_from' | 'term_to'>,
  currentTermFrom: string | null,
): boolean {
  if (!currentTermFrom) return true;
  const from = row.term_from?.slice(0, 10) || null;
  if (from) return from >= currentTermFrom;
  const to = row.term_to?.slice(0, 10) || null;
  if (to && to < currentTermFrom) return false;
  return true;
}

const UNIQUE_POSTS = new Set([
  'president',
  'vice-president',
  'secretary',
  'treasurer',
  'cultural secretary',
]);

function normalizePersonKey(name: string): string {
  return name.trim().toLowerCase().replace(/\s+/g, ' ');
}

/**
 * Collapse accidental duplicate office-bearers in the same term.
 * Unique posts keep one row (prefer a closed 2-year tenure, then longer name).
 */
export function dedupeCommitteeByPosition<
  T extends { position: string; name: string; term_to?: string | null; sort_order?: number },
>(rows: T[]): T[] {
  const groups = new Map<string, T[]>();
  for (const r of rows) {
    const pos = r.position.trim().toLowerCase();
    const key = UNIQUE_POSTS.has(pos) ? pos : `${pos}|${normalizePersonKey(r.name)}`;
    const list = groups.get(key) ?? [];
    list.push(r);
    groups.set(key, list);
  }
  const out: T[] = [];
  for (const list of groups.values()) {
    if (list.length === 1) {
      out.push(list[0]);
      continue;
    }
    list.sort((a, b) => {
      const aTo = a.term_to ? 1 : 0;
      const bTo = b.term_to ? 1 : 0;
      if (aTo !== bTo) return bTo - aTo;
      if (b.name.trim().length !== a.name.trim().length) return b.name.trim().length - a.name.trim().length;
      return (a.sort_order ?? 0) - (b.sort_order ?? 0);
    });
    out.push(list[0]);
  }
  return out.sort(
    (a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0) || a.name.localeCompare(b.name),
  );
}

export type CommitteeTermSplit<T> = {
  current: T[];
  previous: T[];
  currentTermFrom: string | null;
};

/** Split active roster into current term vs earlier terms (Previous year). */
export function splitCommitteeTerms<
  T extends Pick<CommitteeMemberRow, 'term_from' | 'term_to' | 'is_active' | 'position' | 'name' | 'sort_order'>,
>(rows: T[]): CommitteeTermSplit<T> {
  const active = rows.filter((r) => r.is_active !== false);
  const currentTermFrom = latestCommitteeTermFrom(active);
  const current: T[] = [];
  const previous: T[] = [];
  for (const r of active) {
    if (isCurrentCommitteeTerm(r, currentTermFrom)) current.push(r);
    else previous.push(r);
  }
  return {
    current: dedupeCommitteeByPosition(current),
    previous,
    currentTermFrom,
  };
}

export function currentCommitteeMembers<
  T extends Pick<CommitteeMemberRow, 'term_from' | 'term_to' | 'is_active' | 'position' | 'name' | 'sort_order'>,
>(rows: T[]): T[] {
  return splitCommitteeTerms(rows).current;
}

/** True when the member is on the living roster for the given calendar day. */
export function isCommitteeMemberEffectiveOn(
  row: Pick<CommitteeMemberRow, 'is_active' | 'term_from' | 'term_to'>,
  onDate: string = localIsoDate(),
): boolean {
  if (!row.is_active) return false;
  const from = row.term_from?.slice(0, 10);
  const to = row.term_to?.slice(0, 10);
  if (from && from > onDate) return false;
  if (to && to < onDate) return false;
  return true;
}

export function filterEffectiveCommitteeMembers<T extends Pick<CommitteeMemberRow, 'is_active' | 'term_from' | 'term_to'>>(
  rows: T[],
  onDate: string = localIsoDate(),
): T[] {
  return rows.filter((r) => isCommitteeMemberEffectiveOn(r, onDate));
}

export function selectionTypeLabel(type: CommitteeSelectionType | null | undefined): string {
  switch (type) {
    case 'elected':
      return 'Elected';
    case 'nominated':
      return 'Nominated';
    case 'runner_up':
      return 'Runner-up (2nd/3rd)';
    case 'voluntary':
      return 'Voluntary';
    case 'executive_proposed':
      return 'Executive proposed';
    default:
      return '—';
  }
}

export const COMMITTEE_SELECTION_OPTIONS: { value: CommitteeSelectionType; label: string }[] = [
  { value: 'elected', label: 'Elected' },
  { value: 'nominated', label: 'Nominated' },
  { value: 'runner_up', label: 'Runner-up (2nd/3rd)' },
  { value: 'voluntary', label: 'Voluntary' },
  { value: 'executive_proposed', label: 'Executive proposed' },
];
