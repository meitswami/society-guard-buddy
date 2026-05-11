import { useState, useEffect, useMemo, useCallback } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useStore } from '@/store/useStore';
import { Vote, Plus, Trash2, Landmark } from 'lucide-react';
import { toast } from 'sonner';
import { confirmAction, showSuccess } from '@/lib/swal';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import {
  validateElectionRankings,
  tallyElection,
  type ElectionPost,
  type ElectionResultsPayload,
  type PollOptionRow,
} from '@/lib/electionTally';
import { ElectionResultsBanner } from '@/components/ElectionResultsBanner';

interface Props {
  adminName?: string;
  isResident?: boolean;
  voterId?: string;
  flatNumber?: string;
  /** Flat UUID — required to enforce max 2 ballots per flat for elections. */
  flatId?: string;
}

type VoterProfile = { name: string; flatNumber: string };

const POST_LABEL: Record<ElectionPost, string> = {
  president: 'President',
  secretary: 'Secretary',
  treasurer: 'Treasurer',
  committee: 'Committee member',
};

const EXEC_POSTS: ElectionPost[] = ['president', 'secretary', 'treasurer'];

function normKind(row: { poll_kind?: string | null }): 'standard' | 'election' {
  return row.poll_kind === 'election' ? 'election' : 'standard';
}

