import { supabase } from '@/integrations/supabase/client';
import { BYE_LAW } from '@/lib/electionGovernance';

export type ElectionEligibilityReason =
  | 'member_not_found'
  | 'member_left'
  | 'removal_disqualification'
  | 'wrong_society'
  | 'not_designated_joint_voter'
  | 'maintenance_arrears_over_60_days'
  | string;

export type ElectionEligibility = {
  eligible: boolean;
  reasons: ElectionEligibilityReason[];
  arrears: boolean;
  is_designated_voter: boolean;
  member_id?: string;
  flat_id?: string | null;
  as_of?: string;
  arrears_days?: number;
};

export function eligibilityReasonLabel(reason: ElectionEligibilityReason): string {
  switch (reason) {
    case 'member_not_found':
      return 'Member record not found';
    case 'member_left':
      return 'Member has left the Society';
    case 'removal_disqualification':
      return 'Disqualified after committee removal (Special Resolution)';
    case 'wrong_society':
      return 'Member does not belong to this Society';
    case 'not_designated_joint_voter':
      return 'Not the designated voter for joint ownership';
    case 'maintenance_arrears_over_60_days':
      return `Maintenance/common-expense arrears exceed ${BYE_LAW.arrearsDisqualifyDays} days`;
    default:
      return reason;
  }
}

/** Call DB bye-law eligibility function (arrears, designated voter, disqualification). */
export async function fetchMemberElectionEligibility(opts: {
  memberId: string;
  societyId: string;
  asOf?: string; // YYYY-MM-DD
  arrearsDays?: number;
}): Promise<{ data: ElectionEligibility | null; error: string | null }> {
  const { data, error } = await supabase.rpc('member_election_eligibility', {
    p_member_id: opts.memberId,
    p_society_id: opts.societyId,
    p_as_of: opts.asOf ?? new Date().toISOString().slice(0, 10),
    p_arrears_days: opts.arrearsDays ?? BYE_LAW.arrearsDisqualifyDays,
  });

  if (error) return { data: null, error: error.message };

  const raw = (data ?? {}) as Record<string, unknown>;
  const reasonsRaw = raw.reasons;
  const reasons = Array.isArray(reasonsRaw)
    ? (reasonsRaw as ElectionEligibilityReason[])
    : [];

  return {
    data: {
      eligible: Boolean(raw.eligible),
      reasons,
      arrears: Boolean(raw.arrears),
      is_designated_voter: raw.is_designated_voter !== false,
      member_id: typeof raw.member_id === 'string' ? raw.member_id : opts.memberId,
      flat_id: (raw.flat_id as string | null | undefined) ?? null,
      as_of: typeof raw.as_of === 'string' ? raw.as_of : undefined,
      arrears_days: typeof raw.arrears_days === 'number' ? raw.arrears_days : undefined,
    },
    error: null,
  };
}
