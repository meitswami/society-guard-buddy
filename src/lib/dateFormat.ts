import { format } from 'date-fns';

// Chosen global style: dd-MM-yyyy (easy to scan, consistent, locale-agnostic)
export const DATE_FMT = 'dd-MM-yyyy';
export const DATE_TIME_FMT = 'dd-MM-yyyy hh:mm a';
export const TIME_FMT = 'hh:mm a';
export const MONTH_FMT = 'MMMM yyyy';

export function fmtDate(value: Date | string | number | null | undefined): string {
  if (!value) return '';
  const d = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(d.getTime())) return '';
  return format(d, DATE_FMT);
}

export function fmtDateTime(value: Date | string | number | null | undefined): string {
  if (!value) return '';
  const d = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(d.getTime())) return '';
  return format(d, DATE_TIME_FMT);
}

export function fmtTime(value: Date | string | number | null | undefined): string {
  if (!value) return '';
  const d = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(d.getTime())) return '';
  return format(d, TIME_FMT);
}

export function fmtMonth(value: Date | string | number | null | undefined): string {
  if (!value) return '';
  const d = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(d.getTime())) return '';
  return format(d, MONTH_FMT);
}

