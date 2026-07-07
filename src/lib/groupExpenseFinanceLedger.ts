import { format, isValid, parse } from 'date-fns';
import type { SupabaseClient } from '@supabase/supabase-js';
import { buildGroupExpenseLedgerTitle, joinNoteLines } from '@/lib/financeExpenseHead';

export function entryMonthFromExpenseDate(expenseDate: string): string {
  const d = parse(expenseDate, 'yyyy-MM-dd', new Date());
  return isValid(d) ? format(d, 'yyyy-MM') : format(new Date(), 'yyyy-MM');
}

function allocationStyleForAmounts(amounts: number[]): 'split_total_equally' | 'none' {
  if (amounts.length === 0) return 'none';
  const first = amounts[0];
  const allEq = amounts.every((a) => Math.abs(a - first) < 0.005);
  return allEq ? 'split_total_equally' : 'none';
}

/** Mirrors Finance “outsider only” + `separate_entry` for society books (outflow). */
export async function insertFinanceLedgerForGroupExpense(
  client: SupabaseClient,
  opts: {
    societyId: string;
    adminName: string;
    groupName: string;
    expenseId: string;
    title: string;
    total: number;
    expenseDate: string;
    payment_method: string;
    screenshot_url: string | null;
    notes: string | null;
    vendor_or_service: string | null;
    allocationSplits: { flat_number: string; amount: number }[];
    flats: { id: string; flat_number: string }[];
    counterpartyName: string;
    counterpartyRelation: string | null;
    expenseCategory: 'food' | 'payment';
    eventTitle?: string | null;
  },
): Promise<{ error: string | null }> {
  const transaction_date = opts.expenseDate.slice(0, 10);
  const entry_month = entryMonthFromExpenseDate(transaction_date);
  const amounts = opts.allocationSplits.map((s) => s.amount);
  const sum = Number(amounts.reduce((a, b) => a + b, 0).toFixed(2));
  if (Math.abs(sum - opts.total) > 0.02) {
    return { error: 'Split amounts do not match expense total for ledger' };
  }
  const allocation_style = allocationStyleForAmounts(amounts);
  const { ledgerTitle, detailNote } = buildGroupExpenseLedgerTitle({
    expenseCategory: opts.expenseCategory,
    groupName: opts.groupName,
    expenseTitle: opts.title,
    eventTitle: opts.eventTitle,
  });
  const notes = joinNoteLines([
    detailNote,
    opts.notes?.trim() || null,
    opts.vendor_or_service?.trim() ? `Vendor: ${opts.vendor_or_service.trim()}` : null,
  ]);

  const { data: fe, error: feErr } = await client
    .from('finance_entries')
    .insert({
      society_id: opts.societyId,
      record_mode: 'outsider_only',
      destination: 'separate_entry',
      allocation_style,
      include_vacant: false,
      entry_month,
      transaction_date,
      total_amount: opts.total,
      aggregate_flat_count: opts.allocationSplits.length,
      charge_id: null,
      title: ledgerTitle,
      notes,
      screenshot_url: opts.screenshot_url,
      transaction_id: null,
      payment_method: opts.payment_method,
      payment_status: 'verified',
      created_by: opts.adminName,
      expense_id: opts.expenseId,
    })
    .select('id')
    .single();

  if (feErr || !fe?.id) {
    return { error: feErr?.message ?? 'Could not create finance ledger entry' };
  }

  const entryId = fe.id as string;

  const { error: cpErr } = await client.from('finance_entry_counterparties').insert({
    finance_entry_id: entryId,
    name: opts.counterpartyName.slice(0, 500),
    relation_to_society: opts.counterpartyRelation ? opts.counterpartyRelation.slice(0, 500) : null,
  });
  if (cpErr) {
    await client.from('finance_entries').delete().eq('id', entryId);
    return { error: cpErr.message };
  }

  const flatIdByNumber = new Map(opts.flats.map((f) => [f.flat_number, f.id]));
  const allocRows = opts.allocationSplits.map((s) => ({
    finance_entry_id: entryId,
    flat_id: flatIdByNumber.get(s.flat_number) ?? null,
    flat_number: s.flat_number,
    amount: s.amount,
  }));

  const { error: allocErr } = await client.from('finance_entry_allocations').insert(allocRows);
  if (allocErr) {
    await client.from('finance_entries').delete().eq('id', entryId);
    return { error: allocErr.message };
  }

  return { error: null };
}

