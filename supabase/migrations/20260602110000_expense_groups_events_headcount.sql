-- Event / function expense groups: optional link to events; headcount weights for adult vs child splits.

ALTER TABLE public.expense_groups
  ADD COLUMN IF NOT EXISTS event_id uuid REFERENCES public.events(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS group_kind text NOT NULL DEFAULT 'event'
    CHECK (group_kind IN ('event', 'general')),
  ADD COLUMN IF NOT EXISTS adult_weight numeric NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS child_weight numeric NOT NULL DEFAULT 0.5;

CREATE INDEX IF NOT EXISTS idx_expense_groups_event_id ON public.expense_groups (event_id)
  WHERE event_id IS NOT NULL;
