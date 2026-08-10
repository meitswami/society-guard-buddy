import { supabase } from '@/integrations/supabase/client';
import type { SocietyBankAccount, SocietyBankAccountInput } from '@/lib/societyBankAccount';

export async function fetchPrimarySocietyBankAccount(
  societyId: string,
): Promise<SocietyBankAccount | null> {
  const { data, error } = await supabase
    .from('society_bank_accounts')
    .select('*')
    .eq('society_id', societyId)
    .eq('is_active', true)
    .eq('is_primary', true)
    .maybeSingle();

  if (error) throw new Error(error.message);
  return (data as SocietyBankAccount | null) ?? null;
}

export async function fetchSocietyBankAccounts(societyId: string): Promise<SocietyBankAccount[]> {
  const { data, error } = await supabase
    .from('society_bank_accounts')
    .select('*')
    .eq('society_id', societyId)
    .order('is_primary', { ascending: false })
    .order('created_at', { ascending: false });

  if (error) throw new Error(error.message);
  return (data as SocietyBankAccount[]) ?? [];
}

export async function upsertSocietyBankAccount(
  societyId: string,
  input: SocietyBankAccountInput,
  existingId?: string | null,
): Promise<SocietyBankAccount> {
  const payload = {
    society_id: societyId,
    bank_name: input.bank_name.trim(),
    account_holder_name: input.account_holder_name.trim(),
    account_number: input.account_number.replace(/\s+/g, ''),
    ifsc: input.ifsc.trim().toUpperCase(),
    branch_name: input.branch_name?.trim() || null,
    branch_address: input.branch_address?.trim() || null,
    micr: input.micr?.trim() || null,
    account_type: input.account_type?.trim() || null,
    currency: input.currency?.trim() || 'INR',
    upi_vpa: input.upi_vpa?.trim() || null,
    customer_id: input.customer_id?.trim() || null,
    is_primary: input.is_primary ?? true,
    is_active: input.is_active ?? true,
    effective_from: input.effective_from || null,
    effective_to: input.effective_to || null,
    notes: input.notes?.trim() || null,
  };

  if (payload.is_primary) {
    let demote = supabase
      .from('society_bank_accounts')
      .update({ is_primary: false })
      .eq('society_id', societyId)
      .eq('is_primary', true);
    if (existingId) demote = demote.neq('id', existingId);
    await demote;
  }

  if (existingId) {
    const { data, error } = await supabase
      .from('society_bank_accounts')
      .update(payload)
      .eq('id', existingId)
      .select('*')
      .single();
    if (error) throw new Error(error.message);
    return data as SocietyBankAccount;
  }

  const { data, error } = await supabase
    .from('society_bank_accounts')
    .insert(payload)
    .select('*')
    .single();
  if (error) throw new Error(error.message);
  return data as SocietyBankAccount;
}

export async function deactivateSocietyBankAccount(id: string): Promise<void> {
  const { error } = await supabase
    .from('society_bank_accounts')
    .update({ is_active: false, is_primary: false })
    .eq('id', id);
  if (error) throw new Error(error.message);
}
