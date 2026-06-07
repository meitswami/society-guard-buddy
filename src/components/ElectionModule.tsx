import { useState, useCallback, useEffect } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { Landmark, Trash2, UserPlus, Award } from 'lucide-react';
import { toast } from 'sonner';
import { confirmAction, showSuccess } from '@/lib/swal';
import { DateInput } from '@/components/DateInput';
import VotingCharterPanel from '@/components/VotingCharterPanel';
import {
  validateElectionRankings,
  tallyElection,
  type ElectionPost,
  type ElectionResultsPayload,
  type PollOptionRow,
} from '@/lib/electionTally';
import {
  electionPhase,
  isPostOpenForNomination,
  isVotingWindowOpen,
  votingWindowLabel,
  phaseBadgeLabel,
  POST_DISPLAY,
  EXECUTIVE_POSTS,
  type ElectionPhase,
} from '@/lib/electionGovernance';
import { applyElectionToCommittee } from '@/lib/electionApply';
import { capsFieldChange } from '@/lib/entryCaps';

type VoterProfile = { name: string; flatNumber: string };

interface Props {
  /** When true, rendered inside PollManager elections section (no duplicate page chrome). */
  embedded?: boolean;
  adminName?: string;
  isResident?: boolean;
  societyId: string | null;
  voterId?: string;
  voterPhone?: string;
  memberId?: string;
  memberName?: string;
  flatNumber?: string;
  flatId?: string;
  electionPolls: any[];
  options: any[];
  ballots: any[];
  voterProfiles: Record<string, VoterProfile>;
  onReload: () => void;
}

const defaultOpenPosts = {
  president: true,
  vice_president: true,
  secretary: true,
  treasurer: true,
  committee: true,
};

