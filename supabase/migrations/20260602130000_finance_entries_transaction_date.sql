-- Billing (transaction) date for ledger rows; used in period reports. entry_month must contain this date.

ALTER TABLE public.finance_entries
  ADD COLUMN IF NOT EXISTS transaction_date date;

UPDATE public.finance_entries
SET transaction_date = (entry_month || '-01')::date
WHERE transaction_date IS NULL
  AND entry_month IS NOT NULL
  AND entry_month ~ '^\d{4}-\d{2}$';

COMMENT ON COLUMN public.finance_entries.transaction_date IS
  'Bill/transaction date for reporting. Must fall within entry_month. recording uses created_at / payment recording_date separately.';
