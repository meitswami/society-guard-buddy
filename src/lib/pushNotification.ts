import { supabase } from '@/integrations/supabase/client';
import { fetchSocietyNotificationSound } from '@/lib/societyNotificationSound';

export type PushTargetType = 'all' | 'flat' | 'user';

export type PushNotificationBody = {
  title: string;
  message: string;
  target_type: PushTargetType;
  society_id: string;
  target_flat_numbers?: string[];
  target_ids?: string[];
  media_items?: { url: string; kind: 'image' | 'video' }[];
  sound_key?: string;
  sound_custom_url?: string;
};

/** Best-effort FCM / OneSignal push (same contract as NotificationCenter). */
export async function invokePushNotification(body: PushNotificationBody): Promise<void> {
  try {
    const sound =
      body.sound_key != null
        ? { sound_key: body.sound_key, sound_custom_url: body.sound_custom_url ?? '' }
        : await fetchSocietyNotificationSound(body.society_id);
    await supabase.functions.invoke('send-push-notification', {
      body: {
        target_flat_numbers: [],
        target_ids: [],
        media_items: [],
        ...body,
        sound_key: sound.sound_key,
        sound_custom_url: sound.sound_custom_url ?? '',
      },
    });
  } catch (e) {
    console.warn('Push notification failed (may not be configured):', e);
  }
}
