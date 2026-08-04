export type ElectionPost = 'president' | 'vice_president' | 'secretary' | 'treasurer' | 'committee';

export type PollOptionRow = {
  id: string;
  poll_id: string | null;
  option_text: string;
  election_post: string | null;
  member_id?: string | null;
  flat_id?: string | null;
  flat_number?: string | null;
  nominated_by?: string | null;
  nomination_statement?: string | null;
};

export type BallotRow = {
  rankings: Record<string, Record<string, number>> | null;
};

const THREE_POSTS: ElectionPost[] = ['president', 'secretary', 'treasurer'];
const LEGACY_EXTRA: ElectionPost[] = ['vice_president', 'committee'];

/** Borda-style points: rank 1 gets m points, rank m gets 1 point. */
function pointsForRank(rank: number, m: number): number {
  if (m <= 0 || rank < 1 || rank > m) return 0;
  return m - rank + 1;
}

function postsPresent(options: PollOptionRow[]): ElectionPost[] {
  const have = new Set(options.map((o) => o.election_post).filter(Boolean));
  const ordered: ElectionPost[] = [...THREE_POSTS, ...LEGACY_EXTRA];
  return ordered.filter((p) => have.has(p));
}

export function validateElectionRankings(
  options: PollOptionRow[],
  rankings: Record<string, Record<string, number>>,
  _committeeSeats?: number,
): string | null {
  const byPost = (post: string) => options.filter((o) => o.election_post === post);

  for (const post of postsPresent(options)) {
    const postOpts = byPost(post);
    if (postOpts.length === 0) continue;
    const m = postOpts.length;
    const rmap = rankings[post] ?? {};
    const usedRanks = new Set<number>();
    for (const o of postOpts) {
      const r = rmap[o.id];
      if (r === undefined || r === null) return `Assign a rank for every ${post} candidate`;
      const rank = Number(r);
      if (!Number.isInteger(rank) || rank < 1 || rank > m) return `Invalid rank for ${post}`;
      if (usedRanks.has(rank)) return `Duplicate rank ${rank} for ${post}`;
      usedRanks.add(rank);
    }
    if (usedRanks.size !== m) return `Complete all rankings for ${post}`;
  }

  return null;
}

export type ElectedWinner = { option_id: string; name: string; score: number; place?: number; from_post?: ElectionPost };

export type FormationMember = {
  key: string;
  name: string;
  flat_number?: string | null;
  flat_id?: string | null;
  member_id?: string | null;
  option_id?: string | null;
  from_post?: ElectionPost | null;
  place?: number | null;
  source: 'runner_up' | 'voluntary' | 'executive_proposed';
};

export type CommitteeFormationState = {
  selected_runner_up_ids: string[];
  voluntary: FormationMember[];
  executive_proposed: FormationMember[];
};

export type ElectionResultsPayload = {
  president: ElectedWinner | null;
  vice_president: ElectedWinner | null;
  secretary: ElectedWinner | null;
  treasurer: ElectedWinner | null;
  committee: ElectedWinner[];
  /** 2nd & 3rd place unelected candidates per executive post (eligible for committee). */
  runners_up?: Partial<Record<ElectionPost, ElectedWinner[]>>;
  vacant?: Partial<Record<ElectionPost, { reason: string; top_score: number; required: number }>>;
  formation?: CommitteeFormationState;
  tallied_at: string;
};

export function emptyFormationState(): CommitteeFormationState {
  return { selected_runner_up_ids: [], voluntary: [], executive_proposed: [] };
}

export function listRunnersUp(results: ElectionResultsPayload): ElectedWinner[] {
  const out: ElectedWinner[] = [];
  for (const post of THREE_POSTS) {
    for (const r of results.runners_up?.[post] ?? []) {
      out.push({ ...r, from_post: post });
    }
  }
  return out;
}

export function tallyElection(
  options: PollOptionRow[],
  ballots: BallotRow[],
  committeeSeats: number,
  winningVotes: Record<string, number> = {},
  runnerUpPlaces = 2,
): ElectionResultsPayload {
  const byPost = (post: string) => options.filter((o) => o.election_post === post);
  const scoreMap = (post: string) => {
    const postOpts = byPost(post);
    const m = postOpts.length;
    const scores = new Map<string, number>();
    for (const o of postOpts) scores.set(o.id, 0);
    if (m === 0) return scores;
    for (const b of ballots) {
      const rmap = b.rankings?.[post] ?? {};
      for (const o of postOpts) {
        const rank = Number(rmap[o.id]);
        scores.set(o.id, (scores.get(o.id) ?? 0) + pointsForRank(rank, m));
      }
    }
    return scores;
  };

  const vacant: ElectionResultsPayload['vacant'] = {};

  const rankedForPost = (post: ElectionPost): ElectedWinner[] => {
    const postOpts = byPost(post);
    if (postOpts.length === 0) return [];
    const scores = scoreMap(post);
    return [...postOpts]
      .sort((a, b) => (scores.get(b.id) ?? 0) - (scores.get(a.id) ?? 0))
      .map((o, i) => ({
        option_id: o.id,
        name: o.option_text,
        score: scores.get(o.id) ?? 0,
        place: i + 1,
        from_post: post,
      }));
  };

  const resolveWinner = (post: ElectionPost, ranked: ElectedWinner[]): ElectedWinner | null => {
    if (ranked.length === 0) return null;
    const best = ranked[0];
    const required = Number(winningVotes[post] ?? 0);
    if (Number.isFinite(required) && required > 0 && best.score < required) {
      vacant[post] = {
        reason: `Top score ${best.score} below required ${required}`,
        top_score: best.score,
        required,
      };
      return null;
    }
    return best;
  };

  const winners: Partial<Record<ElectionPost, ElectedWinner | null>> = {};
  const runners_up: NonNullable<ElectionResultsPayload['runners_up']> = {};
  for (const post of [...THREE_POSTS, 'vice_president' as ElectionPost]) {
    const ranked = rankedForPost(post);
    const winner = resolveWinner(post, ranked);
    winners[post] = winner;
    if (THREE_POSTS.includes(post)) {
      const unelected = ranked.filter((r) => !winner || r.option_id !== winner.option_id);
      const slice = unelected.slice(0, Math.max(0, runnerUpPlaces));
      if (slice.length > 0) runners_up[post] = slice;
    }
  }

  const committeeOpts = byPost('committee');
  const cScores = scoreMap('committee');
  const committeeSorted = [...committeeOpts].sort((a, b) => (cScores.get(b.id) ?? 0) - (cScores.get(a.id) ?? 0));
  const seats =
    committeeOpts.length === 0 ? 0 : Math.max(0, Math.min(committeeSeats, committeeSorted.length));
  const committee: ElectedWinner[] = committeeSorted.slice(0, seats).map((o, i) => ({
    option_id: o.id,
    name: o.option_text,
    score: cScores.get(o.id) ?? 0,
    place: i + 1,
    from_post: 'committee' as ElectionPost,
  }));

  return {
    president: winners.president ?? null,
    vice_president: winners.vice_president ?? null,
    secretary: winners.secretary ?? null,
    treasurer: winners.treasurer ?? null,
    committee,
    runners_up: Object.keys(runners_up).length ? runners_up : undefined,
    vacant: Object.keys(vacant).length ? vacant : undefined,
    formation: emptyFormationState(),
    tallied_at: new Date().toISOString(),
  };
}
