-- Society pool receipts: record inflow first, distribute equally to flats later.

ALTER TABLE public.finance_entries
  ADD COLUMN IF NOT EXISTS distributed_at timestamptz;

ALTER TABLE public.finance_entries DROP CONSTRAINT IF EXISTS finance_entries_record_mode_check;

ALTER TABLE public.finance_entries
  ADD CONSTRAINT finance_entries_record_mode_check
  CHECK (record_mode IN ('flats_only', 'flats_plus_outsider', 'outsider_only', 'society_pool'));
