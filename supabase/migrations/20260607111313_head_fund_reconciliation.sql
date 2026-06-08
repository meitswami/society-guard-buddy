-- Link contribution receipt types to expense heads; track shortfall adjustments.

ALTER TABLE public.maintenance_charges
  ADD COLUMN IF NOT EXISTS expense_group_id uuid REFERENCES public.expense_groups(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_maintenance_charges_expense_group
  ON public.maintenance_charges (expense_group_id)
  WHERE expense_group_id IS NOT NULL;

COMMENT ON COLUMN public.maintenance_charges.expense_group_id IS
  'When set, flat receipts under this charge count as contributions toward the linked expense head.';

CREATE TABLE IF NOT EXISTS public.head_fund_adjustments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id uuid NOT NULL REFERENCES public.societies(id) ON DELETE CASCADE,
  expense_group_id uuid NOT NULL REFERENCES public.expense_groups(id) ON DELETE CASCADE,
  amount numeric NOT NULL CHECK (amount > 0),
  source_type text NOT NULL CHECK (source_type IN ('member_advance', 'maintenance_pool', 'corpus')),
  flat_number text,
  flat_id uuid REFERENCES public.flats(id) ON DELETE SET NULL,
  notes text,
  finance_entry_id uuid REFERENCES public.finance_entries(id) ON DELETE SET NULL,
  created_by text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_head_fund_adjustments_group
  ON public.head_fund_adjustments (expense_group_id, created_at DESC);

ALTER TABLE public.head_fund_adjustments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "All access head_fund_adjustments" ON public.head_fund_adjustments;
CREATE POLICY "All access head_fund_adjustments" ON public.head_fund_adjustments
  FOR ALL USING (true) WITH CHECK (true);

-- Auto-link receipt types to payment heads by name (e.g. Water Softner Installation → Water Softner)
UPDATE public.maintenance_charges mc
SET expense_group_id = g.id
FROM public.expense_groups g
WHERE mc.expense_group_id IS NULL
  AND mc.society_id = g.society_id
  AND COALESCE(g.group_kind, 'general') = 'general'
  AND (
    lower(trim(mc.title)) LIKE '%' || lower(trim(g.name)) || '%'
    OR lower(trim(g.name)) LIKE '%' || lower(regexp_replace(trim(mc.title), '\s+installation\s*$', '', 'i')) || '%'
    OR lower(regexp_replace(trim(mc.title), '\s+installation\s*$', '', 'i')) LIKE '%' || lower(trim(g.name)) || '%'
  );

-- Consolidate water softener expenses under the Water Softner head (from Fixed Assets etc.)
UPDATE public.expenses ex
SET group_id = ws.id
FROM public.expense_groups ws
WHERE ex.group_id <> ws.id
  AND ws.name ILIKE '%water soft%'
  AND COALESCE(ws.group_kind, 'general') = 'general'
  AND ex.record_status = 'active'
  AND ex.expense_category = 'payment'
  AND ex.group_id IN (
    SELECT g2.id FROM public.expense_groups g2 WHERE g2.society_id = ws.society_id
  )
  AND (
    ex.title ILIKE '%water soft%'
    OR ex.title ILIKE '%softner%'
    OR ex.title ILIKE '%softener%'
    OR COALESCE(ex.vendor_or_service, '') ILIKE '%soft%'
  );

-- Ledger titles for moved expenses
UPDATE public.finance_entries fe
SET title = trim(ws.name)
FROM public.expenses ex
JOIN public.expense_groups ws ON ws.id = ex.group_id
WHERE fe.expense_id = ex.id
  AND ws.name ILIKE '%water soft%'
  AND fe.title IS DISTINCT FROM trim(ws.name)
  AND fe.destination = 'separate_entry';

NOTIFY pgrst, 'reload schema';
