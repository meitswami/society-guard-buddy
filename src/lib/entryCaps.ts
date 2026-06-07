import type { ChangeEvent, Dispatch, SetStateAction } from 'react';
import { useStore } from '@/store/useStore';

const STORAGE_KEY = 'entry-caps-mode';

const CAPS_EXEMPT_TYPES = new Set([
  'password',
  'email',
  'tel',
  'number',
  'date',
  'month',
  'week',
  'time',
  'datetime-local',
  'url',
  'search',
  'hidden',
  'file',
  'color',
  'range',
]);

/** Fields that should never be uppercased even in CAPS mode. */
const CAPS_EXEMPT_FIELDS = new Set([
  'phone',
  'password',
  'email',
  'otp',
  'amount',
  'target_amount',
  'contribution_amount',
  'screenshot_url',
  'transaction_id',
  'due_day',
  'razorpay',
]);

export function readEntryCapsMode(): boolean {
  const stored = localStorage.getItem(STORAGE_KEY);
  if (stored === null) return true;
  return stored === 'on';
}

export function writeEntryCapsMode(on: boolean) {
  localStorage.setItem(STORAGE_KEY, on ? 'on' : 'off');
}

export function getEntryCapsMode(): boolean {
  return useStore.getState().entryCapsMode;
}

export function shouldApplyEntryCaps(opts?: {
  type?: string;
  field?: string;
  caps?: boolean;
  datasetCaps?: string;
}): boolean {
  if (!getEntryCapsMode()) return false;
  if (opts?.caps === false) return false;
  if (opts?.datasetCaps === 'off') return false;
  if (opts?.type && CAPS_EXEMPT_TYPES.has(opts.type)) return false;
  if (opts?.field && CAPS_EXEMPT_FIELDS.has(opts.field)) return false;
  return true;
}

export function normalizeEntryValue(
  value: string,
  opts?: { type?: string; field?: string; caps?: boolean; datasetCaps?: string },
): string {
  return shouldApplyEntryCaps(opts) ? value.toUpperCase() : value;
}

/** Wrap a string setter for input/textarea onChange. */
export function capsChange(
  setter: (value: string) => void,
  opts?: { type?: string; field?: string; caps?: boolean },
) {
  return (e: ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    setter(normalizeEntryValue(e.target.value, { type: e.target.type, field: opts?.field, caps: opts?.caps }));
  };
}

/** Wrap a form object setter for a single text field. */
export function capsFieldChange<T extends Record<string, unknown>>(
  setter: Dispatch<SetStateAction<T>>,
  field: keyof T,
  opts?: { caps?: boolean },
) {
  return (e: ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    const v = normalizeEntryValue(e.target.value, {
      type: e.target.type,
      field: String(field),
      caps: opts?.caps,
    });
    setter((prev) => ({ ...prev, [field]: v }));
  };
}
