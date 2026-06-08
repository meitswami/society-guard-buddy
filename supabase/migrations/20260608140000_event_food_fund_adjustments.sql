-- Event & food reconciliation: cover shortfall or transfer surplus to society pool.

CREATE TABLE IF NOT EXISTS public.event_food_fund_adjustments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id uuid NOT NULL REFERENCES public.societies(id) ON DELETE CASCADE,
  event_id uuid REFERENCES public.events(id) ON DELETE SET NULL,
  adjustment_kind text NOT NULL CHECK (adjustment_kind IN ('shortfall_cover', 'surplus_to_pool')),
  amount numeric NOT NULL CHECK (amount > 0),
  source_type text NOT NULL CHECK (
    source_type IN ('member_advance', 'maintenance_pool', 'corpus', 'society_pool')
  ),
  flat_number text,
  flat_id uuid REFERENCES public.flats(id) ON DELETE SET NULL,
  payment_method text NOT NULL DEFAULT 'cash',
  notes text,
  created_by text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_event_food_fund_adjustments_event
  ON public.event_food_fund_adjustments (event_id, created_at DESC)
  WHERE event_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_event_food_fund_adjustments_society
  ON public.event_food_fund_adjustments (society_id, created_at DESC);

COMMENT ON TABLE public.event_food_fund_adjustments IS
  'Event food reconciliation: shortfall_cover draws from pool/corpus/member; surplus_to_pool sends excess to society pool.';
COMMENT ON COLUMN public.event_food_fund_adjustments.adjustment_kind IS
  'shortfall_cover = funds added to cover food over contributions; surplus_to_pool = excess transferred to society pool';
COMMENT ON COLUMN public.event_food_fund_adjustments.source_type IS
  'Where shortfall funds come from, or society_pool as destination for surplus';

ALTER TABLE public.event_food_fund_adjustments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "All access event_food_fund_adjustments" ON public.event_food_fund_adjustments;
CREATE POLICY "All access event_food_fund_adjustments" ON public.event_food_fund_adjustments
  FOR ALL USING (true) WITH CHECK (true);

NOTIFY pgrst, 'reload schema';
