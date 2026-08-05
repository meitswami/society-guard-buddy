-- Pin search_path on Phase 2 election functions (advisor lint 0011).
ALTER FUNCTION public.election_proxy_enforce_deadline() SET search_path = public;
ALTER FUNCTION public.prevent_election_ballot_mutation() SET search_path = public;
ALTER FUNCTION public.prevent_election_audit_mutation() SET search_path = public;
ALTER FUNCTION public.log_election_audit_event(uuid, uuid, text, text, text, text, jsonb) SET search_path = public;
ALTER FUNCTION public.flat_has_maintenance_arrears_over_days(uuid, date, integer) SET search_path = public;
ALTER FUNCTION public.election_quorum_required(integer) SET search_path = public;
ALTER FUNCTION public.member_election_eligibility(uuid, uuid, date, integer) SET search_path = public;
ALTER FUNCTION public.record_election_voting_method(uuid, text, text, boolean) SET search_path = public;
