import { supabase } from '@/integrations/supabase/client';
import { playNotificationAlert } from '@/lib/notificationSounds';

export type SocietyNotificationSound = {
  sound_key: 'custom' | 'digital';
  sound_custom_url: string | null;
};

/** Resolve society signature / member-notification tune (admin_push_sound_url). */
export async function fetchSocietyNotificationSound(
  societyId: string | null | undefined,
): Promise<SocietyNotificationSound> {
  if (!societyId) return { sound_key: 'digital', sound_custom_url: null };
  const { data } = await supabase
    .from('societies')
    .select('admin_push_sound_url')
    .eq('id', societyId)
    .maybeSingle();
  const url = data?.admin_push_sound_url?.trim() || null;
  if (url) return { sound_key: 'custom', sound_custom_url: url };
  return { sound_key: 'digital', sound_custom_url: null };
}

const SIGNATURE_TUNE_SESSION_KEY = 'sgb_society_signature_tune_played';

/** Play society signature tune once per browser tab session (app open). */
export async function playSocietySignatureTuneOnOpen(
  societyId: string | null | undefined,
  opts?: { force?: boolean },
): Promise<void> {
  if (!societyId || typeof window === 'undefined') return;
  try {
    if (!opts?.force && sessionStorage.getItem(SIGNATURE_TUNE_SESSION_KEY) === societyId) {
      return;
    }
  } catch {
    /* private mode */
  }

  const sound = await fetchSocietyNotificationSound(societyId);
  if (sound.sound_key !== 'custom' || !sound.sound_custom_url) return;

  playNotificationAlert('custom', sound.sound_custom_url);

  try {
    sessionStorage.setItem(SIGNATURE_TUNE_SESSION_KEY, societyId);
  } catch {
    /* ignore */
  }
}
