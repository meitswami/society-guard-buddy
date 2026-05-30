import { format, isValid, parse } from 'date-fns';

/** Calendar date shown across the app (India-style). */
export const DATE_FMT = 'dd-MM-yyyy';
/** Date + 24h clock (logs, exports). */
export const DATE_TIME_FMT = 'dd-MM-yyyy HH:mm';
/** Date + time with seconds (audit-style). */
export const DATE_TIME_FULL_FMT = 'dd-MM-yyyy HH:mm:ss';
export const TIME_FMT = 'hh:mm a';
/** Month banner / charge titles (word month + year). */
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

export function fmtDateTimeFull(value: Date | string | number | null | undefined): string {
  if (!value) return '';
  const d = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(d.getTime())) return '';
  return format(d, DATE_TIME_FULL_FMT);
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

/** `yyyy-MM-dd` from `<input type="date">` or DB → `dd/MM/yyyy` for labels, PDF, messages. */
export function fmtIsoDateToDisplay(iso: string | null | undefined): string {
  if (!iso) return '';
  const s = iso.slice(0, 10);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(s)) return iso;
  const d = parse(s, 'yyyy-MM-dd', new Date());
  return isValid(d) ? format(d, DATE_FMT) : iso;
}

/** `yyyy-MM` (month picker / entry_month) → `MM-yyyy` for display. */
export function fmtIsoMonthToDisplay(ym: string | null | undefined): string {
  if (!ym) return '';
  const s = ym.slice(0, 7);
  if (!/^\d{4}-\d{2}$/.test(s)) return ym;
  const d = parse(`${s}-01`, 'yyyy-MM-dd', new Date());
  return isValid(d) ? format(d, 'MM-yyyy') : ym;
}
