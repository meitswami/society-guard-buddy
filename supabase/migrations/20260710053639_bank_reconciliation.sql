-- Bank statement import and reconciliation (V3.1)

CREATE TABLE public.bank_statement_imports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id uuid NOT NULL REFERENCES public.societies(id) ON DELETE CASCADE,
  bank_name text,
  account_last4 text,
  period_from date NOT NULL,
  period_to date NOT NULL,
  file_name text,
  imported_by text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_bank_statement_imports_society
  ON public.bank_statement_imports (society_id, created_at DESC);

CREATE TABLE public.bank_statement_lines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  import_id uuid NOT NULL REFERENCES public.bank_statement_imports(id) ON DELETE CASCADE,
  society_id uuid NOT NULL REFERENCES public.societies(id) ON DELETE CASCADE,
  line_date date NOT NULL,
  amount numeric NOT NULL,
  description text,
  reference text,
  balance_after numeric,
  raw_row jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_bank_statement_lines_import
  ON public.bank_statement_lines (import_id, line_date);

CREATE INDEX idx_bank_statement_lines_society_date
  ON public.bank_statement_lines (society_id, line_date);

CREATE TABLE public.bank_reconciliation_matches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  statement_line_id uuid NOT NULL REFERENCES public.bank_statement_lines(id) ON DELETE CASCADE,
  society_id uuid NOT NULL REFERENCES public.societies(id) ON DELETE CASCADE,
  match_type text NOT NULL CHECK (match_type IN (
    'maintenance_payment', 'finance_entry', 'split_combined'
  )),
  maintenance_payment_id uuid REFERENCES public.maintenance_payments(id) ON DELETE SET NULL,
  finance_entry_id uuid REFERENCES public.finance_entries(id) ON DELETE SET NULL,
  match_confidence numeric NOT NULL DEFAULT 0 CHECK (match_confidence >= 0 AND match_confidence <= 1),
  status text NOT NULL DEFAULT 'suggested' CHECK (status IN (
    'suggested', 'confirmed', 'rejected', 'manual'
  )),
  matched_by text,
  matched_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT bank_recon_one_target CHECK (
    (maintenance_payment_id IS NOT NULL)::int + (finance_entry_id IS NOT NULL)::int >= 1
  )
);

CREATE UNIQUE INDEX bank_recon_payment_unique
  ON public.bank_reconciliation_matches (maintenance_payment_id)
  WHERE maintenance_payment_id IS NOT NULL AND status = 'confirmed';

CREATE UNIQUE INDEX bank_recon_entry_unique
  ON public.bank_reconciliation_matches (finance_entry_id)
  WHERE finance_entry_id IS NOT NULL AND status = 'confirmed';

CREATE INDEX idx_bank_recon_line
  ON public.bank_reconciliation_matches (statement_line_id);

CREATE INDEX idx_bank_recon_society_status
  ON public.bank_reconciliation_matches (society_id, status);

ALTER TABLE public.bank_statement_imports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bank_statement_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bank_reconciliation_matches ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "All access bank_statement_imports" ON public.bank_statement_imports;
CREATE POLICY "All access bank_statement_imports" ON public.bank_statement_imports
  FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "All access bank_statement_lines" ON public.bank_statement_lines;
CREATE POLICY "All access bank_statement_lines" ON public.bank_statement_lines
  FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "All access bank_reconciliation_matches" ON public.bank_reconciliation_matches;
CREATE POLICY "All access bank_reconciliation_matches" ON public.bank_reconciliation_matches
  FOR ALL USING (true) WITH CHECK (true);

NOTIFY pgrst, 'reload schema';
