-- Phase 2: Bye-law election governance (consolidated source of truth for the repo).
-- Applied remotely as:
--   bye_law_election_governance_polls_members
--   bye_law_election_governance_proxies
--   bye_law_election_governance_ballots_audit
--   bye_law_election_governance_eligibility_fns
--   bye_law_election_governance_search_path
-- Does NOT delete or rewrite existing Society / election row data.

-- ---------------------------------------------------------------------------
-- 1) Polls — voting method, bye-law mode, quorum snapshot
-- ---------------------------------------------------------------------------
ALTER TABLE public.polls
  ADD COLUMN IF NOT EXISTS voting_method text;

ALTER TABLE public.polls DROP CONSTRAINT IF EXISTS polls_voting_method_check;
ALTER TABLE public.polls
  ADD CONSTRAINT polls_voting_method_check CHECK (
    voting_method IS NULL
    OR voting_method = ANY (ARRAY['secret_ballot'::text, 'show_of_hands'::text])
  );

ALTER TABLE public.polls
  ADD COLUMN IF NOT EXISTS voting_method_recorded_at timestamptz;

ALTER TABLE public.polls
  ADD COLUMN IF NOT EXISTS voting_method_recorded_by text;

ALTER TABLE public.polls
  ADD COLUMN IF NOT EXISTS separate_office_votes boolean NOT NULL DEFAULT false;

ALTER TABLE public.polls
  ADD COLUMN IF NOT EXISTS bye_law_mode boolean NOT NULL DEFAULT true;

ALTER TABLE public.polls
  ADD COLUMN IF NOT EXISTS member_count_at_election integer;

ALTER TABLE public.polls
  ADD COLUMN IF NOT EXISTS election_quorum_required integer;

ALTER TABLE public.polls
  ADD COLUMN IF NOT EXISTS first_mc_meeting_deadline date;

COMMENT ON COLUMN public.polls.voting_method IS
  'Bye-laws: secret_ballot | show_of_hands. Must be recorded before polling.';
COMMENT ON COLUMN public.polls.separate_office_votes IS
  'When false (default), do not auto-run separate per-office ballots unless expressly approved.';
COMMENT ON COLUMN public.polls.bye_law_mode IS
  'When true, enforce 7-seat MC, one-member-one-vote, no auto runner-up seating.';
COMMENT ON COLUMN public.polls.election_quorum_required IS
  'Snapshot of ceil(member_count * 3/4) at election open.';
COMMENT ON COLUMN public.polls.first_mc_meeting_deadline IS
  'First MC meeting must be on or before this date (election + 30 days).';

-- New elections default to fixed 7-seat committee (existing rows keep their values).
ALTER TABLE public.polls
  ALTER COLUMN target_committee_size SET DEFAULT 7;

ALTER TABLE public.polls
  ALTER COLUMN open_posts SET DEFAULT
    '{"president":true,"vice_president":true,"secretary":true,"treasurer":true,"committee":true}'::jsonb;

-- ---------------------------------------------------------------------------
-- 2) Joint ownership — designated voter; removal disqualification
-- ---------------------------------------------------------------------------
ALTER TABLE public.flats
  ADD COLUMN IF NOT EXISTS designated_voter_member_id uuid REFERENCES public.members(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_flats_designated_voter
  ON public.flats (designated_voter_member_id)
  WHERE designated_voter_member_id IS NOT NULL;

COMMENT ON COLUMN public.flats.designated_voter_member_id IS
  'Joint ownership: designated Society member who holds the voting right for this flat.';

ALTER TABLE public.members
  ADD COLUMN IF NOT EXISTS election_disqualified_until date;

COMMENT ON COLUMN public.members.election_disqualified_until IS
  'If set, member cannot vote or contest until this date (e.g. 2 years after Special Resolution removal).';

-- ---------------------------------------------------------------------------
-- 3) Election proxies (written authorisation, 48h, max 1 principal per proxy)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.election_proxies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id uuid NOT NULL REFERENCES public.societies(id) ON DELETE CASCADE,
  poll_id uuid NOT NULL REFERENCES public.polls(id) ON DELETE CASCADE,
  principal_member_id uuid NOT NULL REFERENCES public.members(id) ON DELETE CASCADE,
  proxy_holder_member_id uuid NOT NULL REFERENCES public.members(id) ON DELETE CASCADE,
  authorization_document_url text,
  authorization_notes text,
  submitted_at timestamptz NOT NULL DEFAULT now(),
  submitted_by text,
  meeting_at timestamptz,
  status text NOT NULL DEFAULT 'pending',
  reviewed_by text,
  reviewed_at timestamptz,
  rejection_reason text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT election_proxies_status_check CHECK (
    status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text, 'revoked'::text])
  ),
  CONSTRAINT election_proxies_not_self CHECK (principal_member_id <> proxy_holder_member_id),
  CONSTRAINT election_proxies_poll_principal_unique UNIQUE (poll_id, principal_member_id)
);

