import { supabase } from '@/integrations/supabase/client';
import type {
  ElectionPost,
  ElectionResultsPayload,
  FormationMember,
  PollOptionRow,
} from '@/lib/electionTally';
import { listRunnersUp } from '@/lib/electionTally';
import { fetchMemberPhotoMap } from '@/lib/memberPhotos';

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

function formationInsert(
  societyId: string,
  pollId: string,
  term_from: string,
  term_to: string | null,
  sort: number,
  member: FormationMember,
  selection_type: string,
  opt?: PollOptionRow,
  photoByMemberId: Record<string, string> = {},
): Record<string, unknown> {
  const memberId = member.member_id ?? opt?.member_id ?? null;
  const photo = (memberId && photoByMemberId[memberId]) || null;
  return {
    society_id: societyId,
    flat_id: member.flat_id ?? opt?.flat_id ?? null,
    flat_number: member.flat_number ?? opt?.flat_number ?? null,
    flat_owner_name: opt?.option_text ?? member.name,
    name: member.name,
    position: 'Committee Member',
    photo,
    selection_type,
    term_from,
    term_to,
    sort_order: sort,
    is_active: true,
    source_poll_id: pollId,
    source_option_id: member.option_id ?? opt?.id ?? null,
  };
}

export async function applyElectionToCommittee(input: ApplyInput): Promise<{ ok: true } | { ok: false; error: string }> {
  const { societyId, pollId, results, options, termFrom, termTo } = input;
  const optById = new Map(options.map((o) => [o.id, o]));
  const term_from = termFrom || new Date().toISOString().slice(0, 10);
  const term_to = termTo || null;

  const memberIds = [
    ...options.map((o) => o.member_id).filter(Boolean),
    ...(results.formation?.voluntary ?? []).map((v) => v.member_id).filter(Boolean),
    ...(results.formation?.executive_proposed ?? []).map((e) => e.member_id).filter(Boolean),
  ] as string[];
  const photoByMemberId = await fetchMemberPhotoMap(memberIds);

  const inserts: Record<string, unknown>[] = [];
  let sort = 0;

  for (const post of EXEC_ORDER) {
    const winner = results[post as keyof ElectionResultsPayload];
    if (!winner || typeof winner !== 'object' || !('option_id' in winner)) continue;
    const w = winner as { option_id: string; name: string };
    const opt = optById.get(w.option_id);
    const mid = opt?.member_id ?? null;
    inserts.push({
      society_id: societyId,
      flat_id: opt?.flat_id ?? null,
      flat_number: opt?.flat_number ?? null,
      flat_owner_name: opt?.option_text ?? w.name,
      name: w.name,
      position: POST_TO_COMMITTEE_POSITION[post] ?? post,
      photo: (mid && photoByMemberId[mid]) || null,
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
    const mid = opt?.member_id ?? null;
    inserts.push({
      society_id: societyId,
      flat_id: opt?.flat_id ?? null,
      flat_number: opt?.flat_number ?? null,
      flat_owner_name: opt?.option_text ?? w.name,
      name: w.name,
      position: 'Committee Member',
      photo: (mid && photoByMemberId[mid]) || null,
      selection_type: 'elected',
      term_from,
      term_to,
      sort_order: sort++,
      is_active: true,
      source_poll_id: pollId,
      source_option_id: w.option_id,
    });
  }

  const formation = results.formation;
  const selectedIds = new Set(formation?.selected_runner_up_ids ?? []);
  const winnerIds = new Set(
    EXEC_ORDER.map((p) => {
      const w = results[p as keyof ElectionResultsPayload];
      return w && typeof w === 'object' && 'option_id' in w ? (w as { option_id: string }).option_id : null;
    }).filter(Boolean) as string[],
  );

  for (const runner of listRunnersUp(results)) {
    if (!selectedIds.has(runner.option_id)) continue;
    if (winnerIds.has(runner.option_id)) continue;
    const opt = optById.get(runner.option_id);
    inserts.push(
      formationInsert(
        societyId,
        pollId,
        term_from,
        term_to,
        sort++,
        {
          key: runner.option_id,
          name: runner.name,
          option_id: runner.option_id,
          from_post: runner.from_post ?? null,
          place: runner.place ?? null,
          source: 'runner_up',
          flat_id: opt?.flat_id,
          flat_number: opt?.flat_number,
          member_id: opt?.member_id ?? null,
        },
        'runner_up',
        opt,
        photoByMemberId,
      ),
    );
  }

  for (const v of formation?.voluntary ?? []) {
    inserts.push(formationInsert(societyId, pollId, term_from, term_to, sort++, v, 'voluntary', undefined, photoByMemberId));
  }

  for (const e of formation?.executive_proposed ?? []) {
    inserts.push(
      formationInsert(societyId, pollId, term_from, term_to, sort++, e, 'executive_proposed', undefined, photoByMemberId),
    );
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

export function countFormedCommittee(results: ElectionResultsPayload): number {
  let n = 0;
  for (const post of EXEC_ORDER) {
    const w = results[post as keyof ElectionResultsPayload];
    if (w && typeof w === 'object' && 'option_id' in w) n += 1;
  }
  n += results.committee?.length ?? 0;
  const formation = results.formation;
  if (formation) {
    n += formation.selected_runner_up_ids?.length ?? 0;
    n += formation.voluntary?.length ?? 0;
    n += formation.executive_proposed?.length ?? 0;
  }
  return n;
}
