-- Fixed assets register: builder handover, manual entry, and auto-sync from Finance → FIXED ASSETS payments.

CREATE TABLE public.fixed_assets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id uuid NOT NULL REFERENCES public.societies(id) ON DELETE CASCADE,
  asset_name text NOT NULL,
  description text,
  major_head text NOT NULL DEFAULT 'FIXED ASSETS',
  sub_head text,
  expense_group_id uuid REFERENCES public.expense_groups(id) ON DELETE SET NULL,
  source_type text NOT NULL DEFAULT 'manual'
    CHECK (source_type IN ('builder_handover', 'finance_transaction', 'manual')),
  finance_entry_id uuid REFERENCES public.finance_entries(id) ON DELETE SET NULL,
  expense_id uuid REFERENCES public.expenses(id) ON DELETE SET NULL,
  acquisition_date date,
  bill_value numeric,
  vendor_name text,
  vendor_contact text,
  asset_tag text,
  serial_number text,
  location text,
  warranty_start_date date,
  warranty_end_date date,
  warranty_period_months integer,
  amc_start_date date,
  amc_end_date date,
  amc_period_months integer,
  amc_vendor text,
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'under_repair', 'disposed', 'written_off', 'placeholder')),
  disposal_date date,
  disposal_value numeric,
  disposal_notes text,
  bill_attachment_url text,
  template_key text,
  notes text,
  created_by text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT fixed_assets_finance_entry_unique UNIQUE (finance_entry_id)
);

CREATE INDEX idx_fixed_assets_society_id ON public.fixed_assets (society_id);
CREATE INDEX idx_fixed_assets_society_status ON public.fixed_assets (society_id, status);
CREATE INDEX idx_fixed_assets_society_sub_head ON public.fixed_assets (society_id, sub_head);
CREATE INDEX idx_fixed_assets_expense_id ON public.fixed_assets (expense_id) WHERE expense_id IS NOT NULL;
CREATE INDEX idx_fixed_assets_template_key ON public.fixed_assets (society_id, template_key) WHERE template_key IS NOT NULL;
CREATE UNIQUE INDEX fixed_assets_society_template_key_unique
  ON public.fixed_assets (society_id, template_key)
  WHERE template_key IS NOT NULL;

CREATE TRIGGER fixed_assets_updated_at
  BEFORE UPDATE ON public.fixed_assets
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

ALTER TABLE public.fixed_assets ENABLE ROW LEVEL SECURITY;
CREATE POLICY "fixed_assets all" ON public.fixed_assets FOR ALL USING (true) WITH CHECK (true);

-- Infer whether an expense group is under FIXED ASSETS major head.
CREATE OR REPLACE FUNCTION public.is_fixed_asset_expense_group(p_group_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.expense_groups g
    WHERE g.id = p_group_id
      AND COALESCE(
        NULLIF(trim(g.major_head), ''),
        CASE
          WHEN trim(g.name) ~* 'fixed asset|furniture|chair|equipment|machine|softner|softener|installation|asset|dg set|generator|lift|elevator|boring|borewell|fire fight|play area|gym|garden|cctv|solar|stp|wtp|softener'
            THEN 'FIXED ASSETS'
          ELSE 'MISCELLANEOUS'
        END
      ) = 'FIXED ASSETS'
  );
$$;

-- Upsert a fixed-asset row from a finance ledger entry linked to a FIXED ASSETS expense.
CREATE OR REPLACE FUNCTION public.upsert_fixed_asset_from_finance_entry(p_finance_entry_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
  v_fe public.finance_entries%ROWTYPE;
  v_exp public.expenses%ROWTYPE;
  v_group_name text;
  v_major_head text;
  v_sub_head text;
  v_asset_name text;
  v_acq_date date;
BEGIN
  SELECT * INTO v_fe FROM public.finance_entries WHERE id = p_finance_entry_id;
  IF NOT FOUND OR v_fe.expense_id IS NULL THEN
    RETURN;
  END IF;

  SELECT * INTO v_exp FROM public.expenses WHERE id = v_fe.expense_id;
  IF NOT FOUND OR v_exp.expense_category = 'food' THEN
    RETURN;
  END IF;

  IF v_exp.group_id IS NULL OR NOT public.is_fixed_asset_expense_group(v_exp.group_id) THEN
    RETURN;
  END IF;

  SELECT g.name, COALESCE(NULLIF(trim(g.major_head), ''), 'FIXED ASSETS')
  INTO v_group_name, v_major_head
  FROM public.expense_groups g
  WHERE g.id = v_exp.group_id;

  v_sub_head := COALESCE(NULLIF(trim(v_group_name), ''), 'General');
  v_asset_name := COALESCE(NULLIF(trim(v_exp.title), ''), v_sub_head);
  v_acq_date := COALESCE(v_exp.expense_date::date, v_fe.transaction_date::date, v_fe.created_at::date);

  INSERT INTO public.fixed_assets (
    society_id,
    asset_name,
    description,
    major_head,
    sub_head,
    expense_group_id,
    source_type,
    finance_entry_id,
    expense_id,
    acquisition_date,
    bill_value,
    vendor_name,
    bill_attachment_url,
    notes,
    status,
    created_by
  ) VALUES (
    v_fe.society_id,
    v_asset_name,
    NULLIF(trim(v_exp.notes), ''),
    v_major_head,
    v_sub_head,
    v_exp.group_id,
    'finance_transaction',
    v_fe.id,
    v_exp.id,
    v_acq_date,
    COALESCE(v_fe.total_amount, v_exp.total_amount),
    NULLIF(trim(v_exp.vendor_or_service), ''),
    v_exp.bill_screenshot_url,
    NULLIF(trim(v_fe.notes), ''),
    'active',
    v_fe.created_by
  )
  ON CONFLICT (finance_entry_id) DO UPDATE SET
    asset_name = EXCLUDED.asset_name,
    description = EXCLUDED.description,
    sub_head = EXCLUDED.sub_head,
    expense_group_id = EXCLUDED.expense_group_id,
    expense_id = EXCLUDED.expense_id,
    acquisition_date = EXCLUDED.acquisition_date,
    bill_value = EXCLUDED.bill_value,
    vendor_name = EXCLUDED.vendor_name,
    bill_attachment_url = EXCLUDED.bill_attachment_url,
    notes = EXCLUDED.notes,
    updated_at = now();
END;
$$;

CREATE OR REPLACE FUNCTION public.trg_sync_fixed_asset_from_finance_entry()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
BEGIN
  IF NEW.expense_id IS NOT NULL THEN
    PERFORM public.upsert_fixed_asset_from_finance_entry(NEW.id);
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER finance_entries_sync_fixed_asset
  AFTER INSERT OR UPDATE OF expense_id, total_amount, transaction_date, title, notes
  ON public.finance_entries
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_sync_fixed_asset_from_finance_entry();

-- Backfill from existing finance entries.
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT fe.id
    FROM public.finance_entries fe
    JOIN public.expenses e ON e.id = fe.expense_id
    WHERE e.expense_category <> 'food'
      AND e.group_id IS NOT NULL
      AND public.is_fixed_asset_expense_group(e.group_id)
  LOOP
    PERFORM public.upsert_fixed_asset_from_finance_entry(r.id);
  END LOOP;
END;
$$;

-- RBAC: default fixed_assets permission from finance when missing.
UPDATE public.society_roles
SET permissions = jsonb_set(
  permissions,
  '{fixed_assets}',
  COALESCE(permissions->'fixed_assets', COALESCE(permissions->'finance', 'false'::jsonb)),
  true
);
