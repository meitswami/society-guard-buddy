import { supabase } from '@/integrations/supabase/client';

export type SocietySignupDraft = {
  society_name: string;
  address?: string;
  city?: string;
  state?: string;
  pincode?: string;
  blocks_csv?: string;
  total_floors?: string;
  flats_per_floor?: string;
  flat_series_start?: string;
  flat_series_end?: string;
  contact_person?: string;
  contact_phone: string;
  contact_email?: string;
  referral_code?: string;
  admin_id: string;
  admin_password: string;
};

export async function phonepeInitOrder(input: SocietySignupDraft): Promise<{
  signupId: string;
  token: string;
  amountInr: number;
  redirectUrl: string;
}> {
  const { data, error } = await supabase.functions.invoke('phonepe-init-order', {
    body: input,
  });
  if (error) throw error;
  return data as any;
}

export async function phonepePollStatus(input: { signupId: string; token: string }): Promise<{
  signupId: string;
  status: string;
  societyName: string;
  order: null | { status: string; merchant_transaction_id: string; amount_inr: number; created_at: string };
}> {
  const { data, error } = await supabase.functions.invoke('phonepe-poll-status', {
    body: input,
  });
  if (error) throw error;
  return data as any;
}

