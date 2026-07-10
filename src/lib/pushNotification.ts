import { supabase } from '@/integrations/supabase/client';

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
    await supabase.functions.invoke('send-push-notification', {
      body: {
        target_flat_numbers: [],
        target_ids: [],
        media_items: [],
        sound_key: 'digital',
        sound_custom_url: '',
        ...body,
      },
    });
  } catch (e) {
    console.warn('Push notification failed (may not be configured):', e);
  }
}
