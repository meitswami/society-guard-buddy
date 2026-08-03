import { supabase } from '@/integrations/supabase/client';
import type { ElectionPost, ElectionResultsPayload, PollOptionRow } from '@/lib/electionTally';

const POST_TO_COMMITTEE_POSITION: Record<string, string> = {
  president: 'President',
  vice_president: 'Vice-President',
  secretary: 'Secretary',
  treasurer: 'Treasurer',
  committee: 'Committee Member',
};

const EXEC_ORDER: ElectionPost[] = ['president', 'secretary', 'treasurer', 'vice_president'];

type ApplyInput = {
  societyId: string;
  pollId: string;
  results: ElectionResultsPayload;
  options: PollOptionRow[];
  termFrom: string | null;
  termTo: string | null;
};

export async function applyElectionToCommittee(input: ApplyInput): Promise<{ ok: true } | { ok: false; error: string }> {
  const { societyId, pollId, results, options, termFrom, termTo } = input;
  const optById = new Map(options.map((o) => [o.id, o]));
  const term_from = termFrom || new Date().toISOString().slice(0, 10);
  const term_to = termTo || null;

  const inserts: Record<string, unknown>[] = [];
  let sort = 0;

  for (const post of EXEC_ORDER) {
    const winner = results[post as keyof ElectionResultsPayload];
    if (!winner || typeof winner !== 'object' || !('option_id' in winner)) continue;
    const w = winner as { option_id: string; name: string };
    const opt = optById.get(w.option_id);
    inserts.push({
      society_id: societyId,
      flat_id: opt?.flat_id ?? null,
      flat_number: opt?.flat_number ?? null,
      flat_owner_name: opt?.option_text ?? w.name,
      name: w.name,
      position: POST_TO_COMMITTEE_POSITION[post] ?? post,
      selection_type: 'elected',
      term_from,
      term_to,
      sort_order: sort++,
      is_active: true,
      source_poll_id: pollId,
      source_option_id: w.option_id,
    });
  }

  for (const w of results.committee ?? []) {
    const opt = optById.get(w.option_id);
    inserts.push({
      society_id: societyId,
      flat_id: opt?.flat_id ?? null,
      flat_number: opt?.flat_number ?? null,
      flat_owner_name: opt?.option_text ?? w.name,
      name: w.name,
      position: 'Committee Member',
      selection_type: 'elected',
      term_from,
      term_to,
      sort_order: sort++,
      is_active: true,
      source_poll_id: pollId,
      source_option_id: w.option_id,
    });
  }

  if (inserts.length === 0) {
    return { ok: false, error: 'No winners to publish.' };
  }

  const { error: insErr } = await supabase.from('committee_members').insert(inserts);
  if (insErr) return { ok: false, error: insErr.message };

  const { error: pollErr } = await supabase
    .from('polls')
    .update({
      election_phase: 'applied',
      election_applied_at: new Date().toISOString(),
    })
    .eq('id', pollId);

  if (pollErr) return { ok: false, error: pollErr.message };

  return { ok: true };
}
