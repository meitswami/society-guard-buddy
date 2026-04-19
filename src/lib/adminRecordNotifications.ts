import { supabase } from '@/integrations/supabase/client';
import { toast } from 'sonner';

export type AdminRecordNotifyAudience = 'none' | 'selected_flats' | 'all';

export function mediaItemsFromReceiptUrl(url: string | null): { url: string; kind: 'image' }[] | null {
  if (!url) return null;
  const u = url.split('?')[0].toLowerCase();
  if (u.endsWith('.pdf')) return null;
  if (/\.(png|jpe?g|gif|webp|bmp|svg)$/i.test(u)) return [{ url, kind: 'image' as const }];
  return [{ url, kind: 'image' as const }];
}

/**
 * In-app notification rows + best-effort push (same contract as NotificationCenter).
 * For `selected_flats`, inserts one row per flat and sends one push with `target_flat_numbers`.
 */
export async function notifyResidentsOfRecord(opts: {
  societyId: string;
  adminName: string;
  audience: Exclude<AdminRecordNotifyAudience, 'none'>;
  selectedFlatNumbers: string[];
  title: string;
  message: string;
  notificationType: string;
  billUrl: string | null;
  /** Shown if DB insert or push invoke fails */
  saveSucceededHint?: string;
}): Promise<boolean> {
  const {
    societyId,
    adminName,
    audience,
    selectedFlatNumbers,
    title,
    message,
    notificationType,
    billUrl,
    saveSucceededHint = 'Record saved, but notifying residents failed. You can send a manual notice from Notifications.',
  } = opts;

  const mediaItems = mediaItemsFromReceiptUrl(billUrl);
  const rowBase = {
    title,
    message,
    type: notificationType,
    created_by: adminName,
    society_id: societyId,
    sound_key: 'digital',
    sound_custom_url: null as string | null,
    media_items: mediaItems ?? [],
  };

  try {
    if (audience === 'all') {
      const { error } = await supabase.from('notifications').insert([
        {
          ...rowBase,
          target_type: 'all',
          target_id: null,
        },
      ]);
      if (error) throw error;
      await supabase.functions.invoke('send-push-notification', {
        body: {
          title,
          message,
          target_type: 'all',
          target_flat_numbers: [],
          target_ids: [],
          media_items: mediaItems ?? [],
          society_id: societyId,
          sound_key: 'digital',
          sound_custom_url: '',
        },
      });
    } else {
      const flats = [...new Set(selectedFlatNumbers.filter(Boolean))];
      if (flats.length === 0) return true;
      for (const flat of flats) {
        const { error } = await supabase.from('notifications').insert([
          {
            ...rowBase,
            target_type: 'flat',
            target_id: flat,
          },
        ]);
        if (error) throw error;
      }
      await supabase.functions.invoke('send-push-notification', {
        body: {
          title,
          message,
          target_type: 'flat',
          target_flat_numbers: flats,
          target_ids: [],
          media_items: mediaItems ?? [],
          society_id: societyId,
          sound_key: 'digital',
          sound_custom_url: '',
        },
      });
    }
    return true;
  } catch (e) {
    console.warn('Admin record notification / push failed:', e);
    toast.error(saveSucceededHint);
    return false;
  }
}
