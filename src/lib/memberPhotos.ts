import { supabase } from '@/integrations/supabase/client';

/** Load profile photos for member ids (family, staff, servants — anyone on `members`). */
export async function fetchMemberPhotoMap(memberIds: string[]): Promise<Record<string, string>> {
  const ids = [...new Set(memberIds.filter(Boolean))];
  if (ids.length === 0) return {};
  const { data, error } = await supabase.from('members').select('id, photo').in('id', ids);
  if (error || !data) return {};
  const map: Record<string, string> = {};
  for (const row of data) {
    const photo = typeof row.photo === 'string' ? row.photo.trim() : '';
    if (photo) map[row.id as string] = photo;
  }
  return map;
}

/** Resolve display photo for a poll option: live member profile first. */
export function photoForOption(
  opt: { member_id?: string | null; id?: string },
  photoByMemberId: Record<string, string>,
): string | undefined {
  const mid = opt.member_id;
  if (mid && photoByMemberId[mid]) return photoByMemberId[mid];
  return undefined;
}

/**
 * Keep denormalized committee roster photos in sync when a household member
 * face photo is uploaded or updated (family / staff / elected / nominated).
 */
export async function propagateMemberPhoto(memberId: string, photo: string | null): Promise<void> {
  const trimmed = typeof photo === 'string' ? photo.trim() : '';
  const value = trimmed || null;
  const { data: member } = await supabase
    .from('members')
    .select('id, name, flat_id')
    .eq('id', memberId)
    .maybeSingle();
  if (!member?.flat_id || !member.name?.trim()) return;

  await supabase
    .from('committee_members')
    .update({ photo: value })
    .eq('flat_id', member.flat_id)
    .eq('name', member.name.trim())
    .eq('is_active', true);
}
