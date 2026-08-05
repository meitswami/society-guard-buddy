-- Member consent: Option A (Secret Ballot) vs Option B (Show of Hands)
-- before voting method is finalized. Does not alter existing Society data.

ALTER TABLE public.polls
  ADD COLUMN IF NOT EXISTS voting_method_consent_open boolean NOT NULL DEFAULT false;

ALTER TABLE public.polls
  ADD COLUMN IF NOT EXISTS voting_method_consent_opened_at timestamptz;

ALTER TABLE public.polls
  ADD COLUMN IF NOT EXISTS voting_method_consent_opened_by text;

COMMENT ON COLUMN public.polls.voting_method_consent_open IS
  'When true, members may consent to Option A (secret_ballot) or Option B (show_of_hands) before finalization.';

CREATE TABLE IF NOT EXISTS public.election_voting_method_consents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id uuid NOT NULL REFERENCES public.societies(id) ON DELETE CASCADE,
  poll_id uuid NOT NULL REFERENCES public.polls(id) ON DELETE CASCADE,
  member_id uuid NOT NULL REFERENCES public.members(id) ON DELETE CASCADE,
  choice text NOT NULL,
  member_name text,
  flat_number text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT election_voting_method_consents_choice_check CHECK (
    choice = ANY (ARRAY['secret_ballot'::text, 'show_of_hands'::text])
  ),
  CONSTRAINT election_voting_method_consents_poll_member_unique UNIQUE (poll_id, member_id)
);

CREATE INDEX IF NOT EXISTS idx_election_vm_consents_poll
  ON public.election_voting_method_consents (poll_id);

COMMENT ON TABLE public.election_voting_method_consents IS
  'One immutable consent per member: Option A secret_ballot or Option B show_of_hands.';

ALTER TABLE public.election_voting_method_consents ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "All access election_voting_method_consents" ON public.election_voting_method_consents;
CREATE POLICY "All access election_voting_method_consents" ON public.election_voting_method_consents
  FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON TABLE public.election_voting_method_consents TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.prevent_vm_consent_mutation()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  RAISE EXCEPTION 'Voting-method consents are immutable after submission'
    USING ERRCODE = 'restrict_violation';
END;
$$;

DROP TRIGGER IF EXISTS trg_election_vm_consents_immutable ON public.election_voting_method_consents;
CREATE TRIGGER trg_election_vm_consents_immutable
  BEFORE UPDATE OR DELETE ON public.election_voting_method_consents
  FOR EACH ROW EXECUTE FUNCTION public.prevent_vm_consent_mutation();

CREATE OR REPLACE FUNCTION public.election_voting_method_consent_tally(p_poll_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SET search_path = public AS $$
  SELECT jsonb_build_object(
    'secret_ballot', COALESCE(SUM(CASE WHEN choice = 'secret_ballot' THEN 1 ELSE 0 END), 0),
    'show_of_hands', COALESCE(SUM(CASE WHEN choice = 'show_of_hands' THEN 1 ELSE 0 END), 0),
    'total', COUNT(*)
  )
  FROM public.election_voting_method_consents
  WHERE poll_id = p_poll_id;
$$;

GRANT EXECUTE ON FUNCTION public.election_voting_method_consent_tally(uuid) TO anon, authenticated, service_role;
