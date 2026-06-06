export type CommitteeSelectionType = 'elected' | 'nominated';

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

export function selectionTypeLabel(type: CommitteeSelectionType | null | undefined): string {
  if (type === 'elected') return 'Elected';
  if (type === 'nominated') return 'Nominated';
  return '—';
}
