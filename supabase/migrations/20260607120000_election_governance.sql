-- Election governance: nomination phase, voting window, admin-only results, committee apply.

ALTER TABLE public.polls
  ADD COLUMN IF NOT EXISTS election_phase text NOT NULL DEFAULT 'voting';

ALTER TABLE public.polls DROP CONSTRAINT IF EXISTS polls_election_phase_check;
ALTER TABLE public.polls
  ADD CONSTRAINT polls_election_phase_check CHECK (
    election_phase = ANY (ARRAY['nomination'::text, 'voting'::text, 'closed'::text, 'applied'::text])
  );

ALTER TABLE public.polls
  ADD COLUMN IF NOT EXISTS voting_starts_at timestamptz;

ALTER TABLE public.polls
  ADD COLUMN IF NOT EXISTS voting_ends_at timestamptz;

ALTER TABLE public.polls
  ADD COLUMN IF NOT EXISTS election_applied_at timestamptz;

ALTER TABLE public.polls
  ADD COLUMN IF NOT EXISTS election_term_from date;

ALTER TABLE public.polls
  ADD COLUMN IF NOT EXISTS election_term_to date;

ALTER TABLE public.polls
  ADD COLUMN IF NOT EXISTS open_posts jsonb NOT NULL DEFAULT '{"president":true,"vice_president":true,"secretary":true,"treasurer":true,"committee":true}'::jsonb;

COMMENT ON COLUMN public.polls.election_phase IS 'nomination → voting → closed → applied (roster updated).';
COMMENT ON COLUMN public.polls.open_posts IS 'Which executive/core posts accept self-nomination during nomination phase.';

-- Vice-President post + candidate linkage
ALTER TABLE public.poll_options DROP CONSTRAINT IF EXISTS poll_options_election_post_check;
ALTER TABLE public.poll_options
  ADD CONSTRAINT poll_options_election_post_check CHECK (
    election_post IS NULL
    OR election_post = ANY (
      ARRAY['president'::text, 'vice_president'::text, 'secretary'::text, 'treasurer'::text, 'committee'::text]
    )
  );

ALTER TABLE public.poll_options
  ADD COLUMN IF NOT EXISTS member_id uuid REFERENCES public.members(id) ON DELETE SET NULL;

ALTER TABLE public.poll_options
  ADD COLUMN IF NOT EXISTS flat_id uuid REFERENCES public.flats(id) ON DELETE SET NULL;

ALTER TABLE public.poll_options
  ADD COLUMN IF NOT EXISTS flat_number text;

ALTER TABLE public.poll_options
  ADD COLUMN IF NOT EXISTS nominated_by text;

COMMENT ON COLUMN public.poll_options.nominated_by IS 'member or resident id that proposed this candidate (self-nomination when matches voter).';

ALTER TABLE public.poll_election_ballots
  ADD COLUMN IF NOT EXISTS voter_phone text;

CREATE INDEX IF NOT EXISTS idx_poll_election_ballots_phone ON public.poll_election_ballots (poll_id, voter_phone);

-- Trace elected roster back to election
ALTER TABLE public.committee_members
  ADD COLUMN IF NOT EXISTS source_poll_id uuid REFERENCES public.polls(id) ON DELETE SET NULL;

ALTER TABLE public.committee_members
  ADD COLUMN IF NOT EXISTS source_option_id uuid REFERENCES public.poll_options(id) ON DELETE SET NULL;
