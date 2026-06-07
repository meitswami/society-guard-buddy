import type { ElectionPost } from '@/lib/electionTally';

export type ElectionPhase = 'nomination' | 'voting' | 'closed' | 'applied';

export type ElectionPollRow = {
  id: string;
  is_active: boolean;
  election_phase?: string | null;
  voting_starts_at?: string | null;
  voting_ends_at?: string | null;
  election_applied_at?: string | null;
  open_posts?: Record<string, boolean> | null;
};

export const ALL_ELECTION_POSTS: ElectionPost[] = [
  'president',
  'vice_president',
  'secretary',
  'treasurer',
  'committee',
];

export const EXECUTIVE_POSTS: ElectionPost[] = [
  'president',
  'vice_president',
  'secretary',
  'treasurer',
];

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

export function isPostOpenForNomination(poll: ElectionPollRow, post: ElectionPost): boolean {
  if (electionPhase(poll) !== 'nomination') return false;
  const open = poll.open_posts ?? {};
  return open[post] !== false;
}

export function isVotingWindowOpen(poll: ElectionPollRow, now = Date.now()): boolean {
  if (electionPhase(poll) !== 'voting' || !poll.is_active) return false;
  const start = poll.voting_starts_at ? new Date(poll.voting_starts_at).getTime() : 0;
  const end = poll.voting_ends_at ? new Date(poll.voting_ends_at).getTime() : Number.MAX_SAFE_INTEGER;
  return now >= start && now <= end;
}

export function votingWindowLabel(poll: ElectionPollRow): string {
  const start = poll.voting_starts_at ? new Date(poll.voting_starts_at) : null;
  const end = poll.voting_ends_at ? new Date(poll.voting_ends_at) : null;
  if (!start && !end) return 'Window not scheduled';
  const fmt = (d: Date) =>
    d.toLocaleString('en-IN', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' });
  if (start && end) return `${fmt(start)} → ${fmt(end)}`;
  if (start) return `From ${fmt(start)}`;
  return `Until ${fmt(end!)}`;
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
