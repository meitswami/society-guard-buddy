import { supabase } from '@/integrations/supabase/client';
import type { ElectionVotingMethod } from '@/lib/electionGovernance';
import { logElectionAudit } from '@/lib/electionAudit';
import { recordElectionVotingMethod } from '@/lib/electionAudit';

/** Option A / B presented to members before the voting method is finalized. */
export const VOTING_METHOD_OPTIONS = {
  secret_ballot: {
    code: 'A' as const,
    method: 'secret_ballot' as ElectionVotingMethod,
    titleEn: 'Option A — Secret Ballot',
    titleHi: 'विकल्प A — गुप्त मतपत्र',
    effectEn:
      'Each eligible member casts a private ballot. Individual choices are not announced aloud. Suitable when members prefer privacy and reduced influence from open discussion during polling.',
    effectHi:
      'प्रत्येक पात्र सदस्य निजी मतपत्र डालता है। व्यक्तिगत पसंद खुले में घोषित नहीं होती। जब सदस्य मतदान के समय गोपनीयता चाहें तो उपयुक्त।',
  },
  show_of_hands: {
    code: 'B' as const,
    method: 'show_of_hands' as ElectionVotingMethod,
    titleEn: 'Option B — Show of Hands',
    titleHi: 'विकल्प B — हाथ उठाकर मतदान',
    effectEn:
      'Votes are indicated openly by show of hands (or equivalent open count). Results are visible to those present. Suitable when the meeting prefers transparency and immediate counting.',
    effectHi:
      'मत हाथ उठाकर (या समकक्ष खुली गणना से) दिखाये जाते हैं। उपस्थित सदस्यों को परिणाम तुरंत दिखते हैं। जब बैठक पारदर्शिता और तत्काल गणना चाहे तो उपयुक्त।',
  },
} as const;

export type VotingMethodConsentRow = {
  id: string;
  poll_id: string;
  member_id: string;
  choice: ElectionVotingMethod;
  member_name: string | null;
  flat_number: string | null;
  created_at: string;
};

export type VotingMethodConsentTally = {
  secret_ballot: number;
  show_of_hands: number;
  total: number;
};

export function leadingConsentMethod(tally: VotingMethodConsentTally): ElectionVotingMethod | null {
  if (tally.total < 1) return null;
  if (tally.secret_ballot === tally.show_of_hands) return null; // tie — admin must not auto-pick
  return tally.secret_ballot > tally.show_of_hands ? 'secret_ballot' : 'show_of_hands';
}

export async function openVotingMethodConsent(opts: {
  pollId: string;
  societyId: string;
  openedBy: string;
}): Promise<{ error: string | null }> {
  const { error } = await supabase
    .from('polls')
    .update({
      voting_method_consent_open: true,
      voting_method_consent_opened_at: new Date().toISOString(),
      voting_method_consent_opened_by: opts.openedBy,
    })
    .eq('id', opts.pollId)
    .is('voting_method', null);

  if (error) return { error: error.message };

  await logElectionAudit({
    societyId: opts.societyId,
    pollId: opts.pollId,
    eventType: 'voting_method_consent_opened',
    actorType: 'admin',
    actorName: opts.openedBy,
    payload: { options: ['secret_ballot', 'show_of_hands'] },
  });
  return { error: null };
}

export async function fetchVotingMethodConsents(pollId: string): Promise<{
  rows: VotingMethodConsentRow[];
  error: string | null;
}> {
  const { data, error } = await supabase
    .from('election_voting_method_consents')
    .select('id, poll_id, member_id, choice, member_name, flat_number, created_at')
    .eq('poll_id', pollId)
    .order('created_at', { ascending: true });

  if (error) return { rows: [], error: error.message };
  return {
    rows: (data ?? []).map((r) => ({
      ...r,
      choice: r.choice as ElectionVotingMethod,
    })),
    error: null,
  };
}

export function tallyFromConsents(rows: VotingMethodConsentRow[]): VotingMethodConsentTally {
  let secret_ballot = 0;
  let show_of_hands = 0;
  for (const r of rows) {
    if (r.choice === 'secret_ballot') secret_ballot += 1;
    else if (r.choice === 'show_of_hands') show_of_hands += 1;
  }
  return { secret_ballot, show_of_hands, total: rows.length };
}

export async function submitVotingMethodConsent(opts: {
  societyId: string;
  pollId: string;
  memberId: string;
  choice: ElectionVotingMethod;
  memberName?: string | null;
  flatNumber?: string | null;
}): Promise<{ error: string | null }> {
  const { error } = await supabase.from('election_voting_method_consents').insert([
    {
      society_id: opts.societyId,
      poll_id: opts.pollId,
      member_id: opts.memberId,
      choice: opts.choice,
      member_name: opts.memberName ?? null,
      flat_number: opts.flatNumber ?? null,
    },
  ]);

  if (error) {
    if (/duplicate|unique|immutable/i.test(error.message)) {
      return { error: 'You have already recorded your consent for this election.' };
    }
    return { error: error.message };
  }

  await logElectionAudit({
    societyId: opts.societyId,
    pollId: opts.pollId,
    eventType: 'voting_method_consent_cast',
    actorType: 'resident',
    actorId: opts.memberId,
    actorName: opts.memberName ?? null,
    payload: {
      choice: opts.choice,
      option: opts.choice === 'secret_ballot' ? 'A' : 'B',
    },
  });
  return { error: null };
}

/**
 * Finalize Option A or B after member consent.
 * Requires every eligible member counted in `eligibleMemberCount` to have consented
 * unless `allowPartial` is true (admin override with recorded reason).
 */
export async function finalizeVotingMethodFromConsent(opts: {
  pollId: string;
  societyId: string;
  method: ElectionVotingMethod;
  recordedBy: string;
  eligibleMemberCount: number;
  consentTotal: number;
  allowPartial?: boolean;
  separateOfficeVotes?: boolean;
}): Promise<{ error: string | null }> {
  if (!opts.allowPartial && opts.consentTotal < opts.eligibleMemberCount) {
    return {
      error: `Consent incomplete: ${opts.consentTotal} of ${opts.eligibleMemberCount} eligible members have consented. Wait for all members, or use admin override only if the meeting so resolves.`,
    };
  }

  const { error } = await recordElectionVotingMethod({
    pollId: opts.pollId,
    method: opts.method,
    recordedBy: opts.recordedBy,
    separateOfficeVotes: opts.separateOfficeVotes ?? false,
  });
  if (error) return { error };

  await supabase
    .from('polls')
    .update({ voting_method_consent_open: false })
    .eq('id', opts.pollId);

  await logElectionAudit({
    societyId: opts.societyId,
    pollId: opts.pollId,
    eventType: 'voting_method_finalized',
    actorType: 'admin',
    actorName: opts.recordedBy,
    payload: {
      method: opts.method,
      option: opts.method === 'secret_ballot' ? 'A' : 'B',
      consent_total: opts.consentTotal,
      eligible_member_count: opts.eligibleMemberCount,
      allow_partial: Boolean(opts.allowPartial),
    },
  });

  return { error: null };
}