const ElectionModule = ({
  embedded = false,
  adminName = 'Admin',
  isResident = false,
  societyId,
  voterId = '',
  voterPhone = '',
  memberId = '',
  memberName = '',
  flatNumber = '',
  flatId = '',
  electionPolls,
  options,
  ballots,
  voterProfiles,
  onReload,
}: Props) => {
  const [showElectionForm, setShowElectionForm] = useState(false);
  const [ef, setEf] = useState({
    question: '',
    description: '',
    committeeSeats: 5,
    votingStarts: '',
    votingEnds: '',
    termFrom: '',
    termTo: '',
    president: [''] as string[],
    vice_president: [''] as string[],
    secretary: [''] as string[],
    treasurer: [''] as string[],
    committee: ['', '', '', '', ''] as string[],
    openPosts: { ...defaultOpenPosts },
  });
  const [electionRanks, setElectionRanks] = useState<Record<string, Record<string, Record<string, number>>>>({});

  useEffect(() => {
    if (!voterId) return;
    setElectionRanks((prev) => {
      const merged = { ...prev };
      for (const b of ballots) {
        if (b.voter_id === voterId && b.rankings && typeof b.rankings === 'object') {
          merged[b.poll_id] = b.rankings as Record<string, Record<string, number>>;
        }
      }
      return merged;
    });
  }, [ballots, voterId]);

  const setRank = useCallback((pollId: string, post: string, optionId: string, rankStr: string) => {
    setElectionRanks((prev) => {
      const pollR = { ...(prev[pollId] ?? {}) };
      const postR = { ...(pollR[post] ?? {}) };
      const rank = rankStr === '' ? undefined : Number(rankStr);
      if (rank === undefined || Number.isNaN(rank)) delete postR[optionId];
      else postR[optionId] = rank;
      pollR[post] = postR;
      return { ...prev, [pollId]: pollR };
    });
  }, []);

  const addElection = async () => {
    if (!societyId || !ef.question.trim()) return;
    const seats = Math.max(5, Math.min(20, Number(ef.committeeSeats) || 5));
    const names = (post: ElectionPost) =>
      (post === 'committee' ? ef.committee : ef[post]).map((s) => s.trim()).filter(Boolean);

    const { data: poll, error: pe } = await supabase
      .from('polls')
      .insert([
        {
          question: ef.question.trim(),
          description: ef.description.trim() || null,
          created_by: adminName,
          society_id: societyId,
          poll_kind: 'election',
          election_committee_seats: seats,
          election_phase: 'nomination',
          is_active: true,
          voting_starts_at: ef.votingStarts ? new Date(ef.votingStarts).toISOString() : null,
          voting_ends_at: ef.votingEnds ? new Date(ef.votingEnds).toISOString() : null,
          election_term_from: ef.termFrom || null,
          election_term_to: ef.termTo || null,
          open_posts: ef.openPosts,
        },
      ])
      .select()
      .single();

    if (pe || !poll) {
      toast.error(pe?.message ?? 'Could not create election');
      return;
    }

    const rows: { poll_id: string; option_text: string; election_post: string; votes_count: number }[] = [];
    for (const post of [...EXECUTIVE_POSTS, 'committee'] as ElectionPost[]) {
      for (const t of names(post)) {
        rows.push({ poll_id: poll.id, option_text: t, election_post: post, votes_count: 0 });
      }
    }
    if (rows.length > 0) await supabase.from('poll_options').insert(rows);

    setEf({
      question: '',
      description: '',
      committeeSeats: 5,
      votingStarts: '',
      votingEnds: '',
      termFrom: '',
      termTo: '',
      president: [''],
      vice_president: [''],
      secretary: [''],
      treasurer: [''],
      committee: ['', '', '', '', ''],
      openPosts: { ...defaultOpenPosts },
    });
    setShowElectionForm(false);
    toast.success('Election created — nomination phase open');
    onReload();
    await supabase.from('notifications').insert([
      {
        title: 'Society election — nomination open',
        message: `Propose yourself for posts: ${ef.question.trim()}`,
        type: 'poll',
        target_type: 'all',
        created_by: adminName,
        society_id: societyId,
      },
    ]);
  };

  const selfNominate = async (poll: any, post: ElectionPost) => {
    if (!memberId || !memberName || !flatId) {
      toast.error('Your member profile is required to self-nominate.');
      return;
    }
    if (!isPostOpenForNomination(poll, post)) {
      toast.error('Self-nomination is not open for this post.');
      return;
    }
    const existing = options.filter(
      (o) => o.poll_id === poll.id && o.election_post === post && o.member_id === memberId,
    );
    if (existing.length > 0) {
      toast.error('You have already nominated yourself for this post.');
      return;
    }
    const { error } = await supabase.from('poll_options').insert([
      {
        poll_id: poll.id,
        option_text: memberName.trim(),
        election_post: post,
        votes_count: 0,
        member_id: memberId,
        flat_id: flatId,
        flat_number: flatNumber || null,
        nominated_by: voterId || memberId,
      },
    ]);
    if (error) toast.error(error.message);
    else {
      toast.success(`Nominated for ${POST_DISPLAY[post]}`);
      onReload();
    }
  };

  const submitElectionBallot = async (poll: any) => {
    if (!voterId || !flatId) {
      toast.error('Missing member or flat context.');
      return;
    }
    if (!isVotingWindowOpen(poll)) {
      toast.error('Voting is not open in the current time window.');
      return;
    }
    const pollOpts = options.filter((o) => o.poll_id === poll.id) as PollOptionRow[];
    const rankings = electionRanks[poll.id] ?? {};
    const err = validateElectionRankings(pollOpts, rankings, Number(poll.election_committee_seats) || 5);
    if (err) {
      toast.error(err);
      return;
    }

    const phone = (voterPhone || '').replace(/\D/g, '');
    const existingBallot = ballots.find((b) => b.poll_id === poll.id && b.voter_id === voterId);
    if (!existingBallot && phone) {
      const phoneVote = ballots.find(
        (b) => b.poll_id === poll.id && String(b.voter_phone || '').replace(/\D/g, '') === phone,
      );
      if (phoneVote) {
        toast.error('You have already voted (one vote per member, even across multiple flats).');
        return;
      }
    }

    const sameFlat = (b: { poll_id: string; flat_id?: string | null }) =>
      b.poll_id === poll.id && flatId && b.flat_id === flatId;
    const flatBallots = ballots.filter(sameFlat);
    const distinctOthers = new Set(flatBallots.filter((b) => b.voter_id !== voterId).map((b) => b.voter_id));
    if (!existingBallot && distinctOthers.size >= 2) {
      toast.error('This flat already has two ballots (e.g. both spouses).');
      return;
    }

    const { error } = await supabase.from('poll_election_ballots').upsert(
      {
        poll_id: poll.id,
        voter_id: voterId,
        flat_id: flatId,
        flat_number: flatNumber || null,
        voter_phone: phone || null,
        rankings,
      },
      { onConflict: 'poll_id,voter_id' },
    );
    if (error) toast.error(error.message);
    else {
      toast.success(existingBallot ? 'Ballot updated' : 'Ranked ballot submitted');
      onReload();
    }
  };

  const startVoting = async (poll: any) => {
    const ok = await confirmAction('Open voting?', 'Residents can rank candidates during the scheduled window.', 'Open voting', 'Cancel');
    if (!ok) return;
    await supabase
      .from('polls')
      .update({ election_phase: 'voting', is_active: true })
      .eq('id', poll.id);
    toast.success('Voting phase started');
    onReload();
  };

  const closeElection = async (poll: any) => {
    const ok = await confirmAction('Close election?', 'Voting stops. Results stay in admin portal until you publish to the committee roster.', 'Close & tally', 'Cancel');
    if (!ok) return;
    const pollOpts = options.filter((o) => o.poll_id === poll.id) as PollOptionRow[];
    const bRows = ballots
      .filter((b) => b.poll_id === poll.id)
      .map((b) => ({ rankings: b.rankings as Record<string, Record<string, number>> }));
    const results = tallyElection(pollOpts, bRows, Number(poll.election_committee_seats) || 5) as ElectionResultsPayload;
    await supabase
      .from('polls')
      .update({ is_active: false, election_phase: 'closed', election_results: results as unknown as Record<string, unknown> })
      .eq('id', poll.id);
    showSuccess('Election closed', 'Results are available here in the admin portal.');
    onReload();
  };

  const publishToCommittee = async (poll: any) => {
    if (!societyId || !poll.election_results) return;
    const ok = await confirmAction(
      'Publish to Committee module?',
      'Elected members will appear in the residents’ Committee tab. This cannot be undone automatically.',
      'Publish',
      'Cancel',
    );
    if (!ok) return;
    const pollOpts = options.filter((o) => o.poll_id === poll.id) as PollOptionRow[];
    const res = await applyElectionToCommittee({
      societyId,
      pollId: poll.id,
      results: poll.election_results as ElectionResultsPayload,
      options: pollOpts,
      termFrom: poll.election_term_from,
      termTo: poll.election_term_to,
    });
    if (!res.ok) toast.error(res.error);
    else {
      showSuccess('Published', 'Committee roster updated for residents.');
      onReload();
    }
  };

  const renderResults = (poll: any, adminView: boolean) => {
    const raw = poll.election_results;
    if (!raw || typeof raw !== 'object') return null;
    const r = raw as ElectionResultsPayload;
    return (
      <div className="mt-3 rounded-lg border border-primary/30 bg-primary/5 p-3 space-y-1 text-sm">
        <p className="text-xs font-semibold text-primary uppercase tracking-wide flex items-center gap-1">
          <Award className="w-3.5 h-3.5" /> {adminView ? 'Tallied results (admin only)' : 'Results'}
        </p>
        {(['president', 'vice_president', 'secretary', 'treasurer'] as const).map((post) => {
          const w = r[post];
          if (!w) return null;
          return (
            <p key={post}>
              <span className="text-muted-foreground">{POST_DISPLAY[post]}:</span>{' '}
              <strong>{w.name}</strong>
              <span className="text-[10px] text-muted-foreground ml-1">({w.score} pts)</span>
            </p>
          );
        })}
        {r.committee?.length > 0 && (
          <div>
            <p className="text-muted-foreground text-xs mt-1">Committee ({r.committee.length})</p>
            <ul className="list-disc list-inside font-medium">
              {r.committee.map((c) => (
                <li key={c.option_id}>
                  {c.name}
                  <span className="text-[10px] text-muted-foreground font-normal ml-1">({c.score} pts)</span>
                </li>
              ))}
            </ul>
          </div>
        )}
      </div>
    );
  };

  const renderRankControls = (poll: any, post: ElectionPost) => {
    const postOpts = options.filter((o) => o.poll_id === poll.id && o.election_post === post);
    if (postOpts.length === 0) return null;
    const m = postOpts.length;
    const ranks = electionRanks[poll.id]?.[post] ?? {};
    return (
      <div className="space-y-2 mb-3">
        <p className="text-xs font-semibold text-muted-foreground">
          {POST_DISPLAY[post]} — rank each candidate (1 = highest preference)
        </p>
        {postOpts.map((opt) => (
          <div key={opt.id} className="flex flex-wrap items-center justify-between gap-2 text-sm">
            <span className="min-w-0 flex-1">
              {opt.option_text}
              {opt.flat_number ? <span className="text-[10px] text-muted-foreground ml-1">· Flat {opt.flat_number}</span> : null}
            </span>
            <select
              className="input-field w-24 text-sm py-1"
              value={ranks[opt.id] ?? ''}
              onChange={(e) => setRank(poll.id, post, opt.id, e.target.value)}
            >
              <option value="">—</option>
              {Array.from({ length: m }, (_, i) => i + 1).map((n) => (
                <option key={n} value={n}>
                  {n}
                </option>
              ))}
            </select>
          </div>
        ))}
      </div>
    );
  };

  const renderElectionCard = (poll: any) => {
    const phase = electionPhase(poll);
    const pollBallots = ballots.filter((b) => b.poll_id === poll.id);
    const myBallot = pollBallots.find((b) => b.voter_id === voterId);
    const seats = Number(poll.election_committee_seats) || 5;
    const votingOpen = isVotingWindowOpen(poll);
    const showResultsToResident = false;

    return (
      <div key={poll.id} className="card-section p-4 mb-3 border-l-4 border-l-primary">
        <div className="flex justify-between items-start gap-2 mb-2">
          <div className="min-w-0">
            <span className="text-[10px] uppercase font-semibold text-primary">Election</span>
            <p className="font-semibold">{poll.question}</p>
            {poll.description && <p className="text-xs text-muted-foreground mt-1">{poll.description}</p>}
            <p className="text-[11px] text-muted-foreground mt-1">Voting window: {votingWindowLabel(poll)}</p>
          </div>
          <span className="text-[10px] px-2 py-0.5 rounded-full shrink-0 bg-muted text-muted-foreground">
            {phaseBadgeLabel(phase)}
          </span>
        </div>
        <p className="text-xs text-muted-foreground mb-2">{pollBallots.length} ballot(s) cast</p>

        {!isResident && (phase === 'closed' || phase === 'applied') && poll.election_results && renderResults(poll, true)}

        {isResident && showResultsToResident && poll.election_results && renderResults(poll, false)}

        {isResident && phase === 'nomination' && (
          <div className="mt-3 border-t border-border pt-3 space-y-2">
            <p className="text-xs font-medium text-foreground">Propose yourself for a post</p>
            <div className="flex flex-wrap gap-2">
              {([...EXECUTIVE_POSTS, 'committee'] as ElectionPost[]).map((post) =>
                isPostOpenForNomination(poll, post) ? (
                  <button
                    key={post}
                    type="button"
                    onClick={() => void selfNominate(poll, post)}
                    className="text-xs px-3 py-1.5 rounded-lg border border-primary/40 text-primary hover:bg-primary/10 flex items-center gap-1"
                  >
                    <UserPlus className="w-3 h-3" /> {POST_DISPLAY[post]}
                  </button>
                ) : null,
              )}
            </div>
          </div>
        )}

        {isResident && phase === 'voting' && (
          <div className="mt-3 space-y-1 border-t border-border pt-3">
            {!votingOpen && (
              <p className="text-xs text-amber-600">Voting opens in the scheduled window: {votingWindowLabel(poll)}</p>
            )}
            {myBallot && votingOpen && (
              <p className="text-xs text-green-600 font-medium mb-2">Ballot submitted — you may update ranks until the window closes.</p>
            )}
            {votingOpen && (
              <>
                {EXECUTIVE_POSTS.map((post) => (
                  <div key={post}>{renderRankControls(poll, post)}</div>
                ))}
                {renderRankControls(poll, 'committee')}
                <button
                  type="button"
                  disabled={!flatId || !voterId}
                  onClick={() => void submitElectionBallot(poll)}
                  className="btn-primary w-full text-sm mt-2"
                >
                  Submit ranked ballot
                </button>
              </>
            )}
          </div>
        )}

        {!isResident && (
          <div className="mt-2 text-xs text-muted-foreground space-y-1">
            {pollBallots.slice(0, 6).map((b) => {
              const prof = voterProfiles[b.voter_id];
              return (
                <div key={b.id} className="flex justify-between gap-2">
                  <span>{prof?.name ?? b.voter_id.slice(0, 8)}</span>
                  <span>Flat {prof?.flatNumber ?? b.flat_number ?? '—'}</span>
                </div>
              );
            })}
          </div>
        )}

        {!isResident && (
          <div className="mt-3 flex flex-wrap gap-2">
            {phase === 'nomination' && (
              <button type="button" onClick={() => void startVoting(poll)} className="text-xs px-3 py-1.5 rounded-lg bg-primary text-primary-foreground">
                Start voting window
              </button>
            )}
            {phase === 'voting' && poll.is_active && (
              <button type="button" onClick={() => void closeElection(poll)} className="text-xs text-destructive underline">
                Close election &amp; tally
              </button>
            )}
            {phase === 'closed' && (
              <button type="button" onClick={() => void publishToCommittee(poll)} className="text-xs px-3 py-1.5 rounded-lg bg-emerald-600 text-white">
                Publish winners to Committee module
              </button>
            )}
            {phase === 'applied' && (
              <span className="text-xs text-green-600 font-medium">✓ Published to committee roster</span>
            )}
          </div>
        )}
      </div>
    );
  };

  return (
    <div className={embedded ? 'space-y-3' : ''}>
      <VotingCharterPanel />

      {!embedded && (
        <div className="mb-3 rounded-lg border border-primary/20 bg-primary/5 px-3 py-2">
          <p className="text-[11px] text-muted-foreground">
            <strong className="text-foreground">Society Elections</strong> — nominate, rank-vote for MC posts, publish winners to Committee.
          </p>
        </div>
      )}

      {!isResident && (
        <>
          <button
            type="button"
            onClick={() => setShowElectionForm(!showElectionForm)}
            className="btn-primary flex items-center justify-center gap-2 w-full sm:w-auto"
          >
            <Landmark className="w-4 h-4" /> New society election
          </button>

          {showElectionForm && (
            <div className="card-section p-4 mb-4 flex flex-col gap-3">
              <p className="text-xs font-semibold text-muted-foreground uppercase">Society election (nomination first)</p>
              <input
                className="input-field"
                placeholder="Election title (e.g. Managing Committee 2026)"
                value={ef.question}
                onChange={capsFieldChange(setEf, 'question')}
              />
              <textarea
                className="input-field"
                placeholder="Description (optional)"
                value={ef.description}
                onChange={capsFieldChange(setEf, 'description')}
              />
              <div className="grid grid-cols-2 gap-2">
                <div>
                  <label className="text-[10px] text-muted-foreground">Voting starts</label>
                  <input
                    type="datetime-local"
                    className="input-field mt-0.5"
                    value={ef.votingStarts}
                    onChange={(e) => setEf({ ...ef, votingStarts: e.target.value })}
                  />
                </div>
                <div>
                  <label className="text-[10px] text-muted-foreground">Voting ends</label>
                  <input
                    type="datetime-local"
                    className="input-field mt-0.5"
                    value={ef.votingEnds}
                    onChange={(e) => setEf({ ...ef, votingEnds: e.target.value })}
                  />
                </div>
              </div>
              <div className="grid grid-cols-2 gap-2">
                <div>
                  <label className="text-[10px] text-muted-foreground">Tenure from</label>
                  <DateInput className="input-field mt-0.5" value={ef.termFrom} onChange={(e) => setEf({ ...ef, termFrom: e.target.value })} />
                </div>
                <div>
                  <label className="text-[10px] text-muted-foreground">Tenure to (optional)</label>
                  <DateInput className="input-field mt-0.5" value={ef.termTo} onChange={(e) => setEf({ ...ef, termTo: e.target.value })} />
                </div>
              </div>
              <label className="text-xs text-muted-foreground">
                Committee seats (min 5)
                <input
                  className="input-field mt-1"
                  type="number"
                  min={5}
                  max={20}
                  value={ef.committeeSeats}
                  onChange={(e) => setEf({ ...ef, committeeSeats: Number(e.target.value) || 5 })}
                />
              </label>

              {([...EXECUTIVE_POSTS, 'committee'] as ElectionPost[]).map((post) => (
                <div key={post} className="space-y-2">
                  <p className="text-xs font-semibold">{POST_DISPLAY[post]} — seed candidates (optional)</p>
                  {(post === 'committee' ? ef.committee : ef[post]).map((line, i) => (
                    <div key={`${post}-${i}`} className="flex gap-2">
                      <input
                        className="input-field flex-1 text-sm"
                        placeholder={`Name ${i + 1}`}
                        value={line}
                        onChange={(e) => {
                          const next = [...(post === 'committee' ? ef.committee : ef[post])];
                          next[i] = e.target.value;
                          setEf({ ...ef, [post]: next });
                        }}
                      />
                      {(post === 'committee' ? ef.committee : ef[post]).length > 1 && (
                        <button
                          type="button"
                          onClick={() =>
                            setEf({
                              ...ef,
                              [post]: (post === 'committee' ? ef.committee : ef[post]).filter((_, j) => j !== i),
                            })
                          }
                          className="text-destructive"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      )}
                    </div>
                  ))}
                  <button
                    type="button"
                    className="text-xs text-primary underline"
                    onClick={() =>
                      setEf({
                        ...ef,
                        [post]: [...(post === 'committee' ? ef.committee : ef[post]), ''],
                      })
                    }
                  >
                    + Add {POST_DISPLAY[post]} candidate
                  </button>
                </div>
              ))}

              <button type="button" onClick={() => void addElection()} className="btn-primary">
                Create election (nomination phase)
              </button>
            </div>
          )}
        </>
      )}

      {electionPolls.length > 0 ? (
        <div className="space-y-3">{electionPolls.map(renderElectionCard)}</div>
      ) : (
        <div className="card-section p-6 text-center">
          <Landmark className="w-8 h-8 text-muted-foreground mx-auto mb-2 opacity-50" />
          <p className="text-sm text-muted-foreground">No society elections yet.</p>
          {!isResident && (
            <p className="text-xs text-muted-foreground mt-1">Create an election to open nomination for executive and committee posts.</p>
          )}
          {isResident && (
            <p className="text-xs text-muted-foreground mt-1">When the admin opens an election, you can self-nominate and vote here.</p>
          )}
        </div>
      )}
    </div>
  );
};

export default ElectionModule;