const PollManager = ({
  adminName = 'Admin',
  isResident = false,
  voterId = '',
  flatNumber = '',
  flatId = '',
}: Props) => {
  const societyId = useStore((s) => s.societyId);
  const [polls, setPolls] = useState<any[]>([]);
  const [options, setOptions] = useState<any[]>([]);
  const [votes, setVotes] = useState<any[]>([]);
  const [ballots, setBallots] = useState<any[]>([]);
  const [voterProfiles, setVoterProfiles] = useState<Record<string, VoterProfile>>({});
  const [voteDetailOption, setVoteDetailOption] = useState<{ optionId: string; optionText: string } | null>(null);
  const [showForm, setShowForm] = useState(false);
  const [showElectionForm, setShowElectionForm] = useState(false);
  const [pf, setPf] = useState({ question: '', description: '', options: ['', ''] });
  const [ef, setEf] = useState({
    question: '',
    description: '',
    committeeSeats: 5,
    president: [''],
    secretary: [''],
    treasurer: [''],
    committee: ['', '', '', '', ''],
  });
  /** Per-election poll id → rankings JSON shape for validate/tally */
  const [electionRanks, setElectionRanks] = useState<Record<string, Record<string, Record<string, number>>>>({});

  useEffect(() => {
    void loadAll();
  }, [societyId]);

  const loadAll = async () => {
    if (!societyId) {
      setPolls([]);
      setOptions([]);
      setVotes([]);
      setBallots([]);
      setVoterProfiles({});
      return;
    }
    const { data: p } = await supabase
      .from('polls')
      .select('*')
      .eq('society_id', societyId)
      .order('created_at', { ascending: false });
    const pollRows = p ?? [];
    setPolls(pollRows);
    const pollIds = pollRows.map((row) => row.id);
    const electionIds = pollRows.filter((row) => normKind(row) === 'election').map((row) => row.id);

    const [o, v, b] = await Promise.all([
      pollIds.length ? supabase.from('poll_options').select('*').in('poll_id', pollIds) : Promise.resolve({ data: [] as any[] }),
      pollIds.length ? supabase.from('poll_votes').select('*').in('poll_id', pollIds) : Promise.resolve({ data: [] as any[] }),
      electionIds.length
        ? supabase.from('poll_election_ballots').select('*').in('poll_id', electionIds)
        : Promise.resolve({ data: [] as any[] }),
    ]);
    if (o.data) setOptions(o.data);
    if (v.data) {
      setVotes(v.data);
    } else {
      setVotes([]);
    }
    const ballotVoterIds = (b.data ?? []).map((row: { voter_id: string }) => row.voter_id).filter(Boolean);
    const voteVoterIds = (v.data ?? []).map((row: { voter_id: string }) => row.voter_id).filter(Boolean);
    const ids = [...new Set([...voteVoterIds, ...ballotVoterIds])] as string[];
    if (ids.length > 0) {
        const { data: mems } = await supabase.from('members').select('id, name, flat_id').in('id', ids);
        const flatIds = [...new Set((mems ?? []).map((m) => m.flat_id).filter(Boolean))] as string[];
        const { data: flatRows } =
          flatIds.length > 0
            ? await supabase.from('flats').select('id, flat_number').in('id', flatIds)
            : { data: [] as { id: string; flat_number: string }[] };
        const flatNumById = new Map((flatRows ?? []).map((f) => [f.id, f.flat_number]));
        const map: Record<string, VoterProfile> = {};
        for (const m of mems ?? []) {
          map[m.id] = {
            name: (m.name as string)?.trim() || 'Member',
            flatNumber: flatNumById.get(m.flat_id) ?? '',
          };
        }
        setVoterProfiles(map);
    } else {
      setVoterProfiles({});
    }
    setBallots(b.data ?? []);
  };

  const standardPolls = useMemo(() => polls.filter((p) => normKind(p) === 'standard'), [polls]);
  const electionPolls = useMemo(() => polls.filter((p) => normKind(p) === 'election'), [polls]);

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

  const detailVoters = useMemo(() => {
    if (!voteDetailOption) return [];
    return votes
      .filter((row) => row.option_id === voteDetailOption.optionId)
      .sort((a, b) => {
        const na = voterProfiles[a.voter_id]?.name ?? '';
        const nb = voterProfiles[b.voter_id]?.name ?? '';
        return na.localeCompare(nb);
      });
  }, [voteDetailOption, votes, voterProfiles]);

  const addPoll = async () => {
    if (!societyId || !pf.question || pf.options.filter((o) => o.trim()).length < 2) return;
    const notifyTitle = pf.question.trim();
    const { data: poll } = await supabase
      .from('polls')
      .insert([
        {
          question: pf.question,
          description: pf.description || null,
          created_by: adminName,
          society_id: societyId,
          poll_kind: 'standard',
        },
      ])
      .select()
      .single();
    if (poll) {
      const opts = pf.options.filter((o) => o.trim()).map((o) => ({ poll_id: poll.id, option_text: o.trim() }));
      await supabase.from('poll_options').insert(opts);
    }
    setPf({ question: '', description: '', options: ['', ''] });
    setShowForm(false);
    toast.success('Poll created');
    loadAll();
    await supabase.from('notifications').insert([
      {
        title: 'New Poll',
        message: `Vote now: ${notifyTitle}`,
        type: 'poll',
        target_type: 'all',
        created_by: adminName,
        society_id: societyId,
      },
    ]);
  };

  const addElection = async () => {
    if (!societyId || !ef.question.trim()) return;
    const notifyTitle = ef.question.trim();
    const seats = Math.max(5, Math.min(20, Number(ef.committeeSeats) || 5));
    const names = (post: ElectionPost) =>
      (post === 'committee' ? ef.committee : ef[post]).map((s) => s.trim()).filter(Boolean);
    const pres = names('president');
    const sec = names('secretary');
    const tre = names('treasurer');
    const com = names('committee');
    if (pres.length < 1 || sec.length < 1 || tre.length < 1) {
      toast.error('Add at least one candidate for President, Secretary, and Treasurer');
      return;
    }
    if (com.length < 1) {
      toast.error('Add at least one committee candidate');
      return;
    }
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
          is_active: true,
        },
      ])
      .select()
      .single();
    if (pe || !poll) {
      toast.error(pe?.message ?? 'Could not create election');
      return;
    }
    const rows: { poll_id: string; option_text: string; election_post: string; votes_count: number }[] = [];
    for (const t of pres) rows.push({ poll_id: poll.id, option_text: t, election_post: 'president', votes_count: 0 });
    for (const t of sec) rows.push({ poll_id: poll.id, option_text: t, election_post: 'secretary', votes_count: 0 });
    for (const t of tre) rows.push({ poll_id: poll.id, option_text: t, election_post: 'treasurer', votes_count: 0 });
    for (const t of com) rows.push({ poll_id: poll.id, option_text: t, election_post: 'committee', votes_count: 0 });
    await supabase.from('poll_options').insert(rows);
    setEf({
      question: '',
      description: '',
      committeeSeats: 5,
      president: [''],
      secretary: [''],
      treasurer: [''],
      committee: ['', '', '', '', ''],
    });
    setShowElectionForm(false);
    toast.success('Election created');
    loadAll();
    await supabase.from('notifications').insert([
      {
        title: 'Society election',
        message: `Ranked voting open: ${notifyTitle}`,
        type: 'poll',
        target_type: 'all',
        created_by: adminName,
        society_id: societyId,
      },
    ]);
  };

  const castVote = async (pollId: string, optionId: string) => {
    const existing = votes.find((v) => v.poll_id === pollId && v.voter_id === voterId);
    if (existing) {
      toast.error('Already voted');
      return;
    }
    await supabase.from('poll_votes').insert([
      {
        poll_id: pollId,
        option_id: optionId,
        voter_id: voterId,
        voter_type: 'resident',
        flat_number: flatNumber,
      },
    ]);
    await supabase
      .from('poll_options')
      .update({ votes_count: (options.find((o) => o.id === optionId)?.votes_count || 0) + 1 })
      .eq('id', optionId);
    toast.success('Vote cast!');
    loadAll();
  };

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

  const submitElectionBallot = async (poll: any) => {
    if (!voterId || !flatId) {
      toast.error('Missing member or flat context — reopen Polls from your dashboard.');
      return;
    }
    const pollOpts = options.filter((o) => o.poll_id === poll.id) as PollOptionRow[];
    const rankings = electionRanks[poll.id] ?? {};
    const err = validateElectionRankings(pollOpts, rankings, Number(poll.election_committee_seats) || 5);
    if (err) {
      toast.error(err);
      return;
    }

    const existingBallot = ballots.find((b) => b.poll_id === poll.id && b.voter_id === voterId);
    const sameFlat = (b: { poll_id: string; flat_id?: string | null; flat_number?: string | null }) => {
      if (b.poll_id !== poll.id) return false;
      if (flatId && b.flat_id === flatId) return true;
      if (flatNumber && b.flat_number && String(b.flat_number) === String(flatNumber)) return true;
      return false;
    };
    const flatBallots = ballots.filter(sameFlat);
    const distinctOthers = new Set(flatBallots.filter((b) => b.voter_id !== voterId).map((b) => b.voter_id));
    if (!existingBallot && distinctOthers.size >= 2) {
      toast.error('This flat already has two ballots (e.g. both spouses). No further votes from this flat.');
      return;
    }

    const payload = {
      poll_id: poll.id,
      voter_id: voterId,
      flat_id: flatId,
      flat_number: flatNumber || null,
      rankings,
    };
    const { error } = await supabase.from('poll_election_ballots').upsert(payload, { onConflict: 'poll_id,voter_id' });
    if (error) {
      toast.error(error.message);
      return;
    }
    toast.success(existingBallot ? 'Ballot updated' : 'Ranked ballot submitted');
    loadAll();
  };

  const closePoll = async (poll: any) => {
    const ok = await confirmAction(
      normKind(poll) === 'election' ? 'Close election?' : 'Close Poll?',
      normKind(poll) === 'election'
        ? 'Voting stops and winners are calculated from ranked ballots.'
        : 'This will stop accepting new votes.',
      'Yes, Close',
      'Cancel',
    );
    if (!ok) return;

    if (normKind(poll) === 'election') {
      const pollOpts = options.filter((o) => o.poll_id === poll.id) as PollOptionRow[];
      const bRows = ballots.filter((b) => b.poll_id === poll.id).map((b) => ({ rankings: b.rankings as Record<string, Record<string, number>> }));
      const results = tallyElection(pollOpts, bRows, Number(poll.election_committee_seats) || 5) as ElectionResultsPayload;
      await supabase
        .from('polls')
        .update({ is_active: false, election_results: results as unknown as Record<string, unknown> })
        .eq('id', poll.id);
      showSuccess('Election closed', 'Results are published to residents and admin home.');
    } else {
      await supabase.from('polls').update({ is_active: false }).eq('id', poll.id);
      showSuccess('Closed!', 'Poll has been closed');
    }
    loadAll();
  };

  const openVoteDetail = (opt: { id: string; option_text: string; votes_count?: number | null }) => {
    const c = Number(opt.votes_count) || 0;
    const actual = votes.filter((v) => v.option_id === opt.id).length;
    if (c === 0 && actual === 0) {
      toast.message('No votes for this option yet');
      return;
    }
    setVoteDetailOption({ optionId: opt.id, optionText: opt.option_text });
  };

  const renderElectionResults = (poll: any) => {
    const raw = poll.election_results;
    if (!raw || typeof raw !== 'object') return null;
    const r = raw as ElectionResultsPayload;
    return (
      <div className="mt-3 rounded-lg border border-primary/30 bg-primary/5 p-3 space-y-1 text-sm">
        <p className="text-xs font-semibold text-primary uppercase tracking-wide">Elected</p>
        {r.president && (
          <p>
            <span className="text-muted-foreground">President:</span> <strong>{r.president.name}</strong>
          </p>
        )}
        {r.secretary && (
          <p>
            <span className="text-muted-foreground">Secretary:</span> <strong>{r.secretary.name}</strong>
          </p>
        )}
        {r.treasurer && (
          <p>
            <span className="text-muted-foreground">Treasurer:</span> <strong>{r.treasurer.name}</strong>
          </p>
        )}
        {r.committee?.length > 0 && (
          <div>
            <p className="text-muted-foreground text-xs mt-1">Committee ({r.committee.length})</p>
            <ul className="list-disc list-inside font-medium">
              {r.committee.map((c) => (
                <li key={c.option_id}>{c.name}</li>
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
        <p className="text-xs font-semibold text-muted-foreground">{POST_LABEL[post]} — rank each candidate (1 = highest preference)</p>
        {postOpts.map((opt) => (
          <div key={opt.id} className="flex flex-wrap items-center justify-between gap-2 text-sm">
            <span className="min-w-0 flex-1">{opt.option_text}</span>
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
    const pollBallots = ballots.filter((b) => b.poll_id === poll.id);
    const myBallot = pollBallots.find((b) => b.voter_id === voterId);
    const hasVoted = !!myBallot;
    const seats = Number(poll.election_committee_seats) || 5;

    return (
      <div key={poll.id} className="card-section p-4 mb-3 border-l-4 border-l-primary">
        <div className="flex justify-between items-start gap-2 mb-2">
          <div className="min-w-0">
            <span className="text-[10px] uppercase font-semibold text-primary">Election</span>
            <p className="font-semibold">{poll.question}</p>
            {poll.description && <p className="text-xs text-muted-foreground mt-1">{poll.description}</p>}
            <p className="text-[11px] text-muted-foreground mt-1">
              Three executive posts (President, Secretary, Treasurer) and {seats} committee seat(s). Each flat may submit
              up to two ranked ballots (e.g. spouses). One ballot per member.
            </p>
          </div>
          <span
            className={`text-[10px] px-2 py-0.5 rounded-full shrink-0 ${poll.is_active ? 'bg-green-500/20 text-green-600' : 'bg-muted text-muted-foreground'}`}
          >
            {poll.is_active ? 'Voting open' : 'Closed'}
          </span>
        </div>
        <p className="text-xs text-muted-foreground mb-2">{pollBallots.length} ballot(s) cast</p>

        {!poll.is_active && poll.election_results && renderElectionResults(poll)}

        {isResident && poll.is_active && (
          <div className="mt-3 space-y-1 border-t border-border pt-3">
            {hasVoted && <p className="text-xs text-green-600 font-medium mb-2">You have submitted a ballot. You may adjust ranks and save again.</p>}
            {!flatId && (
              <p className="text-xs text-destructive">Flat link missing — cannot submit election ballot from this screen.</p>
            )}
            {EXEC_POSTS.map((post) => (
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
          </div>
        )}

        {!isResident && (
          <div className="mt-2 text-xs text-muted-foreground space-y-1">
            {pollBallots.slice(0, 8).map((b) => {
              const prof = voterProfiles[b.voter_id];
              return (
                <div key={b.id} className="flex justify-between gap-2">
                  <span>{prof?.name ?? b.voter_id.slice(0, 8)}</span>
                  <span>Flat {prof?.flatNumber ?? b.flat_number ?? '—'}</span>
                </div>
              );
            })}
            {pollBallots.length > 8 && <p>+{pollBallots.length - 8} more…</p>}
          </div>
        )}

        {!isResident && poll.is_active && (
          <button type="button" onClick={() => void closePoll(poll)} className="text-xs text-destructive underline mt-3">
            Close election &amp; tally results
          </button>
        )}
      </div>
    );
  };

  return (
    <div className="page-container pb-24">
      <Dialog open={!!voteDetailOption} onOpenChange={(open) => !open && setVoteDetailOption(null)}>
        <DialogContent className="max-h-[85vh] overflow-y-auto sm:max-w-md">
          <DialogHeader>
            <DialogTitle>Votes: {voteDetailOption?.optionText}</DialogTitle>
            <DialogDescription>
              {detailVoters.length > 0
                ? `${detailVoters.length} ${detailVoters.length === 1 ? 'person' : 'people'} chose this option.`
                : 'Individual votes are loaded from the database.'}
            </DialogDescription>
          </DialogHeader>
          {detailVoters.length === 0 ? (
            <p className="text-sm text-muted-foreground">
              No vote rows in the database for this option. Try refreshing; option totals may need to be reconciled.
            </p>
          ) : (
            <ul className="space-y-2 text-sm pr-1">
              {detailVoters.map((v) => {
                const prof = voterProfiles[v.voter_id];
                const flatLabel = prof?.flatNumber || v.flat_number || '—';
                const label =
                  prof?.name ??
                  (String(v.voter_type || '').toLowerCase() === 'resident' ? 'Resident' : v.voter_type || 'Voter');
                return (
                  <li
                    key={v.id}
                    className="flex flex-col gap-0.5 rounded-lg border border-border px-3 py-2 sm:flex-row sm:items-center sm:justify-between"
                  >
                    <span className="font-medium">{label}</span>
                    <span className="text-xs text-muted-foreground">Flat {flatLabel}</span>
                  </li>
                );
              })}
            </ul>
          )}
        </DialogContent>
      </Dialog>

      <div className="flex items-center gap-3 mb-2">
        <div className="w-10 h-10 rounded-xl bg-purple-500/10 flex items-center justify-center">
          <Vote className="w-5 h-5 text-purple-500" />
        </div>
        <div>
          <h1 className="page-title">Polls &amp; Voting</h1>
          <p className="text-[11px] text-muted-foreground">
            <strong>Polls</strong> — single choice per member. <strong>Elections</strong> — ranked choice for MC roles (max 2 ballots per flat).
          </p>
        </div>
      </div>

      <ElectionResultsBanner societyId={societyId} />

      {!isResident && (
        <>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 mb-3">
            <button type="button" onClick={() => setShowForm(!showForm)} className="btn-primary flex items-center justify-center gap-2">
              <Plus className="w-4 h-4" /> New poll
            </button>
            <button
              type="button"
              onClick={() => setShowElectionForm(!showElectionForm)}
              className="btn-secondary border border-border flex items-center justify-center gap-2"
            >
              <Landmark className="w-4 h-4" /> New society election
            </button>
          </div>

          {showForm && (
            <div className="card-section p-4 mb-4 flex flex-col gap-3">
              <p className="text-xs font-semibold text-muted-foreground uppercase">Standard poll</p>
              <input className="input-field" placeholder="Question" value={pf.question} onChange={(e) => setPf({ ...pf, question: e.target.value })} />
              <textarea
                className="input-field"
                placeholder="Description (optional)"
                value={pf.description}
                onChange={(e) => setPf({ ...pf, description: e.target.value })}
              />
              {pf.options.map((o, i) => (
                <div key={i} className="flex gap-2">
                  <input
                    className="input-field flex-1 text-sm"
                    placeholder={`Option ${i + 1}`}
                    value={o}
                    onChange={(e) => {
                      const opts = [...pf.options];
                      opts[i] = e.target.value;
                      setPf({ ...pf, options: opts });
                    }}
                  />
                  {i > 1 && (
                    <button type="button" onClick={() => setPf({ ...pf, options: pf.options.filter((_, j) => j !== i) })} className="text-destructive">
                      <Trash2 className="w-4 h-4" />
                    </button>
                  )}
                </div>
              ))}
              <button type="button" onClick={() => setPf({ ...pf, options: [...pf.options, ''] })} className="text-xs text-primary underline">
                + Add option
              </button>
              <button type="button" onClick={() => void addPoll()} className="btn-primary">
                Create poll
              </button>
            </div>
          )}

          {showElectionForm && (
            <div className="card-section p-4 mb-4 flex flex-col gap-3">
              <p className="text-xs font-semibold text-muted-foreground uppercase">Society election (MC)</p>
              <input
                className="input-field"
                placeholder="Election title (e.g. Managing Committee 2026)"
                value={ef.question}
                onChange={(e) => setEf({ ...ef, question: e.target.value })}
              />
              <textarea
                className="input-field"
                placeholder="Description / rules (optional)"
                value={ef.description}
                onChange={(e) => setEf({ ...ef, description: e.target.value })}
              />
              <label className="text-xs text-muted-foreground">
                Committee seats to fill (min 5)
                <input
                  className="input-field mt-1"
                  type="number"
                  min={5}
                  max={20}
                  value={ef.committeeSeats}
                  onChange={(e) => setEf({ ...ef, committeeSeats: Number(e.target.value) || 5 })}
                />
              </label>

              {(['president', 'secretary', 'treasurer'] as const).map((post) => (
                <div key={post} className="space-y-2">
                  <p className="text-xs font-semibold">{POST_LABEL[post]} candidates</p>
                  {ef[post].map((line, i) => (
                    <div key={`${post}-${i}`} className="flex gap-2">
                      <input
                        className="input-field flex-1 text-sm"
                        placeholder={`Name ${i + 1}`}
                        value={line}
                        onChange={(e) => {
                          const next = [...ef[post]];
                          next[i] = e.target.value;
                          setEf({ ...ef, [post]: next });
                        }}
                      />
                      {ef[post].length > 1 && (
                        <button type="button" onClick={() => setEf({ ...ef, [post]: ef[post].filter((_, j) => j !== i) })} className="text-destructive">
                          <Trash2 className="w-4 h-4" />
                        </button>
                      )}
                    </div>
                  ))}
                  <button type="button" className="text-xs text-primary underline" onClick={() => setEf({ ...ef, [post]: [...ef[post], ''] })}>
                    + Add {POST_LABEL[post]} candidate
                  </button>
                </div>
              ))}

              <div className="space-y-2">
                <p className="text-xs font-semibold">Committee member candidates</p>
                {ef.committee.map((line, i) => (
                  <div key={`com-${i}`} className="flex gap-2">
                    <input
                      className="input-field flex-1 text-sm"
                      placeholder={`Candidate ${i + 1}`}
                      value={line}
                      onChange={(e) => {
                        const next = [...ef.committee];
                        next[i] = e.target.value;
                        setEf({ ...ef, committee: next });
                      }}
                    />
                    {ef.committee.length > 1 && (
                      <button type="button" onClick={() => setEf({ ...ef, committee: ef.committee.filter((_, j) => j !== i) })} className="text-destructive">
                        <Trash2 className="w-4 h-4" />
                      </button>
                    )}
                  </div>
                ))}
                <button type="button" className="text-xs text-primary underline" onClick={() => setEf({ ...ef, committee: [...ef.committee, ''] })}>
                  + Add committee candidate
                </button>
              </div>

              <button type="button" onClick={() => void addElection()} className="btn-primary">
                Create election
              </button>
            </div>
          )}
        </>
      )}

      {electionPolls.length > 0 && (
        <div className="mb-6">
          <h2 className="text-sm font-semibold mb-2 flex items-center gap-2">
            <Landmark className="w-4 h-4" /> Society elections
          </h2>
          {electionPolls.map(renderElectionCard)}
        </div>
      )}

      {standardPolls.length > 0 && (
        <div className="mb-2">
          <h2 className="text-sm font-semibold mb-2">Polls</h2>
        </div>
      )}

      {standardPolls.map((poll) => {
        const pollOpts = options.filter((o) => o.poll_id === poll.id);
        const pollVotes = votes.filter((v) => v.poll_id === poll.id);
        const totalVotes = pollOpts.reduce((s, o) => s + (o.votes_count || 0), 0);
        const hasVoted = votes.some((v) => v.poll_id === poll.id && v.voter_id === voterId);

        return (
          <div key={poll.id} className="card-section p-4 mb-3">
            <div className="flex justify-between items-start mb-2">
              <div>
                <span className="text-[10px] uppercase font-medium text-muted-foreground">Poll</span>
                <p className="font-semibold">{poll.question}</p>
                {poll.description && <p className="text-xs text-muted-foreground">{poll.description}</p>}
              </div>
              <span
                className={`text-[10px] px-2 py-0.5 rounded-full ${poll.is_active ? 'bg-green-500/20 text-green-600' : 'bg-muted text-muted-foreground'}`}
              >
                {poll.is_active ? 'Active' : 'Closed'}
              </span>
            </div>
            <p className="text-xs text-muted-foreground mb-3">{totalVotes} votes</p>

            <div className="space-y-2">
              {pollOpts.map((opt) => {
                const pct = totalVotes > 0 ? ((opt.votes_count || 0) / totalVotes) * 100 : 0;
                return (
                  <div key={opt.id}>
                    {isResident && poll.is_active && !hasVoted ? (
                      <button
                        type="button"
                        onClick={() => void castVote(poll.id, opt.id)}
                        className="w-full text-left p-2 rounded-lg border border-border hover:bg-primary/5 text-sm"
                      >
                        {opt.option_text}
                      </button>
                    ) : (
                      <button
                        type="button"
                        onClick={() => openVoteDetail(opt)}
                        className={`relative w-full rounded-lg bg-muted/50 p-2 text-left overflow-hidden transition ring-offset-background ${
                          (opt.votes_count || 0) > 0 || votes.some((x) => x.option_id === opt.id)
                            ? 'cursor-pointer hover:ring-2 hover:ring-primary/40 focus:outline-none focus:ring-2 focus:ring-primary'
                            : 'cursor-default opacity-90'
                        }`}
                        title={
                          (opt.votes_count || 0) > 0 || votes.some((x) => x.option_id === opt.id) ? 'Who voted for this option?' : undefined
                        }
                      >
                        <div className="absolute inset-0 bg-primary/10 rounded-lg" style={{ width: `${pct}%` }} />
                        <div className="relative flex justify-between gap-2 text-sm">
                          <span>{opt.option_text}</span>
                          <span className="shrink-0 font-mono text-xs">
                            {opt.votes_count || 0} ({pct.toFixed(0)}%)
                          </span>
                        </div>
                      </button>
                    )}
                  </div>
                );
              })}
            </div>

            {!isResident && poll.is_active && (
              <button type="button" onClick={() => void closePoll(poll)} className="text-xs text-destructive underline mt-2">
                Close poll
              </button>
            )}
          </div>
        );
      })}
    </div>
  );
};

export default PollManager;
