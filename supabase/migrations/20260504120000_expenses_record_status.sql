ALTER TABLE public.expenses
  ADD COLUMN IF NOT EXISTS record_status text NOT NULL DEFAULT 'active';

ALTER TABLE public.expenses
  DROP CONSTRAINT IF EXISTS expenses_record_status_check;

ALTER TABLE public.expenses
  ADD CONSTRAINT expenses_record_status_check
  CHECK (record_status IN ('active', 'archived'));
