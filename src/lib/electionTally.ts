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

/**
 * Bye-law ballot payload (non-ranked).
 * - Combined (default): `{ selected: optionId[] }` — mark up to committeeSize nominees.
 * - Separate office (expressly approved): `{ [post]: optionId }` and `{ committee: optionId[] }`.
 */
export type BallotChoices = {
  selected?: string[];
  president?: string;
  vice_president?: string;
  secretary?: string;
  treasurer?: string;
  committee?: string | string[];
};

export type BallotRow = {
  choices?: BallotChoices | Record<string, unknown> | null;
  /** @deprecated Legacy ranked/Borda ballots only. */
  rankings?: Record<string, Record<string, number>> | null;
};

const OFFICE_POSTS: ElectionPost[] = ['president', 'vice_president', 'secretary', 'treasurer'];
const ALL_POSTS: ElectionPost[] = [...OFFICE_POSTS, 'committee'];

function asStringArray(v: unknown): string[] {
  if (Array.isArray(v)) return v.filter((x): x is string => typeof x === 'string' && x.length > 0);
  if (typeof v === 'string' && v.length > 0) return [v];
  return [];
}

function normalizeChoices(raw: BallotRow['choices']): BallotChoices {
  if (!raw || typeof raw !== 'object') return {};
  const c = raw as BallotChoices;
  return {
    selected: asStringArray(c.selected),
    president: typeof c.president === 'string' ? c.president : undefined,
    vice_president: typeof c.vice_president === 'string' ? c.vice_president : undefined,
    secretary: typeof c.secretary === 'string' ? c.secretary : undefined,
    treasurer: typeof c.treasurer === 'string' ? c.treasurer : undefined,
    committee: asStringArray(c.committee),
  };
}

function postsPresent(options: PollOptionRow[]): ElectionPost[] {
  const have = new Set(options.map((o) => o.election_post).filter(Boolean));
  return ALL_POSTS.filter((p) => have.has(p));
}

/** Validate one-member ballot choices (plurality / limited vote — never ranked). */
export function validateElectionChoices(
  options: PollOptionRow[],
  choicesRaw: BallotChoices,
  separateOfficeVotes: boolean,
  opts?: { committeeSeats?: number; maxMarks?: number },
): string | null {
  const committeeSeats = opts?.committeeSeats ?? 3;
  const maxMarks = opts?.maxMarks ?? 7;
  const choices = normalizeChoices(choicesRaw);
  const byId = new Map(options.map((o) => [o.id, o]));
  const openPosts = postsPresent(options);

  if (separateOfficeVotes) {
    for (const post of openPosts) {
      if (post === 'committee') {
        const picks = asStringArray(choices.committee);
        if (picks.length === 0 && options.some((o) => o.election_post === 'committee')) {
          return 'Select Executive Member candidate(s)';
        }
        if (picks.length > committeeSeats) {
          return `Select at most ${committeeSeats} Executive Member(s)`;
        }
        const seen = new Set<string>();
        for (const id of picks) {
          const opt = byId.get(id);
          if (!opt || opt.election_post !== 'committee') return 'Invalid Executive Member selection';
          if (seen.has(id)) return 'Duplicate Executive Member selection';
          seen.add(id);
        }
        continue;
      }
      const pick = choices[post];
      if (!pick) return `Select one candidate for ${post.replace('_', ' ')}`;
      const opt = byId.get(pick);
      if (!opt || opt.election_post !== post) return `Invalid selection for ${post.replace('_', ' ')}`;
    }
    return null;
  }

  const selected = asStringArray(choices.selected);
  if (selected.length === 0) return 'Select at least one nominee on your ballot';
  if (selected.length > maxMarks) return `Select at most ${maxMarks} nominees (one vote per member)`;
  const seen = new Set<string>();
  for (const id of selected) {
    if (!byId.has(id)) return 'Invalid nominee on ballot';
    if (seen.has(id)) return 'Duplicate selection on ballot';
    seen.add(id);
  }
  return null;
}

