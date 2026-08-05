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
