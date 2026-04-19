-- Society / committee expense metadata and multi-payer tracking
ALTER TABLE public.expenses
  ADD COLUMN IF NOT EXISTS payment_method text NOT NULL DEFAULT 'cash',
  ADD COLUMN IF NOT EXISTS bill_screenshot_url text,
  ADD COLUMN IF NOT EXISTS service_kind text NOT NULL DEFAULT 'one_time',
  ADD COLUMN IF NOT EXISTS vendor_or_service text,
  ADD COLUMN IF NOT EXISTS expense_date date NOT NULL DEFAULT (timezone('utc', now()))::date,
  ADD COLUMN IF NOT EXISTS notes text,
  ADD COLUMN IF NOT EXISTS paid_by_flats jsonb NOT NULL DEFAULT '[]'::jsonb;

COMMENT ON COLUMN public.expenses.paid_by_flats IS 'JSON array of flat numbers that advanced payment; empty uses paid_by_flat only.';
COMMENT ON COLUMN public.expenses.split_type IS 'equal_all | equal_selected | custom | society_fund';
