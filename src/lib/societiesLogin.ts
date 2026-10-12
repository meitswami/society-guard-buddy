import { supabase } from '@/integrations/supabase/client';

export type LoginSocietyRow = { id: string; name: string };

/**
 * Same ordering as superadmin dashboard: active societies A–Z by name.
 * Throws when the request fails, so callers can show an error instead of an empty list.
 */
export async function fetchActiveSocietiesByName(): Promise<LoginSocietyRow[]> {
  const { data, error } = await supabase
    .from('societies')
    .select('id, name')
    .eq('is_active', true)
    .order('name', { ascending: true });
  if (error) throw new Error(error.message || 'Could not load societies');
  return data ?? [];
}

const wait = (ms: number) => new Promise((r) => setTimeout(r, ms));

/**
 * Login screens: retry a few times with backoff. The first request from a freshly
 * opened Android WebView / PWA often fails while the network is still coming up.
 */
export async function fetchActiveSocietiesWithRetry(attempts = 4): Promise<LoginSocietyRow[]> {
  let lastError: unknown = null;
  for (let i = 0; i < attempts; i++) {
    try {
      const rows = await fetchActiveSocietiesByName();
      if (rows.length > 0 || i === attempts - 1) return rows;
    } catch (e) {
      lastError = e;
      console.warn(`[societies] load attempt ${i + 1} failed`, e);
    }
    await wait(800 * 2 ** i);
  }
  throw lastError instanceof Error ? lastError : new Error('Could not load societies');
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
