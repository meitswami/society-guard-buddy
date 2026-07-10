import { supabase } from '@/integrations/supabase/client';
import {
  buildCurrentMonthChargeTitle,
  isCurrentMonthChargeTitle,
  isMonthlyMaintenanceCharge,
  normalizeTitle,
} from '@/lib/financeChargeHelpers';
import type {
  EventContribRefRow,
  EventFoodRefRow,
  FinanceLedgerRow,
  SocietyFlatRow,
} from '@/lib/financeManagerTypes';
import type {
  FinancePeriodLedgerEntry,
  FinancePeriodPayment,
  FinancePeriodReserveTransfer,
} from '@/lib/financePeriodReport';
import { sortFlatsByNumber } from '@/lib/flatMultiSelectOptions';

export type FinanceReminderSchedule = 'once_12pm' | 'twice_12pm_7pm';

export type SocietyFinanceCoreData = {
  flats: SocietyFlatRow[];
  primaryByFlatId: Record<string, string>;
  societyName: string;
  residentUsers: { id: string; name: string; flat_number: string; flat_id: string }[];
  autoReminderEnabled: boolean;
  autoReminderSchedule: FinanceReminderSchedule;
  charges: unknown[];
  paymentExpenseGroups: { id: string; name: string; major_head: string | null }[];
  payments: unknown[];
  ledgerEntries: FinanceLedgerRow[];
  expenseCategoryById: Record<string, string>;
};

export type FinanceFlatReportData = {
  expenses: Array<Record<string, unknown> & { group_name: string }>;
  splits: Array<Record<string, unknown>>;
};

export type FinanceEventReferenceData = {
  contributions: EventContribRefRow[];
  foodExpenses: EventFoodRefRow[];
};

export type SocietyFinanceReportData = {
  payments: FinancePeriodPayment[];
  ledgerEntries: FinancePeriodLedgerEntry[];
  expenseCategoryById: Record<string, string>;
  reserveTransfers: FinancePeriodReserveTransfer[];
};

const emptyCoreData = (): SocietyFinanceCoreData => ({
  flats: [],
  primaryByFlatId: {},
  societyName: '',
  residentUsers: [],
  autoReminderEnabled: true,
  autoReminderSchedule: 'once_12pm',
  charges: [],
  paymentExpenseGroups: [],
  payments: [],
  ledgerEntries: [],
  expenseCategoryById: {},
});

