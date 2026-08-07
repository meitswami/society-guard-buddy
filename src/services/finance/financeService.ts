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
  reminderDueDay: number;
  autoIssueEnabled: boolean;
  autoIssueWhatsapp: boolean;
  billSoundKey: string;
  charges: unknown[];
  paymentExpenseGroups: { id: string; name: string; major_head: string | null; description?: string | null }[];
  payments: unknown[];
  ledgerEntries: FinanceLedgerRow[];
  expenseCategoryById: Record<string, string>;
  reserveTransfers: FinancePeriodReserveTransfer[];
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
  reminderDueDay: 1,
  autoIssueEnabled: true,
  autoIssueWhatsapp: true,
  billSoundKey: 'melody',
  charges: [],
  paymentExpenseGroups: [],
  payments: [],
  ledgerEntries: [],
  expenseCategoryById: {},
  reserveTransfers: [],
});

/** Map core finance cache into period-report shape (single source for Report + Finance). */
export function derivePeriodReportDataFromCore(core: SocietyFinanceCoreData): SocietyFinanceReportData {
  return {
    payments: (core.payments ?? []) as FinancePeriodPayment[],
    ledgerEntries: core.ledgerEntries as FinancePeriodLedgerEntry[],
    expenseCategoryById: core.expenseCategoryById,
    reserveTransfers: core.reserveTransfers ?? [],
  };
}

async function ensureCurrentMonthMaintenanceCharge(
  societyId: string,
  adminName: string,
  charges: any[],
  reminderDueDay: number,
): Promise<any[]> {
  const monthlyMaintenanceCharges = charges.filter(isMonthlyMaintenanceCharge);
  const hasCurrentMonthCharge = monthlyMaintenanceCharges.some((row) => isCurrentMonthChargeTitle(row.title));
  const templateCharge = monthlyMaintenanceCharges[0];
  if (hasCurrentMonthCharge || !templateCharge) return charges;

  const currentTitle = buildCurrentMonthChargeTitle();
  if (charges.some((row) => normalizeTitle(row.title) === normalizeTitle(currentTitle))) {
    return charges;
  }

  const { data: inserted, error } = await supabase
    .from('maintenance_charges')
    .insert([
      {
        title: currentTitle,
        amount: Number(templateCharge.amount) || 0,
        frequency: 'monthly',
        due_day: reminderDueDay,
        created_by: adminName,
        society_id: societyId,
      },
    ])
    .select('*')
    .maybeSingle();

  if (error || !inserted) return charges;
  return [inserted, ...charges];
}

