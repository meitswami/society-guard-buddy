-- Event contributions: flat owners vs outsiders; headcount / split mode metadata

ALTER TABLE public.event_contributions
  ADD COLUMN IF NOT EXISTS contributor_type text NOT NULL DEFAULT 'flat_owner',
  ADD COLUMN IF NOT EXISTS outsider_name text,
  ADD COLUMN IF NOT EXISTS adult_count integer,
  ADD COLUMN IF NOT EXISTS kid_count integer,
  ADD COLUMN IF NOT EXISTS split_mode text;

COMMENT ON COLUMN public.event_contributions.contributor_type IS 'flat_owner | outsider';
COMMENT ON COLUMN public.event_contributions.split_mode IS 'individual | headcount | lump_equal | same_per_flat';
