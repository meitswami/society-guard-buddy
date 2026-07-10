import { uploadToNotificationMedia, sanitizeStorageFileName } from '@/lib/notificationMediaStorage';
import { supabase } from '@/integrations/supabase/client';
import type { NotificationMediaItem } from '@/components/NotificationDetailModal';

const MAX_IMAGE_BYTES = 12 * 1024 * 1024;

function fileMediaKind(file: File): 'image' | 'video' | null {
  if (file.type.startsWith('image/')) return 'image';
  if (file.type.startsWith('video/')) return 'video';
  return null;
}

async function dataUrlToFile(dataUrl: string, index: number): Promise<File | null> {
  try {
    const res = await fetch(dataUrl);
    const blob = await res.blob();
    return new File([blob], `emergency_${Date.now()}_${index}.jpg`, { type: blob.type || 'image/jpeg' });
  } catch {
    return null;
  }
}

export async function uploadEmergencyMedia(files: File[], dataUrls: string[] = []): Promise<NotificationMediaItem[]> {
  const items: NotificationMediaItem[] = [];
  const allFiles: File[] = [...files];

  for (let i = 0; i < dataUrls.length; i++) {
    const f = await dataUrlToFile(dataUrls[i], i);
    if (f) allFiles.push(f);
  }

  for (const file of allFiles) {
    const kind = fileMediaKind(file);
    if (!kind) continue;
    if (kind === 'image' && file.size > MAX_IMAGE_BYTES) continue;
    const safe = sanitizeStorageFileName(file.name);
    const path = `emergency/${crypto.randomUUID()}/${Date.now()}_${safe}`;
    const url = await uploadToNotificationMedia(path, file);
    if (url) items.push({ url, kind });
  }
  return items;
}

export type EmergencyAlertResult = {
  success: boolean;
  notification_id?: string;
  push_sent?: number;
  whatsapp_recipients?: number;
  whatsapp_sent?: number;
  whatsapp_failed?: number;
  whatsapp_configured?: boolean;
  error?: string;
};

export async function sendEmergencyAlert(opts: {
  societyId: string;
  title: string;
  message: string;
  senderRole: 'guard' | 'resident';
  senderName: string;
  senderFlatNumber?: string;
  files?: File[];
  photoDataUrls?: string[];
}): Promise<EmergencyAlertResult> {
  const mediaItems = await uploadEmergencyMedia(opts.files ?? [], opts.photoDataUrls ?? []);

  const { data, error } = await supabase.functions.invoke('send-emergency-alert', {
    body: {
      society_id: opts.societyId,
      title: opts.title,
      message: opts.message,
      sender_role: opts.senderRole,
      sender_name: opts.senderName,
      sender_flat_number: opts.senderFlatNumber ?? null,
      media_items: mediaItems,
    },
  });

  if (error) {
    return { success: false, error: error.message };
  }
  if ((data as { error?: string })?.error) {
    return { success: false, error: (data as { error: string }).error };
  }
  return { success: true, ...(data as Omit<EmergencyAlertResult, 'success'>) };
}
