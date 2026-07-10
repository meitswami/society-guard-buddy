import type { ChannelTotals } from '@/lib/cashBankChannel';
import type { ReportDetailRow } from '@/components/ReportDetailModal';

export type FinanceSubTab =
  | 'maintenance'
  | 'payments'
  | 'record_payment'
  | 'receipts'
  | 'period'
  | 'totals'
  | 'reminders'
  | 'flat_report';

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

export type TransactionHeadSummaryRow = {
  head: string;
  total: number;
  entries: number;
  byChannel: ChannelTotals;
};

export type TransactionHeadModalLayer = {
  title: string;
  subtitle?: string;
  total?: number;
  rows: ReportDetailRow[];
  drillable: boolean;
};

export type UnpaidFlatGridRow = {
  flat_number: string;
  primary_name: string;
  is_occupied: boolean | null;
  pending_payment: 'pending' | 'rejected' | null;
  due_amount: number | null;
  charge_title: string | null;
};

export type SocietyFlatRow = {
  id: string;
  flat_number: string;
  owner_name: string | null;
  is_occupied: boolean | null;
};
