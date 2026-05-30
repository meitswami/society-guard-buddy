-- Add recording_date to expenses and maintenance_payments
-- recording_date = date the record was entered into the system (defaults to today)
-- expense_date / due_date = the actual transaction/bill date

ALTER TABLE public.expenses
  ADD COLUMN IF NOT EXISTS recording_date date NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE public.maintenance_payments
  ADD COLUMN IF NOT EXISTS recording_date date NOT NULL DEFAULT CURRENT_DATE;

COMMENT ON COLUMN public.expenses.recording_date IS 'Date the expense was recorded in the system (defaults to today).';
COMMENT ON COLUMN public.expenses.expense_date IS 'Actual bill/transaction date.';
COMMENT ON COLUMN public.maintenance_payments.recording_date IS 'Date the payment was recorded in the system (defaults to today).';
COMMENT ON COLUMN public.maintenance_payments.due_date IS 'Due/transaction date for the payment.';
