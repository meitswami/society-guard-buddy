-- Normalized finance ledger for flat/outsider records, allocations, and reporting.

CREATE TABLE public.finance_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id uuid NOT NULL REFERENCES public.societies(id) ON DELETE CASCADE,
  record_mode text NOT NULL DEFAULT 'flats_only'
    CHECK (record_mode IN ('flats_only', 'flats_plus_outsider', 'outsider_only')),
  destination text NOT NULL DEFAULT 'current_month_maintenance'
    CHECK (destination IN (
      'none',
      'current_month_maintenance',
      'corpus',
      'separate_entry'
    )),
  allocation_style text NOT NULL DEFAULT 'none'
    CHECK (allocation_style IN ('same_per_flat', 'split_total_equally', 'none')),
  include_vacant boolean NOT NULL DEFAULT false,
  entry_month text,
  total_amount numeric NOT NULL DEFAULT 0,
  aggregate_flat_count integer NOT NULL DEFAULT 0,
  charge_id uuid REFERENCES public.maintenance_charges(id) ON DELETE SET NULL,
  title text,
  notes text,
  screenshot_url text,
  transaction_id text,
  payment_method text NOT NULL DEFAULT 'cash',
  payment_status text NOT NULL DEFAULT 'verified',
  created_by text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_finance_entries_society_month ON public.finance_entries (society_id, entry_month);
CREATE INDEX idx_finance_entries_society_mode ON public.finance_entries (society_id, record_mode);
CREATE INDEX idx_finance_entries_created ON public.finance_entries (society_id, created_at DESC);

CREATE TABLE public.finance_entry_counterparties (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  finance_entry_id uuid NOT NULL REFERENCES public.finance_entries(id) ON DELETE CASCADE,
  name text NOT NULL,
  relation_to_society text,
  UNIQUE (finance_entry_id)
);

CREATE TABLE public.finance_entry_allocations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  finance_entry_id uuid NOT NULL REFERENCES public.finance_entries(id) ON DELETE CASCADE,
  flat_id uuid REFERENCES public.flats(id) ON DELETE SET NULL,
  flat_number text NOT NULL,
  amount numeric NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_finance_entry_allocations_entry ON public.finance_entry_allocations (finance_entry_id);
CREATE INDEX idx_finance_entry_allocations_flat ON public.finance_entry_allocations (flat_number);

ALTER TABLE public.maintenance_payments
  ADD COLUMN IF NOT EXISTS finance_entry_id uuid REFERENCES public.finance_entries(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_maintenance_payments_finance_entry ON public.maintenance_payments (finance_entry_id);

ALTER TABLE public.finance_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.finance_entry_counterparties ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.finance_entry_allocations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "All access finance_entries" ON public.finance_entries FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "All access finance_entry_counterparties" ON public.finance_entry_counterparties FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "All access finance_entry_allocations" ON public.finance_entry_allocations FOR ALL USING (true) WITH CHECK (true);
