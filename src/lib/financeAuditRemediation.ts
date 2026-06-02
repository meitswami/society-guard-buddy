import { supabase } from '@/integrations/supabase/client';
import { format } from 'date-fns';

export async function deleteMaintenancePayment(paymentId: string, financeEntryId: string | null) {
  const { error } = await supabase.from('maintenance_payments').delete().eq('id', paymentId);
  if (error) return { ok: false as const, error: error.message };

  if (financeEntryId) {
    const { data: remaining } = await supabase
      .from('maintenance_payments')
      .select('id')
      .eq('finance_entry_id', financeEntryId);
    if (!remaining || remaining.length === 0) {
      await supabase.from('finance_entry_allocations').delete().eq('finance_entry_id', financeEntryId);
      await supabase.from('finance_entry_counterparties').delete().eq('finance_entry_id', financeEntryId);
      await supabase.from('finance_entries').delete().eq('id', financeEntryId);
    }
  }

  return { ok: true as const };
}

export async function deleteOrphanLedgerEntry(entryId: string) {
  const { data: linked } = await supabase
    .from('maintenance_payments')
    .select('id')
    .eq('finance_entry_id', entryId);
  if (linked && linked.length > 0) {
    return {
      ok: false as const,
      error: 'This ledger entry still has linked payments. Remove or relink payments first.',
    };
  }

  await supabase.from('finance_entry_allocations').delete().eq('finance_entry_id', entryId);
  await supabase.from('finance_entry_counterparties').delete().eq('finance_entry_id', entryId);
  const { error } = await supabase.from('finance_entries').delete().eq('id', entryId);
  if (error) return { ok: false as const, error: error.message };
  return { ok: true as const };
}

export async function alignPaymentDueToMonth(paymentId: string, yyyyMm: string) {
  const dueDate = `${yyyyMm}-01`;
  const { error } = await supabase
    .from('maintenance_payments')
    .update({ due_date: dueDate })
    .eq('id', paymentId);
  if (error) return { ok: false as const, error: error.message };
  return { ok: true as const, dueDate };
}

export async function alignLedgerEntryMonth(entryId: string, yyyyMm: string) {
  const { error } = await supabase
    .from('finance_entries')
    .update({ entry_month: yyyyMm })
    .eq('id', entryId);
  if (error) return { ok: false as const, error: error.message };
  return { ok: true as const };
}

export function paymentMonthKey(p: { due_date?: string | null; payment_date?: string | null; created_at?: string }) {
  const d = p.due_date || p.payment_date || p.created_at || '';
  return d ? format(new Date(d), 'yyyy-MM') : '';
}