-- One person may not act as proxy for more than one member (active proxies only).
CREATE UNIQUE INDEX IF NOT EXISTS election_proxies_one_holder_per_poll
  ON public.election_proxies (poll_id, proxy_holder_member_id)
  WHERE status = ANY (ARRAY['pending'::text, 'approved'::text]);

CREATE INDEX IF NOT EXISTS idx_election_proxies_poll ON public.election_proxies (poll_id);
CREATE INDEX IF NOT EXISTS idx_election_proxies_society ON public.election_proxies (society_id);
CREATE INDEX IF NOT EXISTS idx_election_proxies_holder ON public.election_proxies (proxy_holder_member_id);

COMMENT ON TABLE public.election_proxies IS
  'Written proxy authorisations. Must be submitted ≥48 hours before the meeting; one holder → one principal.';

ALTER TABLE public.election_proxies ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "All access election_proxies" ON public.election_proxies;
CREATE POLICY "All access election_proxies" ON public.election_proxies
  FOR ALL USING (true) WITH CHECK (true);

GRANT ALL ON TABLE public.election_proxies TO anon, authenticated, service_role;

-- Enforce 48-hour deadline relative to meeting_at (or poll voting_starts_at).
CREATE OR REPLACE FUNCTION public.election_proxy_enforce_deadline()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_meeting timestamptz;
  v_deadline_hours integer := 48;
BEGIN
  v_meeting := NEW.meeting_at;
  IF v_meeting IS NULL THEN
    SELECT p.voting_starts_at INTO v_meeting
    FROM public.polls p
    WHERE p.id = NEW.poll_id;
  END IF;

  IF v_meeting IS NOT NULL
     AND NEW.submitted_at > (v_meeting - make_interval(hours => v_deadline_hours)) THEN
    RAISE EXCEPTION
      'Proxy authorisation must be submitted at least % hours before the meeting',
      v_deadline_hours
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_election_proxy_deadline ON public.election_proxies;
CREATE TRIGGER trg_election_proxy_deadline
  BEFORE INSERT OR UPDATE OF submitted_at, meeting_at, poll_id, status
  ON public.election_proxies
  FOR EACH ROW
  WHEN (NEW.status IS DISTINCT FROM 'rejected' AND NEW.status IS DISTINCT FROM 'revoked')
  EXECUTE FUNCTION public.election_proxy_enforce_deadline();

-- ---------------------------------------------------------------------------
-- 4) Ballots — metadata + immutability (no UPDATE/DELETE after insert)
-- ---------------------------------------------------------------------------
ALTER TABLE public.poll_election_ballots
  ADD COLUMN IF NOT EXISTS choices jsonb NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE public.poll_election_ballots
  ADD COLUMN IF NOT EXISTS ballot_method text;

ALTER TABLE public.poll_election_ballots DROP CONSTRAINT IF EXISTS poll_election_ballots_ballot_method_check;
ALTER TABLE public.poll_election_ballots
  ADD CONSTRAINT poll_election_ballots_ballot_method_check CHECK (
    ballot_method IS NULL
    OR ballot_method = ANY (ARRAY['secret_ballot'::text, 'show_of_hands'::text, 'ranked_legacy'::text])
  );

ALTER TABLE public.poll_election_ballots
  ADD COLUMN IF NOT EXISTS is_proxy_vote boolean NOT NULL DEFAULT false;

ALTER TABLE public.poll_election_ballots
  ADD COLUMN IF NOT EXISTS proxy_id uuid REFERENCES public.election_proxies(id) ON DELETE SET NULL;

ALTER TABLE public.poll_election_ballots
  ADD COLUMN IF NOT EXISTS submitted_at timestamptz NOT NULL DEFAULT now();

COMMENT ON COLUMN public.poll_election_ballots.choices IS
  'Bye-law ballots: selected option ids / seat choices (non-ranked). rankings retained for legacy.';
COMMENT ON COLUMN public.poll_election_ballots.ballot_method IS
  'Method recorded on the ballot at submission time.';

