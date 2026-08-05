import type { ElectionPost } from '@/lib/electionTally';

export type ElectionPhase = 'nomination' | 'voting' | 'closed' | 'applied';

export type ElectionVotingMethod = 'secret_ballot' | 'show_of_hands';

export type ElectionPollRow = {
  id: string;
  is_active: boolean;
  election_phase?: string | null;
  nomination_starts_at?: string | null;
  nomination_ends_at?: string | null;
  voting_starts_at?: string | null;
  voting_ends_at?: string | null;
  election_applied_at?: string | null;
  open_posts?: Record<string, boolean> | null;
  winning_votes?: Record<string, number> | null;
  voting_method?: ElectionVotingMethod | string | null;
};

/**
 * Registered bye-laws — controlling source for the Election Module.
 * Do not use generic apartment-election assumptions where they conflict.
 */
export const BYE_LAW = {
  /** Society apartment count used for quorum examples (30-flat configuration). */
  apartments: 30,
  /** Fixed Management Committee size. */
  committeeSize: 7,
  president: 1,
  vicePresident: 1,
  secretary: 1,
  treasurer: 1,
  executiveMembers: 3,
  /** Management Committee term in years. */
  termYears: 2,
  /** Re-election of retiring members is permitted. */
  reElectionPermitted: true,
  /** One voting right per society member (not per apartment). */
  votesPerMember: 1,
  /** Proxy authorization must be submitted this many hours before the meeting. */
  proxyDeadlineHours: 48,
  /** One person may not act as proxy for more than this many members. */
  maxProxiesPerPerson: 1,
  /** Election quorum as a fraction of members (3/4). */
  electionQuorumNumerator: 3,
  electionQuorumDenominator: 4,
  /** For 30 members: ceil(30 * 3/4) = 23. */
  electionQuorumFor30: 23,
  /** Maintenance/common-expense arrears exceeding this many days disqualify voting & contesting. */
  arrearsDisqualifyDays: 60,
  /** Ordinary MC meeting quorum: 2/3 of seven = five. */
  mcMeetingQuorumNumerator: 2,
  mcMeetingQuorumDenominator: 3,
  mcMeetingQuorumOfSeven: 5,
  /** Seven clear days' notice for regular MC meetings. */
  regularMeetingNoticeClearDays: 7,
  /** First MC meeting within this many days of election. */
  firstMeetingWithinDays: 30,
  /** Removal by Special Resolution disqualifies for this many years. */
  removalDisqualificationYears: 2,
  /** Voting methods permitted by bye-laws (must be recorded before polling). */
  votingMethods: ['secret_ballot', 'show_of_hands'] as const,
} as const;

/** Minimum members that must be represented for election quorum. */
export function electionQuorumRequired(memberCount: number): number {
  return Math.ceil(
    (memberCount * BYE_LAW.electionQuorumNumerator) / BYE_LAW.electionQuorumDenominator,
  );
}

/** Ordinary Management Committee meeting quorum (2/3 of roster size). */
export function mcMeetingQuorumRequired(committeeSize = BYE_LAW.committeeSize): number {
  return Math.ceil(
    (committeeSize * BYE_LAW.mcMeetingQuorumNumerator) / BYE_LAW.mcMeetingQuorumDenominator,
  );
}

/**
 * Seven Management Committee seats under the bye-laws:
 * President, Vice-President, Secretary, Treasurer, 3 Executive Members.
 */
export const MANAGEMENT_COMMITTEE_POSTS: ElectionPost[] = [
  'president',
  'vice_president',
  'secretary',
  'treasurer',
  'committee',
];

/** @deprecated Prefer MANAGEMENT_COMMITTEE_POSTS (bye-law 7-seat MC). */
export const THREE_EXECUTIVE_POSTS: ElectionPost[] = ['president', 'secretary', 'treasurer'];

/** Fixed Managing Committee size (bye-laws). */
export const MIN_COMMITTEE_SIZE = BYE_LAW.committeeSize;

/** Target equals fixed size — no target-15 formation. */
export const DEFAULT_TARGET_COMMITTEE_SIZE = BYE_LAW.committeeSize;

/** Fixed committee size alias. */
export const FIXED_COMMITTEE_SIZE = BYE_LAW.committeeSize;

/**
 * Bye-laws do not auto-seat 2nd/3rd place. Kept at 0 for new elections.
 * Legacy polls may still carry runner-up data in `election_results`.
 */
export const RUNNER_UP_PLACES = 0;

/** Default term length in years when creating an election. */
export const DEFAULT_TERM_YEARS = BYE_LAW.termYears;

/** All posts that may appear on legacy elections. */
export const ALL_ELECTION_POSTS: ElectionPost[] = [
  'president',
  'vice_president',
  'secretary',
  'treasurer',
  'committee',
];

/** @deprecated Prefer MANAGEMENT_COMMITTEE_POSTS for new elections. */
export const EXECUTIVE_POSTS: ElectionPost[] = MANAGEMENT_COMMITTEE_POSTS;

