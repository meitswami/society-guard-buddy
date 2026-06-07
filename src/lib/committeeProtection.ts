import type { CommitteeMemberRow } from '@/lib/committeeMember';

const norm = (s: string | null | undefined) => (s ?? '').trim().toLowerCase();

/** True when this household member appears on the published committee roster — admin-only edits. */
export function isMemberOnCommitteeRoster(
  member: { id?: string; name?: string; phone?: string | null; flat_id?: string },
  committeeRows: CommitteeMemberRow[],
): boolean {
  const name = norm(member.name);
  const phone = (member.phone ?? '').replace(/\D/g, '');
  const flatId = member.flat_id ?? '';

  for (const row of committeeRows) {
    if (flatId && row.flat_id && row.flat_id === flatId && name && norm(row.name) === name) return true;
    if (flatId && row.flat_id && row.flat_id === flatId && name && norm(row.flat_owner_name) === name) return true;
    if (phone && row.phone && row.phone.replace(/\D/g, '') === phone) return true;
    if (member.id && row.flat_id === flatId) {
      const holder = norm(row.name);
      const owner = norm(row.flat_owner_name);
      if (holder === name || owner === name) return true;
    }
  }
  return false;
}