/** @deprecated Use validateElectionChoices. */
export function validateElectionRankings(
  options: PollOptionRow[],
  rankings: Record<string, Record<string, number>>,
  _committeeSeats?: number,
): string | null {
  void rankings;
  void _committeeSeats;
  if (options.length === 0) return 'No candidates';
  return 'Ranked ballots are no longer used. Refresh and cast a simple ballot.';
}

export type ElectedWinner = {
  option_id: string;
  name: string;
  score: number;
  place?: number;
  from_post?: ElectionPost;
};

export type FormationMember = {
  key: string;
  name: string;
  flat_number?: string | null;
  flat_id?: string | null;
  member_id?: string | null;
  option_id?: string | null;
  from_post?: ElectionPost | null;
  place?: number | null;
  source: 'voluntary' | 'executive_proposed' | 'runner_up';
};

export type CommitteeFormationState = {
  /** @deprecated Not used for new elections (bye-laws forbid auto-seating runners-up). */
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
  /** Legacy only — never populated for new tallies. */
  runners_up?: Partial<Record<ElectionPost, ElectedWinner[]>>;
  vacant?: Partial<Record<ElectionPost, { reason: string; top_score: number; required: number }>>;
  formation?: CommitteeFormationState;
  tallied_at: string;
  ballot_mode?: 'combined' | 'separate_office' | 'ranked_legacy';
};

export function emptyFormationState(): CommitteeFormationState {
  return { selected_runner_up_ids: [], voluntary: [], executive_proposed: [] };
}

/** Legacy helper — returns [] for new tallies (runners_up never written). */
export function listRunnersUp(results: ElectionResultsPayload): ElectedWinner[] {
  const out: ElectedWinner[] = [];
  for (const post of OFFICE_POSTS) {
    for (const r of results.runners_up?.[post] ?? []) {
      out.push({ ...r, from_post: post });
    }
  }
  return out;
}

function scoreMapFromBallots(
  optionIds: string[],
  ballots: BallotRow[],
  markFor: (choices: BallotChoices, optionId: string) => boolean,
): Map<string, number> {
  const scores = new Map<string, number>();
  for (const id of optionIds) scores.set(id, 0);
  for (const b of ballots) {
    const choices = normalizeChoices(b.choices);
    for (const id of optionIds) {
      if (markFor(choices, id)) scores.set(id, (scores.get(id) ?? 0) + 1);
    }
  }
  return scores;
}

/** Legacy ranked → one vote for rank-1 only (migration path). */
function legacyRankOneScores(post: string, optionIds: string[], ballots: BallotRow[]): Map<string, number> {
  const scores = new Map<string, number>();
  for (const id of optionIds) scores.set(id, 0);
  for (const b of ballots) {
    if (b.choices && typeof b.choices === 'object' && Object.keys(normalizeChoices(b.choices)).some((k) => {
      const v = (normalizeChoices(b.choices) as Record<string, unknown>)[k];
      return Array.isArray(v) ? v.length > 0 : !!v;
    })) {
      continue;
    }
    const rmap = b.rankings?.[post] ?? {};
    for (const id of optionIds) {
      if (Number(rmap[id]) === 1) scores.set(id, (scores.get(id) ?? 0) + 1);
    }
  }
  return scores;
}

function rankedList(
  postOpts: PollOptionRow[],
  scores: Map<string, number>,
  fromPost: ElectionPost,
): ElectedWinner[] {
  return [...postOpts]
    .sort((a, b) => (scores.get(b.id) ?? 0) - (scores.get(a.id) ?? 0))
    .map((o, i) => ({
      option_id: o.id,
      name: o.option_text,
      score: scores.get(o.id) ?? 0,
      place: i + 1,
      from_post: fromPost,
    }));
}

export type TallyElectionOptions = {
  separateOfficeVotes?: boolean;
  committeeSeats?: number;
  /** @deprecated Ignored — runners-up are never auto-collected. */
  runnerUpPlaces?: number;
  /** @deprecated Ignored — Borda thresholds removed. */
  winningVotes?: Record<string, number>;
};