export async function syncFinanceLedgerFromGroupExpenseEdit(
  client: SupabaseClient,
  opts: {
    societyId: string;
    adminName: string;
    groupName: string;
    expenseId: string;
    title: string;
    total: number;
    expenseDate: string;
    payment_method: string;
    screenshot_url?: string | null;
    notes: string | null;
    vendor_or_service: string | null;
    flats: { id: string; flat_number: string }[];
    /** If no splits (society fund), single SOCIETY row */
    allocationSplits: { flat_number: string; amount: number }[];
    counterpartyName: string;
    counterpartyRelation: string | null;
    expenseCategory: 'food' | 'payment';
    eventTitle?: string | null;
  },
): Promise<{ error: string | null }> {
  const { data: fe, error: findErr } = await client.from('finance_entries').select('id').eq('expense_id', opts.expenseId).maybeSingle();
  if (findErr) return { error: findErr.message };
  if (!fe?.id) {
    return insertFinanceLedgerForGroupExpense(client, {
      societyId: opts.societyId,
      adminName: opts.adminName,
      groupName: opts.groupName,
      expenseId: opts.expenseId,
      title: opts.title,
      total: opts.total,
      expenseDate: opts.expenseDate,
      payment_method: opts.payment_method,
      screenshot_url: opts.screenshot_url ?? null,
      notes: opts.notes,
      vendor_or_service: opts.vendor_or_service,
      allocationSplits: opts.allocationSplits,
      flats: opts.flats,
      counterpartyName: opts.counterpartyName,
      counterpartyRelation: opts.counterpartyRelation,
      expenseCategory: opts.expenseCategory,
      eventTitle: opts.eventTitle,
    });
  }

  const transaction_date = opts.expenseDate.slice(0, 10);
  const entry_month = entryMonthFromExpenseDate(transaction_date);
  const amounts = opts.allocationSplits.map((s) => s.amount);
  const sum = Number(amounts.reduce((a, b) => a + b, 0).toFixed(2));
  if (Math.abs(sum - opts.total) > 0.02) {
    return { error: 'Split amounts do not match expense total for ledger sync' };
  }
  const allocation_style = allocationStyleForAmounts(amounts);
  const { ledgerTitle, detailNote } = buildGroupExpenseLedgerTitle({
    expenseCategory: opts.expenseCategory,
    groupName: opts.groupName,
    expenseTitle: opts.title,
    eventTitle: opts.eventTitle,
  });
  const notes = joinNoteLines([
    detailNote,
    opts.notes?.trim() || null,
    opts.vendor_or_service?.trim() ? `Vendor: ${opts.vendor_or_service.trim()}` : null,
  ]);

  const { error: upErr } = await client
    .from('finance_entries')
    .update({
      entry_month,
      transaction_date,
      total_amount: opts.total,
      aggregate_flat_count: opts.allocationSplits.length,
      allocation_style,
      title: ledgerTitle,
      notes,
      payment_method: opts.payment_method,
      created_by: opts.adminName,
    })
    .eq('id', fe.id);
  if (upErr) return { error: upErr.message };

  await client.from('finance_entry_allocations').delete().eq('finance_entry_id', fe.id);

  const flatIdByNumber = new Map(opts.flats.map((f) => [f.flat_number, f.id]));
  const allocRows = opts.allocationSplits.map((s) => ({
    finance_entry_id: fe.id,
    flat_id: flatIdByNumber.get(s.flat_number) ?? null,
    flat_number: s.flat_number,
    amount: s.amount,
  }));

  const { error: insErr } = await client.from('finance_entry_allocations').insert(allocRows);
  if (insErr) return { error: insErr.message };

  const { error: cpErr } = await client
    .from('finance_entry_counterparties')
    .update({
      name: opts.counterpartyName.slice(0, 500),
      relation_to_society: opts.counterpartyRelation ? opts.counterpartyRelation.slice(0, 500) : null,
    })
    .eq('finance_entry_id', fe.id);
  if (cpErr) return { error: cpErr.message };

  return { error: null };
}
