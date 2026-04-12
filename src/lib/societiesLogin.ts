import { supabase } from '@/integrations/supabase/client';

export type LoginSocietyRow = { id: string; name: string };

/** Same ordering as superadmin dashboard: active societies A–Z by name. */
export async function fetchActiveSocietiesByName(): Promise<LoginSocietyRow[]> {
  const { data } = await supabase
    .from('societies')
    .select('id, name')
    .eq('is_active', true)
    .order('name', { ascending: true });
  return data ?? [];
}

export async function getResidentByPhoneInSociety(phone: string, societyId: string) {
  const { data: flats } = await supabase.from('flats').select('id').eq('society_id', societyId);
  const ids = (flats ?? []).map((f) => f.id);
  if (ids.length === 0) return null;
  const { data } = await supabase
    .from('resident_users')
    .select('*')
    .eq('phone', phone)
    .in('flat_id', ids)
    .maybeSingle();
  return data;
}