CREATE OR REPLACE FUNCTION public.prevent_election_ballot_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'UPDATE' THEN
    RAISE EXCEPTION 'Election ballots are immutable after submission'
      USING ERRCODE = 'restrict_violation';
  ELSIF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'Election ballots cannot be deleted'
      USING ERRCODE = 'restrict_violation';
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_poll_election_ballots_immutable ON public.poll_election_ballots;
CREATE TRIGGER trg_poll_election_ballots_immutable
  BEFORE UPDATE OR DELETE ON public.poll_election_ballots
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_election_ballot_mutation();

-- ---------------------------------------------------------------------------
-- 5) Append-only election audit trail
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.election_audit_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id uuid NOT NULL REFERENCES public.societies(id) ON DELETE CASCADE,
  poll_id uuid REFERENCES public.polls(id) ON DELETE SET NULL,
  event_type text NOT NULL,
  actor_type text,
  actor_id text,
  actor_name text,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_election_audit_events_poll
  ON public.election_audit_events (poll_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_election_audit_events_society
  ON public.election_audit_events (society_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_election_audit_events_type
  ON public.election_audit_events (event_type);

COMMENT ON TABLE public.election_audit_events IS
  'Append-only audit of election-critical actions (method recorded, ballot cast, proxy, tally, publish, etc.).';

ALTER TABLE public.election_audit_events ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "election_audit_events_select" ON public.election_audit_events;
DROP POLICY IF EXISTS "election_audit_events_insert" ON public.election_audit_events;
CREATE POLICY "election_audit_events_select" ON public.election_audit_events
  FOR SELECT USING (true);
CREATE POLICY "election_audit_events_insert" ON public.election_audit_events
  FOR INSERT WITH CHECK (true);
-- No UPDATE/DELETE policies — and trigger blocks mutations.

GRANT SELECT, INSERT ON TABLE public.election_audit_events TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.prevent_election_audit_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION 'Election audit events are append-only'
    USING ERRCODE = 'restrict_violation';
END;
$$;

DROP TRIGGER IF EXISTS trg_election_audit_immutable ON public.election_audit_events;
CREATE TRIGGER trg_election_audit_immutable
  BEFORE UPDATE OR DELETE ON public.election_audit_events
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_election_audit_mutation();

CREATE OR REPLACE FUNCTION public.log_election_audit_event(
  p_society_id uuid,
  p_poll_id uuid,
  p_event_type text,
  p_actor_type text DEFAULT NULL,
  p_actor_id text DEFAULT NULL,
  p_actor_name text DEFAULT NULL,
  p_payload jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
  v_id uuid;
BEGIN
  INSERT INTO public.election_audit_events (
    society_id, poll_id, event_type, actor_type, actor_id, actor_name, payload
  ) VALUES (
    p_society_id, p_poll_id, p_event_type, p_actor_type, p_actor_id, p_actor_name,
    COALESCE(p_payload, '{}'::jsonb)
  )
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.log_election_audit_event(uuid, uuid, text, text, text, text, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_election_audit_event(uuid, uuid, text, text, text, text, jsonb)
  TO anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 6) Eligibility helpers (arrears > 60 days, designated voter, disqualification)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.flat_has_maintenance_arrears_over_days(
  p_flat_id uuid,
  p_as_of date DEFAULT CURRENT_DATE,
  p_days integer DEFAULT 60
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY INVOKER
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.maintenance_payments mp
    WHERE mp.flat_id = p_flat_id
      AND COALESCE(mp.payment_status, '') NOT IN ('verified', 'paid')
      AND mp.due_date IS NOT NULL
      AND mp.due_date <= (p_as_of - p_days)
  );
$$;

COMMENT ON FUNCTION public.flat_has_maintenance_arrears_over_days(uuid, date, integer) IS
  'True when the flat has maintenance/common-expense dues unpaid more than p_days before p_as_of.';

CREATE OR REPLACE FUNCTION public.election_quorum_required(p_member_count integer)
RETURNS integer
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p_member_count IS NULL OR p_member_count < 1 THEN 0
    ELSE CEIL(p_member_count * 3.0 / 4.0)::integer
  END;
$$;

CREATE OR REPLACE FUNCTION public.member_election_eligibility(
  p_member_id uuid,
  p_society_id uuid,
  p_as_of date DEFAULT CURRENT_DATE,
  p_arrears_days integer DEFAULT 60
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
AS $$
DECLARE
  v_member public.members%ROWTYPE;
  v_flat public.flats%ROWTYPE;
  v_eligible boolean := true;
  v_reasons text[] := ARRAY[]::text[];
  v_arrears boolean := false;
  v_is_designated boolean := true;
BEGIN
  SELECT * INTO v_member FROM public.members WHERE id = p_member_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'eligible', false,
      'reasons', jsonb_build_array('member_not_found'),
      'arrears', false,
      'is_designated_voter', false
    );
  END IF;

  IF v_member.date_leave IS NOT NULL AND v_member.date_leave <= p_as_of THEN
    v_eligible := false;
    v_reasons := array_append(v_reasons, 'member_left');
  END IF;

  IF v_member.election_disqualified_until IS NOT NULL
     AND v_member.election_disqualified_until >= p_as_of THEN
    v_eligible := false;
    v_reasons := array_append(v_reasons, 'removal_disqualification');
  END IF;

  SELECT * INTO v_flat FROM public.flats WHERE id = v_member.flat_id;
  IF FOUND THEN
    IF p_society_id IS NOT NULL AND v_flat.society_id IS DISTINCT FROM p_society_id THEN
      v_eligible := false;
      v_reasons := array_append(v_reasons, 'wrong_society');
    END IF;

    -- Joint ownership: if a designated voter is set, only that member votes for the flat.
    IF v_flat.designated_voter_member_id IS NOT NULL
       AND v_flat.designated_voter_member_id IS DISTINCT FROM p_member_id THEN
      v_is_designated := false;
      v_eligible := false;
      v_reasons := array_append(v_reasons, 'not_designated_joint_voter');
    END IF;

    v_arrears := public.flat_has_maintenance_arrears_over_days(v_flat.id, p_as_of, p_arrears_days);
    IF v_arrears THEN
      v_eligible := false;
      v_reasons := array_append(v_reasons, 'maintenance_arrears_over_60_days');
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'eligible', v_eligible,
    'reasons', to_jsonb(v_reasons),
    'arrears', v_arrears,
    'is_designated_voter', v_is_designated,
    'member_id', p_member_id,
    'flat_id', v_member.flat_id,
    'as_of', p_as_of,
    'arrears_days', p_arrears_days
  );
END;
$$;

COMMENT ON FUNCTION public.member_election_eligibility(uuid, uuid, date, integer) IS
  'Bye-law eligibility: designated joint voter, arrears >60 days, removal disqualification.';

REVOKE ALL ON FUNCTION public.flat_has_maintenance_arrears_over_days(uuid, date, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.election_quorum_required(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.member_election_eligibility(uuid, uuid, date, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.flat_has_maintenance_arrears_over_days(uuid, date, integer)
  TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.election_quorum_required(integer)
  TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.member_election_eligibility(uuid, uuid, date, integer)
  TO anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 7) Record voting method helper (audited)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.record_election_voting_method(
  p_poll_id uuid,
  p_method text,
  p_recorded_by text DEFAULT NULL,
  p_separate_office_votes boolean DEFAULT false
)
RETURNS public.polls
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
  v_poll public.polls%ROWTYPE;
BEGIN
  IF p_method IS NULL OR p_method NOT IN ('secret_ballot', 'show_of_hands') THEN
    RAISE EXCEPTION 'voting_method must be secret_ballot or show_of_hands'
      USING ERRCODE = 'check_violation';
  END IF;

  UPDATE public.polls
  SET
    voting_method = p_method,
    voting_method_recorded_at = now(),
    voting_method_recorded_by = p_recorded_by,
    separate_office_votes = COALESCE(p_separate_office_votes, false)
  WHERE id = p_poll_id
    AND poll_kind = 'election'
  RETURNING * INTO v_poll;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Election poll not found: %', p_poll_id;
  END IF;

  IF v_poll.society_id IS NOT NULL THEN
    PERFORM public.log_election_audit_event(
      v_poll.society_id,
      v_poll.id,
      'voting_method_recorded',
      'admin',
      NULL,
      p_recorded_by,
      jsonb_build_object(
        'voting_method', p_method,
        'separate_office_votes', COALESCE(p_separate_office_votes, false)
      )
    );
  END IF;

  RETURN v_poll;
END;
$$;

REVOKE ALL ON FUNCTION public.record_election_voting_method(uuid, text, text, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_election_voting_method(uuid, text, text, boolean)
  TO anon, authenticated, service_role;
