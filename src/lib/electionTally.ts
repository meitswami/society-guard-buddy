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

export type ElectedWinner = { option_id: string; name: string; score: number };

export type ElectionResultsPayload = {
  president: ElectedWinner | null;
  vice_president: ElectedWinner | null;
  secretary: ElectedWinner | null;
  treasurer: ElectedWinner | null;
  committee: ElectedWinner[];
  vacant?: Partial<Record<ElectionPost, { reason: string; top_score: number; required: number }>>;
  tallied_at: string;
};

export function tallyElection(
  options: PollOptionRow[],
  ballots: BallotRow[],
  committeeSeats: number,
  winningVotes: Record<string, number> = {},
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

  const pickWinner = (post: ElectionPost): ElectedWinner | null => {
    const postOpts = byPost(post);
    if (postOpts.length === 0) return null;
    const scores = scoreMap(post);
    let best: PollOptionRow | null = null;
    let bestScore = -1;
    for (const o of postOpts) {
      const s = scores.get(o.id) ?? 0;
      if (s > bestScore) {
        bestScore = s;
        best = o;
      }
    }
    if (!best) return null;
    const required = Number(winningVotes[post] ?? 0);
    if (Number.isFinite(required) && required > 0 && bestScore < required) {
      vacant[post] = {
        reason: `Top score ${bestScore} below required ${required}`,
        top_score: bestScore,
        required,
      };
      return null;
    }
    return { option_id: best.id, name: best.option_text, score: bestScore };
  };

  const committeeOpts = byPost('committee');
  const cScores = scoreMap('committee');
  const committeeSorted = [...committeeOpts].sort((a, b) => (cScores.get(b.id) ?? 0) - (cScores.get(a.id) ?? 0));
  const seats =
    committeeOpts.length === 0 ? 0 : Math.max(0, Math.min(committeeSeats, committeeSorted.length));
  const committee: ElectedWinner[] = committeeSorted.slice(0, seats).map((o) => ({
    option_id: o.id,
    name: o.option_text,
    score: cScores.get(o.id) ?? 0,
  }));

  return {
    president: pickWinner('president'),
    vice_president: pickWinner('vice_president'),
    secretary: pickWinner('secretary'),
    treasurer: pickWinner('treasurer'),
    committee,
    vacant: Object.keys(vacant).length ? vacant : undefined,
    tallied_at: new Date().toISOString(),
  };
}
