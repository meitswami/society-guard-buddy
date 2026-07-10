import { format } from 'date-fns';
import { billingMonthFromDate, paymentBillingDate } from '@/lib/financeDates';
import { fmtIsoMonthToDisplay } from '@/lib/dateFormat';

export const normalizeChargeTitle = (value: unknown) => String(value ?? '').trim().toLowerCase();

export const isMonthlyMaintenanceCharge = (charge: { title?: unknown; frequency?: unknown }) => {
  const title = normalizeChargeTitle(charge?.title);
  const frequency = normalizeChargeTitle(charge?.frequency);
  return frequency === 'monthly' && title.includes('maint');
};

export const isCurrentMonthChargeTitle = (title: string, date = new Date()) => {
  const lower = normalizeChargeTitle(title);
  const monthName = format(date, 'MMMM').toLowerCase();
  return lower.includes(monthName) || lower.includes(format(date, 'MM/yyyy')) || lower.includes(format(date, 'MM-yyyy'));
};

export const buildCurrentMonthChargeTitle = (date = new Date()) => `${format(date, 'MMMM')} Monthly Maintenance`;

export const paymentMonthValue = (payment: { due_date?: string | null; created_at?: string | null }) => {
  const raw = paymentBillingDate(payment);
  if (!raw) return '';
  return billingMonthFromDate(raw);
};

export const paymentMonthLabel = (payment: { due_date?: string | null; created_at?: string | null }) => {
  const raw = paymentBillingDate(payment);
  if (!raw) return 'Unknown month';
  return fmtIsoMonthToDisplay(billingMonthFromDate(raw));
};

export const paymentVerifiedAtOrDate = (p: {
  payment_date?: string | null;
  verified_at?: string | null;
  created_at?: string | null;
}) => String(p?.payment_date || p?.verified_at || p?.created_at || '');
