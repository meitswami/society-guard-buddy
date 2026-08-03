const KEY = 'sgb_login_remember_v1';

export type LoginRememberRole = 'guard' | 'admin' | 'resident';

export type LoginRememberV1 = {
  v: 1;
  societyId?: string;
  role?: LoginRememberRole;
  flatId?: string;
  /** Last used mobile / phone (digits), for resident or guard OTP / password login. */
  phone?: string;
};

function normalizePhone(phone: string | undefined): string | undefined {
  if (!phone) return undefined;
  const digits = phone.replace(/\D/g, '').slice(-10);
  return digits.length >= 10 ? digits : phone.replace(/\D/g, '') || undefined;
}

export function readLoginRemember(): LoginRememberV1 | null {
  try {
    const raw = localStorage.getItem(KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as LoginRememberV1;
    if (parsed?.v !== 1) return null;
    return parsed;
  } catch {
    return null;
  }
}

/** Merge-patch remembered login fields (flat + mobile stay editable in the UI). */
export function writeLoginRemember(patch: Partial<Omit<LoginRememberV1, 'v'>>): void {
  try {
    const prev = readLoginRemember() ?? { v: 1 as const };
    const next: LoginRememberV1 = { ...prev, v: 1 };

    if ('societyId' in patch) {
      next.societyId = patch.societyId?.trim() || undefined;
    }
    if ('role' in patch) {
      next.role = patch.role || undefined;
    }
    if ('flatId' in patch) {
      next.flatId = patch.flatId?.trim() || undefined;
    }
    if ('phone' in patch) {
      next.phone = normalizePhone(patch.phone);
    }

    localStorage.setItem(KEY, JSON.stringify(next));
  } catch {
    /* quota / private mode */
  }
}
