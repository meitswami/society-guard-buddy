import { supabase } from '@/integrations/supabase/client';
import { KioskAbortError } from './kioskSpeech';

export type KioskApprovalOutcome = 'approved' | 'rejected' | 'timeout' | 'no_flat';

/**
 * Same request the guard's "Ask permission" button sends (approval_requests row +
 * realtime wait), without the modal UI.
 */
export async function requestResidentApproval(opts: {
  societyId: string;
  flatNumber: string;
  visitorName: string;
  visitorPhone: string;
  purpose: string;
  guardId: string;
  guardName: string;
  timeoutSec?: number;
  signal?: AbortSignal;
  onTick?: (secondsLeft: number) => void;
}): Promise<KioskApprovalOutcome> {
  const { data: flat } = await supabase
    .from('flats')
    .select('id')
    .eq('flat_number', opts.flatNumber)
    .eq('society_id', opts.societyId)
    .maybeSingle();
  if (!flat) return 'no_flat';

  const { data: request, error } = await supabase
    .from('approval_requests')
    .insert({
      visitor_name: opts.visitorName,
      visitor_phone: opts.visitorPhone || null,
      flat_number: opts.flatNumber,
      flat_id: flat.id,
      guard_id: opts.guardId,
      guard_name: opts.guardName,
      purpose: opts.purpose || null,
      status: 'pending',
    })
    .select()
    .single();
  if (error || !request) return 'no_flat';

  const timeoutSec = opts.timeoutSec ?? 120;
  return new Promise<KioskApprovalOutcome>((resolve, reject) => {
    let left = timeoutSec;
    let settled = false;
    const channel = supabase
      .channel(`kiosk-approval-${request.id}`)
      .on(
        'postgres_changes',
        { event: 'UPDATE', schema: 'public', table: 'approval_requests', filter: `id=eq.${request.id}` },
        (payload) => {
          const status = (payload.new as { status?: string }).status;
          if (status === 'approved' || status === 'rejected') finish(status);
        },
      )
      .subscribe();

    // Poll as well, in case the realtime socket is slow on mobile data.
    const poll = setInterval(async () => {
      const { data } = await supabase.from('approval_requests').select('status').eq('id', request.id).maybeSingle();
      if (data?.status === 'approved' || data?.status === 'rejected') finish(data.status);
    }, 5000);

    const tick = setInterval(() => {
      left -= 1;
      opts.onTick?.(left);
      if (left <= 0) finish('timeout');
    }, 1000);
    opts.onTick?.(left);

    const onAbort = () => finish(null);
    opts.signal?.addEventListener('abort', onAbort, { once: true });

    function finish(outcome: KioskApprovalOutcome | null) {
      if (settled) return;
      settled = true;
      clearInterval(poll);
      clearInterval(tick);
      opts.signal?.removeEventListener('abort', onAbort);
      void supabase.removeChannel(channel);
      if (outcome) resolve(outcome);
      else reject(new KioskAbortError());
    }
  });
}
