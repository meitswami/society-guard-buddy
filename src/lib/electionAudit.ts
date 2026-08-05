import { supabase } from '@/integrations/supabase/client';

export type ElectionAuditEventType =
  | 'voting_method_recorded'
  | 'nomination_submitted'
  | 'ballot_cast'
  | 'proxy_submitted'
  | 'proxy_approved'
  | 'proxy_rejected'
  | 'proxy_revoked'
  | 'phase_changed'
  | 'election_tallied'
  | 'committee_published'
  | 'eligibility_checked'
  | 'quorum_snapshot'
  | string;

/** Append-only election audit (DB also blocks UPDATE/DELETE). */
export async function logElectionAudit(opts: {
  societyId: string;
  pollId?: string | null;
  eventType: ElectionAuditEventType;
  actorType?: 'admin' | 'resident' | 'system' | string | null;
  actorId?: string | null;
  actorName?: string | null;
  payload?: Record<string, unknown>;
}): Promise<{ id: string | null; error: string | null }> {
  const { data, error } = await supabase.rpc('log_election_audit_event', {
    p_society_id: opts.societyId,
    p_poll_id: opts.pollId ?? null,
    p_event_type: opts.eventType,
    p_actor_type: opts.actorType ?? null,
    p_actor_id: opts.actorId ?? null,
    p_actor_name: opts.actorName ?? null,
    p_payload: opts.payload ?? {},
  });

  if (error) {
    console.error('Election audit failed:', error);
    return { id: null, error: error.message };
  }
  return { id: typeof data === 'string' ? data : null, error: null };
}

export type ElectionVotingMethod = 'secret_ballot' | 'show_of_hands';

/** Record bye-law voting method before polling (audited in DB). */
export async function recordElectionVotingMethod(opts: {
  pollId: string;
  method: ElectionVotingMethod;
  recordedBy?: string | null;
  separateOfficeVotes?: boolean;
}): Promise<{ error: string | null }> {
  const { error } = await supabase.rpc('record_election_voting_method', {
    p_poll_id: opts.pollId,
    p_method: opts.method,
    p_recorded_by: opts.recordedBy ?? null,
    p_separate_office_votes: opts.separateOfficeVotes ?? false,
  });
  return { error: error?.message ?? null };
}