export async function fetchSocietyFinanceCore(
  societyId: string,
  adminName: string,
): Promise<SocietyFinanceCoreData> {
  const { data: flatRows } = await supabase
    .from('flats')
    .select('flat_number, id, owner_name, is_occupied')
    .eq('society_id', societyId)
    .order('flat_number');
  const flats = sortFlatsByNumber(flatRows ?? []);
  const flatIds = flats.map((x) => x.id);

  const primaryByFlatId: Record<string, string> = {};
  if (flatIds.length > 0) {
    const { data: memberRows } = await supabase
      .from('members')
      .select('flat_id, name')
      .eq('is_primary', true)
      .in('flat_id', flatIds);
    for (const row of memberRows ?? []) {
      if (row.flat_id && row.name?.trim()) primaryByFlatId[row.flat_id] = row.name.trim();
    }
  }

  const { data: societyRow } = await supabase.from('societies').select('name').eq('id', societyId).maybeSingle();
  const societyName = (societyRow as { name?: string } | null)?.name ?? '';

  let residentUsers: SocietyFinanceCoreData['residentUsers'] = [];
  if (flatIds.length > 0) {
    const { data: residentRows } = await supabase
      .from('resident_users')
      .select('id, name, flat_number, flat_id')
      .in('flat_id', flatIds)
      .order('flat_number');
    residentUsers = (residentRows ?? []) as SocietyFinanceCoreData['residentUsers'];
  }

  let autoReminderEnabled = true;
  let autoReminderSchedule: FinanceReminderSchedule = 'once_12pm';
  const { data: reminderSetting } = await (supabase as any)
    .from('finance_reminder_settings')
    .select('enabled, schedule')
    .eq('society_id', societyId)
    .maybeSingle();
  if (reminderSetting) {
    autoReminderEnabled = !!reminderSetting.enabled;
    autoReminderSchedule = reminderSetting.schedule === 'twice_12pm_7pm' ? 'twice_12pm_7pm' : 'once_12pm';
  }

  const { data: chargeData } = await supabase
    .from('maintenance_charges')
    .select('*')
    .eq('society_id', societyId)
    .order('created_at', { ascending: false });
  let charges = chargeData ?? [];

  const monthlyMaintenanceCharges = charges.filter(isMonthlyMaintenanceCharge);
  const hasCurrentMonthCharge = monthlyMaintenanceCharges.some((row) => isCurrentMonthChargeTitle(row.title));
  const templateCharge = monthlyMaintenanceCharges[0];

  if (!hasCurrentMonthCharge && templateCharge) {
    const currentTitle = buildCurrentMonthChargeTitle();
    const looksLikeCurrentChargeAlreadyExists = charges.some(
      (row) => normalizeTitle(row.title) === normalizeTitle(currentTitle),
    );
    if (!looksLikeCurrentChargeAlreadyExists) {
      const { error: createMonthErr } = await supabase.from('maintenance_charges').insert([
        {
          title: currentTitle,
          amount: Number(templateCharge.amount) || 0,
          frequency: 'monthly',
          due_day: Number(templateCharge.due_day) || 1,
          created_by: adminName,
          society_id: societyId,
        },
      ]);
      if (!createMonthErr) {
        const { data: refreshedCharges } = await supabase
          .from('maintenance_charges')
          .select('*')
          .eq('society_id', societyId)
          .order('created_at', { ascending: false });
        charges = refreshedCharges ?? charges;
      }
    }
  }

  const { data: paymentGroups } = await supabase
    .from('expense_groups')
    .select('id, name, major_head')
    .eq('society_id', societyId)
    .eq('group_kind', 'general')
    .order('name');
  const paymentExpenseGroups = (paymentGroups ?? []) as SocietyFinanceCoreData['paymentExpenseGroups'];

  const chargeIds = charges.map((x) => x.id);
  let payments: unknown[] = [];
  if (chargeIds.length > 0) {
    const { data: paymentRows, error: paymentError } = await supabase
      .from('maintenance_payments')
      .select('*')
      .in('charge_id', chargeIds)
      .order('created_at', { ascending: false })
      .limit(2500);
    if (paymentError) throw new Error(paymentError.message);
    payments = paymentRows ?? [];
  }

  const { data: ledgerRows, error: ledgerError } = await supabase
    .from('finance_entries')
    .select('*, finance_entry_counterparties(*), finance_entry_allocations(*)')
    .eq('society_id', societyId)
    .order('created_at', { ascending: false })
    .limit(2500);
  if (ledgerError) throw new Error(ledgerError.message);
  const ledgerEntries = (ledgerRows ?? []) as FinanceLedgerRow[];

  const expenseCategoryById: Record<string, string> = {};
  const linkedExpenseIds = ledgerEntries.map((e) => e.expense_id).filter((id): id is string => Boolean(id));
  if (linkedExpenseIds.length > 0) {
    const { data: expenseCategories, error: categoryError } = await supabase
      .from('expenses')
      .select('id, expense_category')
      .in('id', linkedExpenseIds);
    if (categoryError) throw new Error(categoryError.message);
    for (const row of expenseCategories ?? []) {
      expenseCategoryById[String(row.id)] = String(row.expense_category ?? '');
    }
  }

  return {
    flats,
    primaryByFlatId,
    societyName,
    residentUsers,
    autoReminderEnabled,
    autoReminderSchedule,
    charges,
    paymentExpenseGroups,
    payments,
    ledgerEntries,
    expenseCategoryById,
  };
}

export async function fetchSocietyFinanceCoreSafe(
  societyId: string | null | undefined,
  adminName: string,
): Promise<SocietyFinanceCoreData> {
  if (!societyId) return emptyCoreData();
  return fetchSocietyFinanceCore(societyId, adminName);
}

export async function fetchFinanceFlatReport(societyId: string): Promise<FinanceFlatReportData> {
  const { data: groupRows, error: groupError } = await supabase
    .from('expense_groups')
    .select('id, name')
    .eq('society_id', societyId)
    .eq('group_kind', 'general');
  if (groupError) throw new Error(groupError.message);

  const groupIds = (groupRows ?? []).map((g) => g.id);
  let expenses: FinanceFlatReportData['expenses'] = [];
  let splits: FinanceFlatReportData['splits'] = [];

  if (groupIds.length > 0) {
    const { data: expenseRows, error: expenseError } = await supabase
      .from('expenses')
      .select(
        'id, title, total_amount, expense_date, payment_method, vendor_or_service, service_kind, group_id, split_type, paid_by_flat, paid_by_flats, record_status',
      )
      .in('group_id', groupIds)
      .eq('record_status', 'active')
      .eq('expense_category', 'payment');
    if (expenseError) throw new Error(expenseError.message);

    const expRows = expenseRows ?? [];
    const expIds = expRows.map((e) => e.id);
    if (expIds.length > 0) {
      const { data: splitRows, error: splitError } = await supabase
        .from('expense_splits')
        .select('id, expense_id, flat_number, amount, is_settled, settled_at')
        .in('expense_id', expIds);
      if (splitError) throw new Error(splitError.message);
      splits = splitRows ?? [];
    }

    expenses = expRows.map((e) => ({
      ...e,
      group_name: groupRows?.find((g) => g.id === e.group_id)?.name ?? 'Unknown group',
    }));
  }

  return { expenses, splits };
}

