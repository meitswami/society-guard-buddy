import { parse, isValid } from 'date-fns';
import { DATE_FMT, fmtIsoMonthToDisplay } from '@/lib/dateFormat';

export type AmountRow = {
  amount?: number;
  /** Preferred for grouping — `yyyy-MM-dd` or ISO timestamp. */
  dateIso?: string;
  /** Display date (`dd/MM/yyyy`) when ISO is unavailable. */
  date?: string;
};

export type MonthlyAmountTotal = {
  monthKey: string;
  label: string;
  total: number;
  count: number;
};

export function sumAmountRows(rows: { amount?: number }[]): number {
  return rows.reduce((s, r) => s + (r.amount ?? 0), 0);
}

function monthKeyFromRow(row: AmountRow): string | null {
  if (row.dateIso) {
    const s = row.dateIso.slice(0, 10);
    if (/^\d{4}-\d{2}-\d{2}$/.test(s)) return s.slice(0, 7);
  }
  if (row.date) {
    const trimmed = row.date.trim();
    if (/^\d{4}-\d{2}-\d{2}/.test(trimmed)) return trimmed.slice(0, 7);
    const d = parse(trimmed.slice(0, 10), DATE_FMT, new Date());
    if (isValid(d)) return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
  }
  return null;
}

/** Group signed transaction amounts by calendar month (`yyyy-MM`). */
export function monthlyAmountTotals(rows: AmountRow[]): MonthlyAmountTotal[] {
  const map = new Map<string, { total: number; count: number }>();
  for (const row of rows) {
    if (row.amount === undefined) continue;
    const monthKey = monthKeyFromRow(row);
    if (!monthKey) continue;
    const cur = map.get(monthKey) ?? { total: 0, count: 0 };
    cur.total += row.amount;
    cur.count += 1;
    map.set(monthKey, cur);
  }
  return [...map.entries()]
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([monthKey, v]) => ({
      monthKey,
      label: fmtIsoMonthToDisplay(monthKey),
      total: v.total,
      count: v.count,
    }));
}