export const DEFAULT_OPEN_POSTS: Record<ElectionPost, boolean> = {
  president: true,
  vice_president: true,
  secretary: true,
  treasurer: true,
  committee: true,
};

export const DEFAULT_WINNING_VOTES: Record<string, number> = {
  president: 0,
  vice_president: 0,
  secretary: 0,
  treasurer: 0,
  committee: 0,
};

export const POST_DISPLAY: Record<ElectionPost, string> = {
  president: 'President',
  vice_president: 'Vice-President',
  secretary: 'Secretary',
  treasurer: 'Treasurer',
  committee: 'Executive Member',
};

export const POST_DISPLAY_HI: Record<ElectionPost, string> = {
  president: 'अध्यक्ष',
  vice_president: 'उपाध्यक्ष',
  secretary: 'सचिव',
  treasurer: 'कोषाध्यक्ष',
  committee: 'कार्यकारिणी सदस्य',
};

export function electionPhase(poll: ElectionPollRow): ElectionPhase {
  const p = poll.election_phase as ElectionPhase | undefined;
  if (p === 'nomination' || p === 'voting' || p === 'closed' || p === 'applied') return p;
  if (!poll.is_active && poll.election_applied_at) return 'applied';
  if (!poll.is_active) return 'closed';
  return 'voting';
}

function inWindow(startsAt: string | null | undefined, endsAt: string | null | undefined, now: number): boolean {
  const start = startsAt ? new Date(startsAt).getTime() : 0;
  const end = endsAt ? new Date(endsAt).getTime() : Number.MAX_SAFE_INTEGER;
  return now >= start && now <= end;
}

export function isNominationWindowOpen(poll: ElectionPollRow, now = Date.now()): boolean {
  if (electionPhase(poll) !== 'nomination' || !poll.is_active) return false;
  return inWindow(poll.nomination_starts_at, poll.nomination_ends_at, now);
}

export function isPostOpenForNomination(poll: ElectionPollRow, post: ElectionPost): boolean {
  if (!isNominationWindowOpen(poll)) return false;
  const open = poll.open_posts ?? DEFAULT_OPEN_POSTS;
  return open[post] !== false;
}

export function isVotingWindowOpen(poll: ElectionPollRow, now = Date.now()): boolean {
  if (electionPhase(poll) !== 'voting' || !poll.is_active) return false;
  return inWindow(poll.voting_starts_at, poll.voting_ends_at, now);
}

function windowLabel(startsAt: string | null | undefined, endsAt: string | null | undefined, empty: string): string {
  const start = startsAt ? new Date(startsAt) : null;
  const end = endsAt ? new Date(endsAt) : null;
  if (!start && !end) return empty;
  const fmt = (d: Date) =>
    d.toLocaleString('en-IN', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  if (start && end) return `${fmt(start)} → ${fmt(end)}`;
  if (start) return `From ${fmt(start)}`;
  return `Until ${fmt(end!)}`;
}

export function nominationWindowLabel(poll: ElectionPollRow): string {
  return windowLabel(poll.nomination_starts_at, poll.nomination_ends_at, 'Nomination window not scheduled');
}

export function votingWindowLabel(poll: ElectionPollRow): string {
  return windowLabel(poll.voting_starts_at, poll.voting_ends_at, 'Voting window not scheduled');
}

export function phaseBadgeLabel(phase: ElectionPhase): string {
  switch (phase) {
    case 'nomination':
      return 'Nomination open';
    case 'voting':
      return 'Voting open';
    case 'closed':
      return 'Closed — form committee';
    case 'applied':
      return 'Published to committee';
  }
}

export function postsForPoll(poll: ElectionPollRow, options: { election_post: string | null }[]): ElectionPost[] {
  const fromOpen = MANAGEMENT_COMMITTEE_POSTS.filter(
    (p) => (poll.open_posts ?? DEFAULT_OPEN_POSTS)[p] !== false,
  );
  const fromOpts = new Set(
    options
      .map((o) => o.election_post)
      .filter((p): p is ElectionPost => !!p && ALL_ELECTION_POSTS.includes(p as ElectionPost)),
  );
  const legacy = ALL_ELECTION_POSTS.filter((p) => fromOpts.has(p) && !fromOpen.includes(p));
  return [...fromOpen, ...legacy];
}

export function parseWinningVotes(raw: unknown): Record<string, number> {
  if (!raw || typeof raw !== 'object') return { ...DEFAULT_WINNING_VOTES };
  const out: Record<string, number> = { ...DEFAULT_WINNING_VOTES };
  for (const [k, v] of Object.entries(raw as Record<string, unknown>)) {
    const n = Number(v);
    if (Number.isFinite(n) && n >= 0) out[k] = Math.floor(n);
  }
  return out;
}

export function toDatetimeLocalValue(iso: string | null | undefined): string {
  if (!iso) return '';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '';
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

/** Default term_to = term_from + 2 years (bye-laws). */
export function defaultTermEndIso(termFromIso: string, years = DEFAULT_TERM_YEARS): string {
  const d = new Date(termFromIso);
  d.setFullYear(d.getFullYear() + years);
  return d.toISOString();
}