export async function fetchFinanceEventReference(societyId: string): Promise<FinanceEventReferenceData> {
  const { data: events, error: eventsError } = await supabase
    .from('events')
    .select('id, title')
    .eq('society_id', societyId)
    .order('event_date', { ascending: false })
    .limit(100);
  if (eventsError) throw new Error(eventsError.message);

  const eventIds = (events ?? []).map((e) => e.id);
  const eventTitleById = new Map((events ?? []).map((e) => [String(e.id), String(e.title)]));

  const { data: groups, error: groupsError } = await supabase
    .from('expense_groups')
    .select('id, name, event_id')
    .eq('society_id', societyId)
    .eq('group_kind', 'event');
  if (groupsError) throw new Error(groupsError.message);

  const groupIds = (groups ?? []).map((g) => g.id);
  const groupById = new Map((groups ?? []).map((g) => [String(g.id), g]));

  const [contribRes, expRes] = await Promise.all([
    eventIds.length
      ? supabase
          .from('event_contributions')
          .select('*')
          .in('event_id', eventIds)
          .order('verified_at', { ascending: false })
          .limit(150)
      : Promise.resolve({ data: [], error: null }),
    groupIds.length
      ? supabase
          .from('expenses')
          .select('id, title, total_amount, expense_date, payment_method, bill_screenshot_url, group_id')
          .in('group_id', groupIds)
          .eq('expense_category', 'food')
          .eq('record_status', 'active')
          .order('expense_date', { ascending: false })
          .limit(150)
      : Promise.resolve({ data: [], error: null }),
  ]);

  if (contribRes.error) throw new Error(contribRes.error.message);
  if (expRes.error) throw new Error(expRes.error.message);

  const contributions = (contribRes.data ?? []).map((c) => ({
    ...(c as EventContribRefRow),
    event_title: eventTitleById.get(String((c as { event_id: string }).event_id)) ?? 'Event',
  }));

  const foodExpenses = (expRes.data ?? []).map((ex) => {
    const g = groupById.get(String(ex.group_id));
    return {
      ...(ex as Omit<EventFoodRefRow, 'group_name' | 'event_title'>),
      group_name: g?.name ?? 'Food group',
      event_title: g?.event_id ? eventTitleById.get(String(g.event_id)) ?? null : null,
    };
  });

  return { contributions, foodExpenses };
}

export async function fetchSocietyFinanceReportData(societyId: string): Promise<SocietyFinanceReportData> {
  const { data: chargeRows, error: chargeError } = await supabase
    .from('maintenance_charges')
    .select('id')
    .eq('society_id', societyId);
  if (chargeError) throw new Error(chargeError.message);

  const chargeIds = (chargeRows as { id: string }[] | null)?.map((c) => c.id) ?? [];

  let payments: FinancePeriodPayment[] = [];
  if (chargeIds.length > 0) {
    const { data: paymentRows, error: paymentError } = await supabase
      .from('maintenance_payments')
      .select(
        'id, payment_status, amount, payment_method, due_date, finance_entry_id, flat_number, created_at, notes, transaction_id, resident_name, charge_id',
      )
      .in('charge_id', chargeIds)
      .order('created_at', { ascending: false })
      .limit(2500);
    if (paymentError) throw new Error(paymentError.message);
    payments = (paymentRows as FinancePeriodPayment[]) ?? [];
  }

  const { data: ledgerRows, error: ledgerError } = await supabase
    .from('finance_entries')
    .select(
      'id, record_mode, destination, total_amount, entry_month, created_at, payment_status, payment_method, title, notes, transaction_id, transaction_date, expense_id, charge_id, aggregate_flat_count',
    )
    .eq('society_id', societyId)
    .order('created_at', { ascending: false })
    .limit(2500);
  if (ledgerError) throw new Error(ledgerError.message);
  const ledgerEntries = (ledgerRows as FinancePeriodLedgerEntry[]) ?? [];

  const expenseCategoryById: Record<string, string> = {};
  const linkedExpenseIds = ledgerEntries.map((e) => e.expense_id).filter((id): id is string => Boolean(id));
  if (linkedExpenseIds.length > 0) {
    const { data: expenseCategories, error: categoryError } = await supabase
      .from('expenses')
      .select('id, expense_category')
      .in('id', linkedExpenseIds);
    if (categoryError) throw new Error(categoryError.message);
    for (const ex of expenseCategories ?? []) {
      expenseCategoryById[ex.id] = ex.expense_category;
    }
  }

  const { data: reserveRows, error: reserveError } = await supabase
    .from('reserve_fund_transfers')
    .select('id, entry_month, amount, direction, payment_method, notes, created_at')
    .eq('society_id', societyId)
    .order('entry_month', { ascending: false })
    .limit(500);
  if (reserveError) throw new Error(reserveError.message);

  return {
    payments,
    ledgerEntries,
    expenseCategoryById,
    reserveTransfers: reserveRows ?? [],
  };
}

export async function fetchLatestFinancePeriodReportBatch(societyId: string): Promise<string | null> {
  const { data, error } = await supabase
    .from('notifications')
    .select('delivery_batch_id')
    .eq('society_id', societyId)
    .eq('type', 'finance_period_report')
    .not('delivery_batch_id', 'is', null)
    .order('created_at', { ascending: false })
    .limit(1);
  if (error) throw new Error(error.message);
  return (data?.[0] as { delivery_batch_id?: string } | undefined)?.delivery_batch_id ?? null;
}
