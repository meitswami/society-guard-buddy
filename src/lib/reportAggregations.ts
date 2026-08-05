import { supabase } from '@/integrations/supabase/client';
import { ledgerTransactionDate } from '@/lib/financeDates';
import type { FinancePeriodLedgerEntry } from '@/lib/financePeriodReport';

export type StatusBucket = { payment_status?: string; status?: string; count: number; total: number };

export type MaintenanceLinkSummary = {
  linked: { count: number; total: number };
  unlinked: { count: number; total: number };
};

export type ReportModuleAggregations = {
  maintenanceStatuses: StatusBucket[];
  maintenanceLinkSummary: MaintenanceLinkSummary | null;
  donationStatuses: StatusBucket[];
  splitStatuses: StatusBucket[];
};

function bucketByKey<T>(
  rows: T[],
  keyFn: (row: T) => string,
  amountFn: (row: T) => number,
): StatusBucket[] {
  const map = new Map<string, { count: number; total: number }>();
  for (const row of rows) {
    const key = keyFn(row);
    const cur = map.get(key) ?? { count: 0, total: 0 };
    cur.count += 1;
    cur.total += amountFn(row);
    map.set(key, cur);
  }
  return [...map.entries()].map(([key, v]) => ({
    payment_status: key,
    status: key,
    ...v,
  }));
}

/** Ledger payment-status buckets for a filtered entry set. */
export function computeLedgerStatusBuckets(entries: FinancePeriodLedgerEntry[]): StatusBucket[] {
  return bucketByKey(
    entries,
    (e) => String(e.payment_status ?? 'verified'),
    (e) => Number(e.total_amount || 0),
  );
}

export type LedgerInflowGroup = {
  record_mode: string;
  destination: string;
  total: number;
  flatUnits: number;
  count: number;
};

/** Group ledger inflows by record_mode + destination (shared by Report page and Finance totals). */
export function computeLedgerInflowGroups(
  entries: Array<{
    record_mode?: string;
    destination: string;
    total_amount?: number;
    aggregate_flat_count?: number;
  }>,
  options?: { excludeSeparateEntry?: boolean },
): LedgerInflowGroup[] {
  const excludeSeparateEntry = options?.excludeSeparateEntry ?? false;
  const map = new Map<string, { total: number; flatUnits: number; count: number }>();
  for (const e of entries) {
    if (excludeSeparateEntry && e.destination === 'separate_entry') continue;
    const key = `${e.record_mode ?? ''}||${e.destination}`;
    const cur = map.get(key) ?? { total: 0, flatUnits: 0, count: 0 };
    cur.total += Number(e.total_amount || 0);
    cur.flatUnits += Number(e.aggregate_flat_count || 0);
    cur.count += 1;
    map.set(key, cur);
  }
  return [...map.entries()].map(([k, v]) => {
    const [record_mode, destination] = k.split('||');
    return { record_mode, destination, ...v };
  });
}

/** Filter ledger entries to an inclusive transaction-date range. */
export function filterLedgerByTransactionDateRange(
  entries: FinancePeriodLedgerEntry[],
  from: string,
  to: string,
): FinancePeriodLedgerEntry[] {
  return entries.filter((e) => {
    const d = ledgerTransactionDate(e);
    return d >= from && d <= to;
  });
}

/** Fetch maintenance, donation, and split status aggregates for a report period. */
export async function fetchReportModuleAggregations(
  societyId: string,
  periodFrom: string,
  periodTo: string,
): Promise<ReportModuleAggregations> {
  if (periodFrom > periodTo) {
    return {
      maintenanceStatuses: [],
      maintenanceLinkSummary: null,
      donationStatuses: [],
      splitStatuses: [],
    };
  }

  const from = `${periodFrom}T00:00:00`;
  const to = `${periodTo}T23:59:59`;

  const [chargeRes, campRes, groupsRes] = await Promise.all([
    supabase.from('maintenance_charges').select('id').eq('society_id', societyId),
    supabase.from('donation_campaigns').select('id').eq('society_id', societyId),
    supabase.from('expense_groups').select('id').eq('society_id', societyId).eq('group_kind', 'general'),
  ]);

  const chargeIds = (chargeRes.data as { id: string }[] | null)?.map((c) => c.id) ?? [];
  const campIds = (campRes.data as { id: string }[] | null)?.map((c) => c.id) ?? [];
  const groupIds = (groupsRes.data as { id: string }[] | null)?.map((g) => g.id) ?? [];

  const [mpRes, dpRes, exRes] = await Promise.all([
    chargeIds.length > 0
      ? supabase
          .from('maintenance_payments')
          .select('payment_status, amount, finance_entry_id')
          .in('charge_id', chargeIds)
          .gte('due_date', periodFrom)
          .lte('due_date', periodTo)
      : Promise.resolve({ data: [] as { payment_status?: string; amount: number; finance_entry_id: string | null }[], error: null }),
    campIds.length > 0
      ? supabase
          .from('donation_payments')
          .select('amount, verified_at')
          .in('campaign_id', campIds)
          .gte('created_at', from)
          .lte('created_at', to)
      : Promise.resolve({ data: [] as { amount: number; verified_at: string | null }[], error: null }),
    groupIds.length > 0
      ? supabase
          .from('expenses')
          .select('id')
          .in('group_id', groupIds)
          .eq('record_status', 'active')
          .eq('expense_category', 'payment')
          .gte('expense_date', periodFrom)
          .lte('expense_date', periodTo)
      : Promise.resolve({ data: [] as { id: string }[], error: null }),
  ]);

  const rows =
    (mpRes.data as { payment_status?: string; amount: number; finance_entry_id: string | null }[] | null) ?? [];
  const maintenanceStatuses = bucketByKey(
    rows,
    (p) => String(p.payment_status ?? 'pending'),
    (p) => Number(p.amount || 0),
  );
  let linkedCount = 0;
  let linkedTotal = 0;
  let unlinkedCount = 0;
  let unlinkedTotal = 0;
  for (const p of rows) {
    const amt = Number(p.amount || 0);
    if (p.finance_entry_id) {
      linkedCount += 1;
      linkedTotal += amt;
    } else {
      unlinkedCount += 1;
      unlinkedTotal += amt;
    }
  }
  const maintenanceLinkSummary: MaintenanceLinkSummary | null =
    rows.length > 0
      ? { linked: { count: linkedCount, total: linkedTotal }, unlinked: { count: unlinkedCount, total: unlinkedTotal } }
      : null;

  const donationStatuses = bucketByKey(
    (dpRes.data as { amount: number; verified_at: string | null }[] | null) ?? [],
    (p) => (p.verified_at ? 'verified' : 'pending'),
    (p) => Number(p.amount || 0),
  );

  const expIds = (exRes.data as { id: string }[] | null)?.map((x) => x.id) ?? [];
  let splitStatuses: StatusBucket[] = [];
  if (expIds.length > 0) {
    const { data: splits } = await supabase.from('expense_splits').select('amount, is_settled').in('expense_id', expIds);
    splitStatuses = bucketByKey(
      (splits as { amount: number; is_settled: boolean }[] | null) ?? [],
      (s) => (s.is_settled ? 'settled' : 'pending'),
      (s) => Number(s.amount || 0),
    );
  }

  return { maintenanceStatuses, maintenanceLinkSummary, donationStatuses, splitStatuses };
}
