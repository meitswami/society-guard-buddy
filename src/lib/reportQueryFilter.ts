import type { ReportDetailRow } from '@/components/ReportDetailModal';
import type { FinancePeriodLedgerEntry } from '@/lib/financePeriodReport';
import type { Visitor } from '@/types';

export function normalizeReportQuery(query: string): string {
  return query.trim().toLowerCase();
}

export function matchesHaystack(haystack: string, query: string): boolean {
  const q = normalizeReportQuery(query);
  if (!q) return true;
  return haystack.toLowerCase().includes(q);
}

export function filterVisitorRows(visitors: Visitor[], query: string): Visitor[] {
  const q = normalizeReportQuery(query);
  if (!q) return visitors;
  return visitors.filter((v) => {
    const haystack = [
      v.name,
      v.phone,
      v.flatNumber,
      v.purpose,
      v.guardName,
      v.category,
      v.company ?? '',
      v.vehicleNumber ?? '',
      v.documentNumber,
    ]
      .join(' ')
      .toLowerCase();
    return haystack.includes(q);
  });
}

export function filterLedgerEntries(entries: FinancePeriodLedgerEntry[], query: string): FinancePeriodLedgerEntry[] {
  const q = normalizeReportQuery(query);
  if (!q) return entries;
  return entries.filter((e) => {
    const haystack = [
      e.id,
      e.record_mode ?? '',
      e.destination,
      e.payment_method ?? '',
      e.payment_status ?? '',
      e.title ?? '',
      e.notes ?? '',
      e.transaction_id ?? '',
      e.transaction_date ?? '',
      e.entry_month ?? '',
      String(e.total_amount ?? ''),
      String(e.aggregate_flat_count ?? ''),
    ]
      .join(' ')
      .toLowerCase();
    return haystack.includes(q);
  });
}

export function filterReportDetailRows(rows: ReportDetailRow[], query: string): ReportDetailRow[] {
  const q = normalizeReportQuery(query);
  if (!q) return rows;
  return rows.filter((row) => {
    const haystack = [
      row.label,
      row.sublabel ?? '',
      row.date ?? '',
      row.status ?? '',
      row.extra ?? '',
      row.amount !== undefined ? String(row.amount) : '',
    ]
      .join(' ')
      .toLowerCase();
    return haystack.includes(q);
  });
}

export interface ReportShiftRow {
  id: string;
  guard_id: string;
  guard_name: string;
  login_time: string;
  logout_time: string | null;
}

export function filterShiftRows(shifts: ReportShiftRow[], query: string): ReportShiftRow[] {
  const q = normalizeReportQuery(query);
  if (!q) return shifts;
  return shifts.filter((s) => {
    const haystack = [s.guard_name, s.guard_id, s.login_time, s.logout_time ?? ''].join(' ').toLowerCase();
    return haystack.includes(q);
  });
}
