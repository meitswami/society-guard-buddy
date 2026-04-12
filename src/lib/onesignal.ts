import { registerFcmWebUser } from '@/lib/fcmWeb';

// OneSignal helper for user registration & tagging
declare global {
  interface Window {
    OneSignalDeferred: Array<(OneSignal: any) => void>;
  }
}

const APP_ID = '56605d90-2aff-4fb3-b97d-e423ad959d0b';

let initialized = false;

export const initOneSignal = () => {
  if (initialized) return;
  initialized = true;
  window.OneSignalDeferred = window.OneSignalDeferred || [];
  window.OneSignalDeferred.push(async (OneSignal: any) => {
    await OneSignal.init({ appId: APP_ID });
  });
};

/** Register this user with OneSignal and tag them for targeted notifications */
export const registerOneSignalUser = (opts: {
  userType: 'admin' | 'guard' | 'resident';
  userId: string;
  userName: string;
  flatNumber?: string;
  societyId?: string | null;
}) => {
  window.OneSignalDeferred = window.OneSignalDeferred || [];
  window.OneSignalDeferred.push(async (OneSignal: any) => {
    // Set external user id for targeting
    await OneSignal.login(opts.userId);

    // Add tags for filtering
    await OneSignal.User.addTags({
      user_type: opts.userType,
      user_id: opts.userId,
      user_name: opts.userName,
      ...(opts.flatNumber ? { flat_number: opts.flatNumber } : {}),
      ...(opts.societyId ? { society_id: opts.societyId } : {}),
    });
  });
  void registerFcmWebUser({
    userType: opts.userType,
    userId: opts.userId,
    userName: opts.userName,
    flatNumber: opts.flatNumber,
    societyId: opts.societyId ?? null,
  });
};

/** Prompt for push notification permission */
export const promptPushPermission = () => {
  window.OneSignalDeferred = window.OneSignalDeferred || [];
  window.OneSignalDeferred.push(async (OneSignal: any) => {
    await OneSignal.Slidedown.promptPush();
  });
};
