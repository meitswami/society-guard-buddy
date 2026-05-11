-- Election-style voting (ranked choice per post) alongside standard polls.

ALTER TABLE public.polls
  ADD COLUMN IF NOT EXISTS poll_kind text NOT NULL DEFAULT 'standard';

ALTER TABLE public.polls DROP CONSTRAINT IF EXISTS polls_poll_kind_check;
ALTER TABLE public.polls
  ADD CONSTRAINT polls_poll_kind_check CHECK (poll_kind = ANY (ARRAY['standard'::text, 'election'::text]));

ALTER TABLE public.polls
  ADD COLUMN IF NOT EXISTS election_committee_seats integer NOT NULL DEFAULT 5;

ALTER TABLE public.polls
  ADD COLUMN IF NOT EXISTS election_results jsonb;

COMMENT ON COLUMN public.polls.poll_kind IS 'standard = single-choice poll; election = MC ranked voting.';
COMMENT ON COLUMN public.polls.election_committee_seats IS 'Number of committee seats to fill (election only).';
COMMENT ON COLUMN public.polls.election_results IS 'Computed winners JSON when election is closed.';

ALTER TABLE public.poll_options
  ADD COLUMN IF NOT EXISTS election_post text;

ALTER TABLE public.poll_options DROP CONSTRAINT IF EXISTS poll_options_election_post_check;
ALTER TABLE public.poll_options
  ADD CONSTRAINT poll_options_election_post_check CHECK (
    election_post IS NULL
    OR election_post = ANY (ARRAY['president'::text, 'secretary'::text, 'treasurer'::text, 'committee'::text])
  );

COMMENT ON COLUMN public.poll_options.election_post IS 'For election polls: which post this candidate runs for.';

CREATE TABLE IF NOT EXISTS public.poll_election_ballots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  poll_id uuid NOT NULL REFERENCES public.polls(id) ON DELETE CASCADE,
  voter_id text NOT NULL,
  flat_id uuid REFERENCES public.flats(id) ON DELETE SET NULL,
  flat_number text,
  rankings jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT poll_election_ballots_poll_voter_unique UNIQUE (poll_id, voter_id)
);

CREATE INDEX IF NOT EXISTS idx_poll_election_ballots_poll_id ON public.poll_election_ballots (poll_id);
CREATE INDEX IF NOT EXISTS idx_poll_election_ballots_flat ON public.poll_election_ballots (poll_id, flat_id);

COMMENT ON TABLE public.poll_election_ballots IS 'One row per member voter; rankings JSON maps post -> { option_id: rank }.';

ALTER TABLE public.poll_election_ballots ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "All access poll_election_ballots" ON public.poll_election_ballots;
CREATE POLICY "All access poll_election_ballots" ON public.poll_election_ballots FOR ALL USING (true) WITH CHECK (true);
