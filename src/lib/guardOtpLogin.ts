import { supabase } from '@/integrations/supabase/client';
import { normalizeLoginPhone } from '@/lib/residentLoginOnboarding';

export type GuardRow = {
  id: string;
  guard_id: string;
  name: string;
  password: string;
  phone: string | null;
  auth_mode: string | null;
  society_id: string | null;
};

export type GuardOtpLookupResult =
  | { ok: true; guard: GuardRow }
  | { ok: false; reason: 'not_found' | 'password_mode' | 'no_phone' };

/** Find a guard in this society whose registered phone matches (OTP login). */
export async function findGuardForOtpLogin(phone: string, societyId: string): Promise<GuardOtpLookupResult> {
  const normalized = normalizeLoginPhone(phone);
  if (normalized.length < 10) {
    return { ok: false, reason: 'not_found' };
  }

  const { data, error } = await supabase.from('guards').select('*').eq('society_id', societyId);
  if (error || !data?.length) {
    return { ok: false, reason: 'not_found' };
  }

  const withPhone = data.filter((g) => g.phone && normalizeLoginPhone(g.phone) === normalized);
  if (withPhone.length === 0) {
    return { ok: false, reason: 'not_found' };
  }

  const otpGuard = withPhone.find((g) => g.auth_mode === 'otp');
  if (otpGuard) {
    return { ok: true, guard: otpGuard as GuardRow };
  }

  return { ok: false, reason: 'password_mode' };
}
