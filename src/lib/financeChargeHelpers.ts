import { format, isValid, parse } from 'date-fns';
import { billingMonthFromDate, paymentBillingDate } from '@/lib/financeDates';

export const normalizeTitle = (value: unknown) => String(value ?? '').trim().toLowerCase();

const MONTH_NAMES = [
  'january',
  'february',
  'march',
  'april',
  'may',
  'june',
  'july',
  'august',
  'september',
  'october',
  'november',
  'december',
] as const;

export const isMonthlyMaintenanceCharge = (charge: { title?: unknown; frequency?: unknown }) => {
  const title = normalizeTitle(charge?.title);
  const frequency = normalizeTitle(charge?.frequency);
  return frequency === 'monthly' && title.includes('maint');
};

export const isCurrentMonthChargeTitle = (title: string, date = new Date()) => {
  const lower = normalizeTitle(title);
  const monthName = format(date, 'MMMM').toLowerCase();
  return lower.includes(monthName) || lower.includes(format(date, 'MM/yyyy')) || lower.includes(format(date, 'MM-yyyy'));
};

export const buildCurrentMonthChargeTitle = (date = new Date()) => `${format(date, 'MMMM')} Monthly Maintenance`;

/** Month name embedded in a charge title (e.g. "June Monthly Maintenance" → "june"), else null. */
export const monthNameFromChargeTitle = (title: string): (typeof MONTH_NAMES)[number] | null => {
  const lower = normalizeTitle(title);
  for (const month of MONTH_NAMES) {
    if (lower.includes(month)) return month;
  }
  return null;
};

/**
 * When a receipt type names a calendar month, billing date must fall in that month.
 * Returns true when the title has no month name (no constraint).
 */
export const chargeTitleMatchesBillingMonth = (title: string, dueDateYmd: string): boolean => {
  const named = monthNameFromChargeTitle(title);
  if (!named) return true;
  const d = parse(dueDateYmd.slice(0, 10), 'yyyy-MM-dd', new Date());
  if (!isValid(d)) return false;
  return format(d, 'MMMM').toLowerCase() === named;
};

export const paymentMonthValue = (payment: { due_date?: string | null }) => {
  const raw = paymentBillingDate(payment);
  if (!raw) return '';
  return billingMonthFromDate(raw);
};

export const chargeForUnpaidFilters = (
  charges: { id?: string; title?: string; amount?: number; frequency?: string }[],
  paymentTypeFilter: string,
  paymentMonthFilter: string,
): { title: string; amount: number } | null => {
  if (
    paymentTypeFilter === 'all_payments' ||
    paymentTypeFilter === 'society_pool_pending' ||
    paymentTypeFilter === 'corpus' ||
    paymentTypeFilter === 'outsider_mixed'
  ) {
    return null;
  }

  const pool = charges.filter((c) => {
    if (paymentTypeFilter === 'monthly_maintenance') return isMonthlyMaintenanceCharge(c);
    if (paymentTypeFilter === 'all' || paymentTypeFilter === 'all_receipts') return true;
    if (paymentTypeFilter === 'other') return false;
    return String(c.frequency).toLowerCase() === paymentTypeFilter;
  });
  if (pool.length === 0) return null;

  if (paymentMonthFilter !== 'all') {
    const monthName = format(new Date(`${paymentMonthFilter}-15T12:00:00`), 'MMMM').toLowerCase();
    const match =
      pool.find((c) => normalizeTitle(c.title).includes(monthName)) ??
      pool.find((c) => normalizeTitle(c.title).includes(paymentMonthFilter));
    if (match) return { title: match.title ?? '', amount: Number(match.amount) || 0 };
  }

  const current =
    pool.find((c) => isMonthlyMaintenanceCharge(c) && isCurrentMonthChargeTitle(c.title ?? '')) ?? pool[0];
  return current ? { title: current.title ?? '', amount: Number(current.amount) || 0 } : null;
};

export const transactionFilterHint = (filter: string): string => {
  switch (filter) {
    case 'all_payments':
      return 'Society payments recorded via Record payment — vendor bills, utilities, repairs split across flats (not event food or maintenance receipts).';
    case 'all_receipts':
      return 'Society collections — flat owners, outsiders, monthly/one-time charges; pooled until you distribute to flats.';
    case 'all':
      return 'Society receipts and society-payment rows. Event contribution and food bills appear below as reference only (not in the society ledger).';
    case 'society_pool_pending':
      return 'Receipts recorded in the society pool that are not yet split equally across flats.';
    default:
      return 'Filter by charge type or recording mode. Use society pool when recording, then distribute from the receipt row when needed.';
  }
};