export async function fetchSocietyFinanceCore(
  societyId: string,
  adminName: string,
): Promise<SocietyFinanceCoreData> {
  // Wave 1: independent society-scoped reads in parallel (was ~10 serial round-trips).
  const [
    flatsRes,
    societyRes,
    reminderRes,
    chargesRes,
    paymentGroupsRes,
    ledgerRes,
    reserveRes,
  ] = await Promise.all([
    supabase
      .from('flats')
      .select('flat_number, id, owner_name, is_occupied')
      .eq('society_id', societyId)
      .order('flat_number'),
    supabase.from('societies').select('name').eq('id', societyId).maybeSingle(),
    (supabase as any)
      .from('finance_reminder_settings')
      .select('enabled, schedule, due_day, auto_issue_enabled, auto_issue_whatsapp, bill_sound_key')
      .eq('society_id', societyId)
      .maybeSingle(),
    supabase
      .from('maintenance_charges')
      .select('*')
      .eq('society_id', societyId)
      .order('created_at', { ascending: false }),
    supabase
      .from('expense_groups')
      .select('id, name, major_head, description')
      .eq('society_id', societyId)
      .eq('group_kind', 'general')
      .order('name'),
    supabase
      .from('finance_entries')
      .select('*, finance_entry_counterparties(*), finance_entry_allocations(*)')
      .eq('society_id', societyId)
      .order('created_at', { ascending: false })
      .limit(2500),
    supabase
      .from('reserve_fund_transfers')
      .select('id, entry_month, amount, direction, payment_method, notes, created_at')
      .eq('society_id', societyId)
      .order('entry_month', { ascending: false })
      .limit(500),
  ]);

  if (ledgerRes.error) throw new Error(ledgerRes.error.message);
  if (reserveRes.error) throw new Error(reserveRes.error.message);

  const flats = sortFlatsByNumber(flatsRes.data ?? []);
  const flatIds = flats.map((x) => x.id);
  const societyName = (societyRes.data as { name?: string } | null)?.name ?? '';

  let autoReminderEnabled = true;
  let autoReminderSchedule: FinanceReminderSchedule = 'once_12pm';
  let reminderDueDay = 1;
  let autoIssueEnabled = true;
  let autoIssueWhatsapp = true;
  let billSoundKey = 'melody';
  const reminderSetting = reminderRes.data;
  if (reminderSetting) {
    autoReminderEnabled = !!reminderSetting.enabled;
    autoReminderSchedule = reminderSetting.schedule === 'twice_12pm_7pm' ? 'twice_12pm_7pm' : 'once_12pm';
    reminderDueDay = Math.min(28, Math.max(1, Number(reminderSetting.due_day) || 1));
    if (typeof reminderSetting.auto_issue_enabled === 'boolean') {
      autoIssueEnabled = reminderSetting.auto_issue_enabled;
    }
    if (typeof reminderSetting.auto_issue_whatsapp === 'boolean') {
      autoIssueWhatsapp = reminderSetting.auto_issue_whatsapp;
    }
    if (reminderSetting.bill_sound_key) {
      billSoundKey = String(reminderSetting.bill_sound_key);
    }
  }

  const paymentExpenseGroups = (paymentGroupsRes.data ?? []) as SocietyFinanceCoreData['paymentExpenseGroups'];
  const ledgerEntries = (ledgerRes.data ?? []) as FinanceLedgerRow[];
  const linkedExpenseIds = ledgerEntries.map((e) => e.expense_id).filter((id): id is string => Boolean(id));

  // Start independent wave-2 work immediately; only payments wait on monthly-charge ensure.
  const membersPromise =
    flatIds.length > 0
      ? supabase.from('members').select('flat_id, name').eq('is_primary', true).in('flat_id', flatIds)
      : Promise.resolve({ data: [] as { flat_id: string; name: string }[], error: null });
  const residentsPromise =
    flatIds.length > 0
      ? supabase
          .from('resident_users')
          .select('id, name, flat_number, flat_id')
          .in('flat_id', flatIds)
          .order('flat_number')
      : Promise.resolve({ data: [] as SocietyFinanceCoreData['residentUsers'], error: null });
  const expenseCategoriesPromise =
    linkedExpenseIds.length > 0
      ? supabase.from('expenses').select('id, expense_category').in('id', linkedExpenseIds)
      : Promise.resolve({ data: [] as { id: string; expense_category: string | null }[], error: null });

  const charges = await ensureCurrentMonthMaintenanceCharge(
    societyId,
    adminName,
    chargesRes.data ?? [],
    reminderDueDay,
  );
  const chargeIds = charges.map((x) => x.id);

  const [membersRes, residentsRes, paymentsRes, expenseCategoriesRes] = await Promise.all([
    membersPromise,
    residentsPromise,
    chargeIds.length > 0
      ? supabase
          .from('maintenance_payments')
          .select('*')
          .in('charge_id', chargeIds)
          .order('created_at', { ascending: false })
          .limit(2500)
      : Promise.resolve({ data: [] as unknown[], error: null }),
    expenseCategoriesPromise,
  ]);

  if (paymentsRes.error) throw new Error(paymentsRes.error.message);
  if (expenseCategoriesRes.error) throw new Error(expenseCategoriesRes.error.message);

  const primaryByFlatId: Record<string, string> = {};
  for (const row of membersRes.data ?? []) {
    if (row.flat_id && row.name?.trim()) primaryByFlatId[row.flat_id] = row.name.trim();
  }

  const expenseCategoryById: Record<string, string> = {};
  for (const row of expenseCategoriesRes.data ?? []) {
    expenseCategoryById[String(row.id)] = String(row.expense_category ?? '');
  }

  return {
    flats,
    primaryByFlatId,
    societyName,
    residentUsers: (residentsRes.data ?? []) as SocietyFinanceCoreData['residentUsers'],
    autoReminderEnabled,
    autoReminderSchedule,
    reminderDueDay,
    autoIssueEnabled,
    autoIssueWhatsapp,
    billSoundKey,
    charges,
    paymentExpenseGroups,
    payments: paymentsRes.data ?? [],
    ledgerEntries,
    expenseCategoryById,
    reserveTransfers: (reserveRes.data ?? []) as FinancePeriodReserveTransfer[],
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
  if (groupIds.length === 0) return { expenses: [], splits: [] };

  const groupNameById = new Map((groupRows ?? []).map((g) => [g.id, g.name]));

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
  let splits: FinanceFlatReportData['splits'] = [];
  if (expIds.length > 0) {
    const { data: splitRows, error: splitError } = await supabase
      .from('expense_splits')
      .select('id, expense_id, flat_number, amount, is_settled, settled_at')
      .in('expense_id', expIds);
    if (splitError) throw new Error(splitError.message);
    splits = splitRows ?? [];
  }

  const expenses = expRows.map((e) => ({
    ...e,
    group_name: groupNameById.get(e.group_id) ?? 'Unknown group',
  }));

  return { expenses, splits };
}

export async function fetchFinanceEventReference(societyId: string): Promise<FinanceEventReferenceData> {
  const [eventsRes, groupsRes] = await Promise.all([
    supabase
      .from('events')
      .select('id, title')
      .eq('society_id', societyId)
      .order('event_date', { ascending: false })
      .limit(100),
    supabase
      .from('expense_groups')
      .select('id, name, event_id')
      .eq('society_id', societyId)
      .eq('group_kind', 'event'),
  ]);
  if (eventsRes.error) throw new Error(eventsRes.error.message);
  if (groupsRes.error) throw new Error(groupsRes.error.message);

  const eventIds = (eventsRes.data ?? []).map((e) => e.id);
  const eventTitleById = new Map((eventsRes.data ?? []).map((e) => [String(e.id), String(e.title)]));
  const groupIds = (groupsRes.data ?? []).map((g) => g.id);
  const groupById = new Map((groupsRes.data ?? []).map((g) => [String(g.id), g]));

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

/** @deprecated Prefer `fetchSocietyFinanceCore` + `derivePeriodReportDataFromCore`. */
export async function fetchSocietyFinanceReportData(societyId: string): Promise<SocietyFinanceReportData> {
  const core = await fetchSocietyFinanceCore(societyId, 'Report');
  return derivePeriodReportDataFromCore(core);
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
