-- Reserve fund movements: monthly operating surplus → reserve; reserve → operating / fixed / emergency.

CREATE TABLE IF NOT EXISTS public.reserve_fund_transfers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id uuid NOT NULL REFERENCES public.societies(id) ON DELETE CASCADE,
  entry_month text NOT NULL,
  amount numeric NOT NULL CHECK (amount > 0),
  direction text NOT NULL CHECK (
    direction IN (
      'operating_to_reserve',
      'reserve_to_operating',
      'reserve_to_fixed',
      'reserve_to_emergency'
    )
  ),
  payment_method text NOT NULL DEFAULT 'bank_transfer',
  notes text,
  created_by text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_reserve_fund_transfers_society_month
  ON public.reserve_fund_transfers (society_id, entry_month);

ALTER TABLE public.reserve_fund_transfers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "All access reserve_fund_transfers" ON public.reserve_fund_transfers;
CREATE POLICY "All access reserve_fund_transfers" ON public.reserve_fund_transfers
  FOR ALL USING (true) WITH CHECK (true);

NOTIFY pgrst, 'reload schema';
