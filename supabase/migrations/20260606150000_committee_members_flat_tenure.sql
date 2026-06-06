-- Committee roster: flat link, tenure, elected/nominated, flat owner snapshot.

ALTER TABLE public.committee_members
  ADD COLUMN IF NOT EXISTS flat_id uuid REFERENCES public.flats(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS flat_number text,
  ADD COLUMN IF NOT EXISTS flat_owner_name text,
  ADD COLUMN IF NOT EXISTS term_from date,
  ADD COLUMN IF NOT EXISTS term_to date,
  ADD COLUMN IF NOT EXISTS selection_type text;

ALTER TABLE public.committee_members DROP CONSTRAINT IF EXISTS committee_members_selection_type_check;

ALTER TABLE public.committee_members
  ADD CONSTRAINT committee_members_selection_type_check
    CHECK (selection_type IS NULL OR selection_type = ANY (ARRAY['elected'::text, 'nominated'::text]));

COMMENT ON COLUMN public.committee_members.flat_number IS 'Flat number for the committee member / represented flat.';
COMMENT ON COLUMN public.committee_members.flat_owner_name IS 'Primary member name from Residents at save time.';
COMMENT ON COLUMN public.committee_members.term_from IS 'Start of committee tenure.';
COMMENT ON COLUMN public.committee_members.term_to IS 'End of tenure; NULL = until retirement / ongoing.';
COMMENT ON COLUMN public.committee_members.selection_type IS 'elected or nominated.';

CREATE INDEX IF NOT EXISTS idx_committee_members_flat_id ON public.committee_members (flat_id)
  WHERE flat_id IS NOT NULL;
