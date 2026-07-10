export type FinanceLedgerRow = {
  id: string;
  society_id: string;
  record_mode: string;
  destination: string;
  allocation_style: string;
  include_vacant: boolean;
  entry_month: string | null;
  transaction_date: string | null;
  total_amount: number;
  aggregate_flat_count: number;
  charge_id: string | null;
  expense_id: string | null;
  distributed_at: string | null;
  title: string | null;
  notes: string | null;
  screenshot_url: string | null;
  transaction_id: string | null;
  payment_method: string;
  payment_status: string;
  created_by: string | null;
  created_at: string;
  finance_entry_counterparties: { name: string; relation_to_society: string | null }[] | null;
  finance_entry_allocations: { flat_number: string; amount: number; flat_id: string | null }[] | null;
};

export type SocietyFlatRow = {
  id: string;
  flat_number: string;
  owner_name: string | null;
  is_occupied: boolean | null;
};

export type ResidentUserRow = {
  id: string;
  name: string;
  flat_number: string;
  flat_id: string;
};

export type MaintenanceChargeRow = Record<string, unknown> & {
  id: string;
  title: string;
  amount: number;
  frequency?: string;
  due_day?: number;
  society_id?: string;
  expense_group_id?: string | null;
};

export type MaintenancePaymentRow = Record<string, unknown>;

export type PaymentExpenseGroupRow = {
  id: string;
  name: string;
  major_head: string | null;
};

export type FinanceReminderSchedule = 'once_12pm' | 'twice_12pm_7pm';

export type SocietyFinanceCoreData = {
  flats: SocietyFlatRow[];
  primaryByFlatId: Record<string, string>;
  societyName: string;
  residentUsers: ResidentUserRow[];
  autoReminderEnabled: boolean;
  autoReminderSchedule: FinanceReminderSchedule;
  charges: MaintenanceChargeRow[];
  paymentExpenseGroups: PaymentExpenseGroupRow[];
  payments: MaintenancePaymentRow[];
  ledgerEntries: FinanceLedgerRow[];
  expenseCategoryById: Record<string, string>;
};

export type EventContribRefRow = {
  id: string;
  event_id: string;
  flat_number: string | null;
  amount: number;
  payment_method: string;
  verified_at: string | null;
  resident_name: string | null;
  receipt_basis: string | null;
  batch_label: string | null;
  outsider_name: string | null;
  split_mode: string | null;
  screenshot_url: string | null;
  event_title?: string;
};

export type EventFoodRefRow = {
  id: string;
  title: string;
  total_amount: number;
  expense_date: string;
  payment_method: string;
  bill_screenshot_url: string | null;
  group_name: string;
  event_title: string | null;
};

export type FinanceFlatReportData = {
  expenses: Array<Record<string, unknown> & { group_name: string }>;
  splits: Array<Record<string, unknown>>;
};

export type FinanceEventReferenceData = {
  contributions: EventContribRefRow[];
  foodExpenses: EventFoodRefRow[];
};
