import type { ElectionPost } from '@/lib/electionTally';

export type ElectionPhase = 'nomination' | 'voting' | 'closed' | 'applied';

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
};

/** Posts used for new society elections (President, Secretary, Treasurer). */
export const THREE_EXECUTIVE_POSTS: ElectionPost[] = ['president', 'secretary', 'treasurer'];

/** All posts that may appear on legacy elections. */
export const ALL_ELECTION_POSTS: ElectionPost[] = [
  'president',
  'vice_president',
  'secretary',
  'treasurer',
  'committee',
];

/** @deprecated Prefer THREE_EXECUTIVE_POSTS for new elections. */
export const EXECUTIVE_POSTS: ElectionPost[] = THREE_EXECUTIVE_POSTS;

export const DEFAULT_OPEN_POSTS: Record<ElectionPost, boolean> = {
  president: true,
  secretary: true,
  treasurer: true,
  vice_president: false,
  committee: false,
};

export const DEFAULT_WINNING_VOTES: Record<string, number> = {
  president: 0,
  secretary: 0,
  treasurer: 0,
};

export const POST_DISPLAY: Record<ElectionPost, string> = {
  president: 'President',
  vice_president: 'Vice-President',
  secretary: 'Secretary',
  treasurer: 'Treasurer',
  committee: 'Committee member',
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
      return 'Closed — admin review';
    case 'applied':
      return 'Published to committee';
  }
}

export function postsForPoll(poll: ElectionPollRow, options: { election_post: string | null }[]): ElectionPost[] {
  const fromOpen = THREE_EXECUTIVE_POSTS.filter((p) => (poll.open_posts ?? DEFAULT_OPEN_POSTS)[p] !== false);
  const fromOpts = new Set(
    options.map((o) => o.election_post).filter((p): p is ElectionPost => !!p && ALL_ELECTION_POSTS.includes(p as ElectionPost)),
  );
  const legacy = ALL_ELECTION_POSTS.filter((p) => fromOpts.has(p) && !THREE_EXECUTIVE_POSTS.includes(p));
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
