import { getMessaging, getToken, isSupported, onMessage, type Messaging } from 'firebase/messaging';
import { toast } from 'sonner';
import { supabase } from '@/integrations/supabase/client';
import { getFirebaseApp, isFirebaseConfigured } from '@/lib/firebase';

const vapidKey = import.meta.env.VITE_FIREBASE_VAPID_KEY as string | undefined;

export function isFcmWebPushConfigured(): boolean {
  return Boolean(isFirebaseConfigured() && vapidKey?.trim());
}

let messagingSingleton: Messaging | null = null;

function getMessagingOrThrow(): Messaging {
  if (!messagingSingleton) {
    messagingSingleton = getMessaging(getFirebaseApp());
  }
  return messagingSingleton;
}

/** Foreground FCM: show toast when a notification arrives and the app tab is open. */
export function initFcmForegroundMessaging(): void {
  if (typeof window === 'undefined' || !isFcmWebPushConfigured()) return;
  void (async () => {
    try {
      if (!(await isSupported())) return;
      const messaging = getMessagingOrThrow();
      onMessage(messaging, (payload) => {
        const title = payload.notification?.title ?? 'Kutumbika';
        const body = payload.notification?.body ?? '';
        if (body) toast.info(title, { description: body });
        else toast.info(title);
      });
    } catch {
      /* unsupported or blocked */
    }
  })();
}

export type FcmWebUserOpts = {
  userType: 'admin' | 'guard' | 'resident';
  userId: string;
  userName: string;
  flatNumber?: string;
  societyId?: string | null;
};

/**
 * Request notification permission (if needed), obtain FCM token, upsert into Supabase for targeted sends.
 * Safe to call after login; no-ops when VAPID / messaging is unavailable.
 */
export async function registerFcmWebUser(opts: FcmWebUserOpts): Promise<void> {
  if (!isFcmWebPushConfigured() || typeof window === 'undefined') return;
  try {
    if (!(await isSupported())) return;
    const perm = await Notification.requestPermission();
    if (perm !== 'granted') return;

    const registration = await navigator.serviceWorker.register('/firebase-messaging-sw.js', {
      type: 'classic',
      scope: '/',
    });
    await navigator.serviceWorker.ready;

    const messaging = getMessagingOrThrow();
    const token = await getToken(messaging, {
      vapidKey: vapidKey!.trim(),
      serviceWorkerRegistration: registration,
    });
    if (!token) return;

    const { error } = await supabase.from('fcm_web_tokens').upsert(
      {
        token,
        user_type: opts.userType,
        app_user_id: opts.userId,
        flat_number: opts.flatNumber ?? null,
        society_id: opts.societyId ?? null,
      },
      { onConflict: 'token' },
    );
    if (error) console.warn('[FCM] token upsert failed:', error.message);
  } catch (e) {
    console.warn('[FCM] registerFcmWebUser:', e);
  }
}