/**
 * Plurality / limited-vote tally from `choices`.
 * Does not auto-seat 2nd/3rd place. Does not use Borda ranking.
 */
export function tallyElection(
  options: PollOptionRow[],
  ballots: BallotRow[],
  committeeSeatsOrOpts: number | TallyElectionOptions = 3,
  winningVotesLegacy: Record<string, number> = {},
  runnerUpPlacesLegacy = 0,
): ElectionResultsPayload {
  const opts: TallyElectionOptions =
    typeof committeeSeatsOrOpts === 'number'
      ? {
          committeeSeats: committeeSeatsOrOpts,
          winningVotes: winningVotesLegacy,
          runnerUpPlaces: runnerUpPlacesLegacy,
        }
      : committeeSeatsOrOpts;

  const separate = Boolean(opts.separateOfficeVotes);
  const committeeSeats = Math.max(0, opts.committeeSeats ?? 3);
  const byPost = (post: string) => options.filter((o) => o.election_post === post);

  const hasAnyChoices = ballots.some((b) => {
    const c = normalizeChoices(b.choices);
    return (
      asStringArray(c.selected).length > 0 ||
      OFFICE_POSTS.some((p) => !!c[p]) ||
      asStringArray(c.committee).length > 0
    );
  });

  const ballotMode: ElectionResultsPayload['ballot_mode'] = hasAnyChoices
    ? separate
      ? 'separate_office'
      : 'combined'
    : 'ranked_legacy';

  const winners: Partial<Record<ElectionPost, ElectedWinner | null>> = {};

  if (separate || ballotMode === 'ranked_legacy') {
    for (const post of OFFICE_POSTS) {
      const postOpts = byPost(post);
      if (postOpts.length === 0) {
        winners[post] = null;
        continue;
      }
      const ids = postOpts.map((o) => o.id);
      const scores = hasAnyChoices
        ? scoreMapFromBallots(ids, ballots, (c, id) => c[post] === id)
        : legacyRankOneScores(post, ids, ballots);
      const ranked = rankedList(postOpts, scores, post);
      winners[post] = ranked[0] ?? null;
    }

    const committeeOpts = byPost('committee');
    const cIds = committeeOpts.map((o) => o.id);
    const cScores = hasAnyChoices
      ? scoreMapFromBallots(cIds, ballots, (c, id) => asStringArray(c.committee).includes(id))
      : legacyRankOneScores('committee', cIds, ballots);
    const committeeSorted = rankedList(committeeOpts, cScores, 'committee');
    const seats = Math.min(committeeSeats, committeeSorted.length);

    return {
      president: winners.president ?? null,
      vice_president: winners.vice_president ?? null,
      secretary: winners.secretary ?? null,
      treasurer: winners.treasurer ?? null,
      committee: committeeSorted.slice(0, seats),
      formation: emptyFormationState(),
      tallied_at: new Date().toISOString(),
      ballot_mode: ballotMode,
    };
  }

  // Combined: each marked nominee gets one mark; seat by nominated post.
  const allIds = options.map((o) => o.id);
  const scores = scoreMapFromBallots(allIds, ballots, (c, id) => asStringArray(c.selected).includes(id));

  for (const post of OFFICE_POSTS) {
    const postOpts = byPost(post);
    if (postOpts.length === 0) {
      winners[post] = null;
      continue;
    }
    winners[post] = rankedList(postOpts, scores, post)[0] ?? null;
  }

  const committeeOpts = byPost('committee');
  const committeeSorted = rankedList(committeeOpts, scores, 'committee');
  const seats = Math.min(committeeSeats, committeeSorted.length);

  return {
    president: winners.president ?? null,
    vice_president: winners.vice_president ?? null,
    secretary: winners.secretary ?? null,
    treasurer: winners.treasurer ?? null,
    committee: committeeSorted.slice(0, seats),
    formation: emptyFormationState(),
    tallied_at: new Date().toISOString(),
    ballot_mode: 'combined',
  };
}
