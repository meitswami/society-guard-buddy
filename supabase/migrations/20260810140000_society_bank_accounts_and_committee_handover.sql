-- Society bank accounts (member-facing pay-to details) + Evergreen Heights
-- Aug 2026 AGM committee handover (elected 9 Aug, effective 14 Aug).

CREATE TABLE IF NOT EXISTS public.society_bank_accounts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id uuid NOT NULL REFERENCES public.societies(id) ON DELETE CASCADE,
  bank_name text NOT NULL,
  account_holder_name text NOT NULL,
  account_number text NOT NULL,
  ifsc text NOT NULL,
  branch_name text,
  branch_address text,
  micr text,
  account_type text,
  currency text NOT NULL DEFAULT 'INR',
  upi_vpa text,
  customer_id text,
  is_primary boolean NOT NULL DEFAULT true,
  is_active boolean NOT NULL DEFAULT true,
  effective_from date,
  effective_to date,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS society_bank_accounts_one_primary
  ON public.society_bank_accounts (society_id)
  WHERE is_primary = true AND is_active = true;

CREATE INDEX IF NOT EXISTS idx_society_bank_accounts_society
  ON public.society_bank_accounts (society_id, is_active);

DROP TRIGGER IF EXISTS update_society_bank_accounts_updated_at ON public.society_bank_accounts;
CREATE TRIGGER update_society_bank_accounts_updated_at
  BEFORE UPDATE ON public.society_bank_accounts
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

ALTER TABLE public.society_bank_accounts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "society_bank_accounts all" ON public.society_bank_accounts;
CREATE POLICY "society_bank_accounts all" ON public.society_bank_accounts
  FOR ALL USING (true) WITH CHECK (true);

GRANT ALL ON TABLE public.society_bank_accounts TO anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Seed: Evergreen Heights HDFC current account (from bank letter)
-- ---------------------------------------------------------------------------
INSERT INTO public.society_bank_accounts (
  society_id,
  bank_name,
  account_holder_name,
  account_number,
  ifsc,
  branch_name,
  branch_address,
  micr,
  account_type,
  currency,
  customer_id,
  is_primary,
  is_active,
  effective_from,
  notes
)
SELECT
  '67d326db-6718-4509-ab9b-69d476b0305d'::uuid,
  'HDFC Bank',
  'M/S. EVERGREEN HEIGHTS RESIDENTS WELFARE SCTY',
  '50200123812910',
  'HDFC0010627',
  'ENGINEERS COLONY',
  'HDFC BANK LTD, 6D ENGINEERS COLONY, MANSAROVER, JAIPUR, RAJASTHAN 302020',
  '302240129',
  'TASC CURRENT ACCOUNT (762)',
  'INR',
  '364842440',
  true,
  true,
  '2026-08-07'::date,
  'Society operating account opened 07-Aug-2026. Branch code 10627. Statement contact: EVERGREENHEIGHTS755@GMAIL.COM'
WHERE EXISTS (
  SELECT 1 FROM public.societies WHERE id = '67d326db-6718-4509-ab9b-69d476b0305d'
)
AND NOT EXISTS (
  SELECT 1
  FROM public.society_bank_accounts
  WHERE society_id = '67d326db-6718-4509-ab9b-69d476b0305d'
    AND account_number = '50200123812910'
    AND ifsc = 'HDFC0010627'
);

-- ---------------------------------------------------------------------------
-- Committee handover: previous roster through to 13 Aug; new from 14 Aug
-- Election: General Meeting 9 Aug 2026, unanimous without opposition
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  sid uuid := '67d326db-6718-4509-ab9b-69d476b0305d';
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.societies WHERE id = sid) THEN
    RETURN;
  END IF;

  -- Close current active committee on 13 Aug 2026 (remain visible until that date).
  UPDATE public.committee_members
  SET
    term_to = '2026-08-13'::date,
    updated_at = now()
  WHERE society_id = sid
    AND is_active = true
    AND (term_from IS NULL OR term_from < '2026-08-14'::date)
    AND (term_to IS NULL OR term_to >= '2026-08-14'::date);

  -- Avoid duplicate insert if migration re-run.
  IF EXISTS (
    SELECT 1 FROM public.committee_members
    WHERE society_id = sid
      AND term_from = '2026-08-14'::date
      AND name = 'Suresh Pareek'
      AND position = 'President'
  ) THEN
    NULL;
  ELSE
    INSERT INTO public.committee_members (
      society_id, name, position, selection_type, term_from, term_to,
      sort_order, is_active
    ) VALUES
      (sid, 'Suresh Pareek', 'President', 'elected', '2026-08-14', NULL, 0, true),
      (sid, 'Jaya', 'Vice-President', 'elected', '2026-08-14', NULL, 1, true),
      (sid, 'Virendra Sharma', 'Secretary', 'elected', '2026-08-14', NULL, 2, true),
      (sid, 'Anil Kumar Sharma', 'Treasurer', 'elected', '2026-08-14', NULL, 3, true),
      (sid, 'Mamta Soni', 'Cultural Secretary', 'elected', '2026-08-14', NULL, 4, true),
      (sid, 'Sunil Sharma', 'Committee Member', 'elected', '2026-08-14', NULL, 5, true),
      (sid, 'Abhishek Sharma', 'Committee Member', 'elected', '2026-08-14', NULL, 6, true);
  END IF;

  -- Record the electing general meeting (idempotent by title + date).
  IF NOT EXISTS (
    SELECT 1 FROM public.meetings
    WHERE society_id = sid
      AND title = 'General Meeting — Executive Committee Election'
      AND meeting_at::date = '2026-08-09'
  ) THEN
    INSERT INTO public.meetings (
      society_id,
      title,
      description,
      meeting_at,
      meeting_kind,
      location,
      status,
      published,
      minutes_summary,
      executives_present,
      created_by
    ) VALUES (
      sid,
      'General Meeting — Executive Committee Election',
      'Election of new Executive Committee. Election was unanimous without opposition.',
      '2026-08-09T11:00:00+05:30',
      'general_body',
      'Society premises',
      'completed',
      true,
      'New Executive Committee elected unanimously without opposition on 9 August 2026. '
        || 'Previous committee continues until 13 August 2026. '
        || 'New committee takes effect from 14 August 2026. '
        || 'President: Suresh Pareek; Vice-President: Jaya; Secretary: Virendra Sharma; '
        || 'Treasurer: Anil Kumar Sharma; Cultural Secretary: Mamta Soni; '
        || 'Members: Sunil Sharma, Abhishek Sharma.',
      'Outgoing committee present for handover briefing. Incoming: Suresh Pareek, Jaya, Virendra Sharma, Anil Kumar Sharma, Mamta Soni, Sunil Sharma, Abhishek Sharma.',
      'System'
    );
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';
