-- Link ledger rows created from Splitwise / expense groups back to expenses (CASCADE on expense delete).

ALTER TABLE public.finance_entries
  ADD COLUMN IF NOT EXISTS expense_id uuid REFERENCES public.expenses(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_finance_entries_expense_id ON public.finance_entries (expense_id)
  WHERE expense_id IS NOT NULL;
