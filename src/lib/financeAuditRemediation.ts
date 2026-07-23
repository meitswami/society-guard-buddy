import { supabase } from '@/integrations/supabase/client';
import type { SupabaseClient } from '@supabase/supabase-js';
import { format } from 'date-fns';
import {
  findMonthlyMaintenanceMonthConflicts,
  findReceiptHeadConflicts,
  type AuditPaymentRow,
  type ReceiptHeadRecordingTarget,
} from '@/lib/financeAuditDetection';

export async function queryReceiptHeadConflicts(
  client: SupabaseClient,
  opts: {
    chargeId: string;
    paymentMethod?: string;
    targets: { flatNumber: string; dueDate: string }[];
    /** When recording a monthly maintenance charge, pass all monthly-maint charge ids. */
    monthlyMaintenanceChargeIds?: string[];
  },
): Promise<AuditPaymentRow[]> {
  const flatNumbers = [...new Set(opts.targets.map((t) => t.flatNumber))];
  if (flatNumbers.length === 0 || !opts.chargeId) return [];

  const monthlyIds = opts.monthlyMaintenanceChargeIds ?? [];
  const isMonthlyMaint = monthlyIds.includes(opts.chargeId);
  const chargeIds = isMonthlyMaint ? [...new Set(monthlyIds)] : [opts.chargeId];

  const { data, error } = await client
    .from('maintenance_payments')
    .select(
      'id, charge_id, flat_number, amount, payment_method, due_date, payment_date, created_at, payment_status, transaction_id, notes, finance_entry_id',
    )
    .in('charge_id', chargeIds)
    .in('flat_number', flatNumbers)
    .in('payment_status', ['verified', 'pending']);

  if (error || !data) return [];

  if (isMonthlyMaint) {
    return findMonthlyMaintenanceMonthConflicts(
      data as AuditPaymentRow[],
      chargeIds,
      opts.targets,
    );
  }

  const recordingTargets: ReceiptHeadRecordingTarget[] = opts.targets.map((t) => ({
    flatNumber: t.flatNumber,
    dueDate: t.dueDate,
    chargeId: opts.chargeId,
    paymentMethod: opts.paymentMethod,
  }));

  return findReceiptHeadConflicts(data as AuditPaymentRow[], recordingTargets);
}

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
