CREATE TABLE IF NOT EXISTS public.finance_opening_balance_anchors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id uuid NOT NULL REFERENCES public.societies(id) ON DELETE CASCADE,
  as_on_date date NOT NULL,
  cash_amount numeric,
  bank_amount numeric,
  other_amount numeric,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (society_id, as_on_date)
);

CREATE INDEX IF NOT EXISTS finance_opening_balance_anchors_society_date_idx
  ON public.finance_opening_balance_anchors (society_id, as_on_date DESC);

ALTER TABLE public.finance_opening_balance_anchors ENABLE ROW LEVEL SECURITY;

CREATE POLICY "All access finance_opening_balance_anchors"
ON public.finance_opening_balance_anchors
FOR ALL
USING (true)
WITH CHECK (true);
