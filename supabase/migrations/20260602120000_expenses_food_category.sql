-- Event module: only food bills are split per flat; other society payments belong in Finance.

ALTER TABLE public.expenses
  ADD COLUMN IF NOT EXISTS expense_category text NOT NULL DEFAULT 'food'
    CHECK (expense_category IN ('food', 'payment'));

COMMENT ON COLUMN public.expenses.expense_category IS
  'food = event catering split among flats; payment = legacy/non-food (use Finance record payment instead).';

-- Legacy general-group rows are payment-nature, not event food splits.
UPDATE public.expenses e
SET expense_category = 'payment'
FROM public.expense_groups g
WHERE e.group_id = g.id
  AND COALESCE(g.group_kind, 'event') = 'general';
