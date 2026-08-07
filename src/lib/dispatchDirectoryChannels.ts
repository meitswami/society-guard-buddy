import { supabase } from '@/integrations/supabase/client';

export type DirectoryDispatchChannels = {
  whatsapp?: boolean;
  email?: boolean;
};

export type DirectoryDispatchTarget =
  | { type: 'all' }
  | { type: 'flat'; flatNumbers: string[] }
  | { type: 'user'; residentUserIds: string[] };

/**
 * Best-effort WhatsApp + email despatch via directory contacts.
 * Does not create in-app notifications or push — callers keep those paths.
 */
export async function dispatchDirectoryChannels(opts: {
  societyId: string;
  title: string;
  message: string;
  channels: DirectoryDispatchChannels;
  target?: DirectoryDispatchTarget;
  imageUrl?: string | null;
}): Promise<{
  whatsapp_sent: number;
  whatsapp_failed: number;
  email_sent: number;
  email_failed: number;
  skipped?: string;
} | null> {
  const wantWa = !!opts.channels.whatsapp;
  const wantEmail = !!opts.channels.email;
  if (!wantWa && !wantEmail) return null;

  const target = opts.target ?? { type: 'all' as const };
  try {
    const { data, error } = await supabase.functions.invoke('dispatch-directory-message', {
      body: {
        society_id: opts.societyId,
        title: opts.title,
        message: opts.message,
        channels: { whatsapp: wantWa, email: wantEmail },
        target_type: target.type,
        target_flat_numbers: target.type === 'flat' ? target.flatNumbers : [],
        target_ids: target.type === 'user' ? target.residentUserIds : [],
        image_url: opts.imageUrl ?? null,
      },
    });
    if (error) {
      console.warn('dispatch-directory-message failed', error);
      return null;
    }
    return data as {
      whatsapp_sent: number;
      whatsapp_failed: number;
      email_sent: number;
      email_failed: number;
      skipped?: string;
    };
  } catch (e) {
    console.warn('dispatch-directory-message invoke error', e);
    return null;
  }
}
