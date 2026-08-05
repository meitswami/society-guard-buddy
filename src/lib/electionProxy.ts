import { supabase } from '@/integrations/supabase/client';
import { BYE_LAW } from '@/lib/electionGovernance';
import { logElectionAudit } from '@/lib/electionAudit';

export type ElectionProxyStatus = 'pending' | 'approved' | 'rejected' | 'revoked';

export type ElectionProxyRow = {
  id: string;
  society_id: string;
  poll_id: string;
  principal_member_id: string;
  proxy_holder_member_id: string;
  authorization_document_url: string | null;
  authorization_notes: string | null;
  submitted_at: string;
  submitted_by: string | null;
  meeting_at: string | null;
  status: ElectionProxyStatus;
  reviewed_by: string | null;
  reviewed_at: string | null;
  rejection_reason: string | null;
};

/** Hours remaining until proxy submission deadline (meeting − 48h). */
export function proxyDeadlineIso(meetingAtIso: string, hours = BYE_LAW.proxyDeadlineHours): string {
  const d = new Date(meetingAtIso);
  d.setHours(d.getHours() - hours);
  return d.toISOString();
}

export function isProxySubmissionOnTime(submittedAt: Date, meetingAt: Date): boolean {
  const deadline = new Date(meetingAt);
  deadline.setHours(deadline.getHours() - BYE_LAW.proxyDeadlineHours);
  return submittedAt.getTime() <= deadline.getTime();
}

export async function submitElectionProxy(opts: {
  societyId: string;
  pollId: string;
  principalMemberId: string;
  proxyHolderMemberId: string;
  meetingAt?: string | null;
  authorizationDocumentUrl?: string | null;
  authorizationNotes?: string | null;
  submittedBy?: string | null;
}): Promise<{ data: ElectionProxyRow | null; error: string | null }> {
  if (opts.principalMemberId === opts.proxyHolderMemberId) {
    return { data: null, error: 'A member cannot act as their own proxy.' };
  }

  const { data, error } = await supabase
    .from('election_proxies')
    .insert([
      {
        society_id: opts.societyId,
        poll_id: opts.pollId,
        principal_member_id: opts.principalMemberId,
        proxy_holder_member_id: opts.proxyHolderMemberId,
        meeting_at: opts.meetingAt ?? null,
        authorization_document_url: opts.authorizationDocumentUrl ?? null,
        authorization_notes: opts.authorizationNotes ?? null,
        submitted_by: opts.submittedBy ?? null,
        status: 'pending',
      },
    ])
    .select()
    .single();

  if (error) return { data: null, error: error.message };

  await logElectionAudit({
    societyId: opts.societyId,
    pollId: opts.pollId,
    eventType: 'proxy_submitted',
    actorType: 'resident',
    actorId: opts.principalMemberId,
    actorName: opts.submittedBy ?? null,
    payload: {
      proxy_id: data.id,
      proxy_holder_member_id: opts.proxyHolderMemberId,
    },
  });

  return { data: data as ElectionProxyRow, error: null };
}

export async function reviewElectionProxy(opts: {
  proxyId: string;
  societyId: string;
  pollId: string;
  status: 'approved' | 'rejected' | 'revoked';
  reviewedBy: string;
  rejectionReason?: string | null;
}): Promise<{ error: string | null }> {
  const { error } = await supabase
    .from('election_proxies')
    .update({
      status: opts.status,
      reviewed_by: opts.reviewedBy,
      reviewed_at: new Date().toISOString(),
      rejection_reason: opts.rejectionReason ?? null,
    })
    .eq('id', opts.proxyId);

  if (error) return { error: error.message };

  await logElectionAudit({
    societyId: opts.societyId,
    pollId: opts.pollId,
    eventType:
      opts.status === 'approved'
        ? 'proxy_approved'
        : opts.status === 'revoked'
          ? 'proxy_revoked'
          : 'proxy_rejected',
    actorType: 'admin',
    actorName: opts.reviewedBy,
    payload: { proxy_id: opts.proxyId, status: opts.status, rejection_reason: opts.rejectionReason },
  });

  return { error: null };
}
