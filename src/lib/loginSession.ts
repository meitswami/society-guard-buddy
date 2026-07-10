import { auditLoginSuccess, auditBiometricLogin } from '@/lib/auditLogger';
import { registerOneSignalUser, promptPushPermission } from '@/lib/onesignal';

type AppUserType = 'admin' | 'guard' | 'resident';

type LoginSessionOpts = {
  userType: AppUserType;
  userId: string;
  userName: string;
  societyId?: string | null;
  flatNumber?: string;
  method?: string;
};

/** Audit success, register push targeting, and prompt for notification permission. */
export function completeLoginSession(opts: LoginSessionOpts) {
  auditLoginSuccess(opts.userType, opts.userId, opts.userName, opts.method);
  registerOneSignalUser({
    userType: opts.userType,
    userId: opts.userId,
    userName: opts.userName,
    flatNumber: opts.flatNumber,
    societyId: opts.societyId,
  });
  promptPushPermission();
}

/** Same as completeLoginSession but records a biometric login audit event. */
export function completeBiometricLoginSession(opts: Omit<LoginSessionOpts, 'method'>) {
  auditBiometricLogin(opts.userType, opts.userId, opts.userName);
  registerOneSignalUser({
    userType: opts.userType,
    userId: opts.userId,
    userName: opts.userName,
    flatNumber: opts.flatNumber,
    societyId: opts.societyId,
  });
  promptPushPermission();
}
