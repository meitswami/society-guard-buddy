import { useState, useEffect, useMemo } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useStore } from '@/store/useStore';
import { Vote, Plus, Trash2, Landmark, ListChecks } from 'lucide-react';
import { toast } from 'sonner';
import { confirmAction, showSuccess } from '@/lib/swal';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { ElectionResultsBanner } from '@/components/ElectionResultsBanner';
import ElectionModule from '@/components/ElectionModule';
import { invokePushNotification } from '@/lib/pushNotification';

interface Props {
  adminName?: string;
  isResident?: boolean;
  voterId?: string;
  voterPhone?: string;
  memberId?: string;
  memberName?: string;
  flatNumber?: string;
  /** Flat UUID — required to enforce max 2 ballots per flat for elections. */
  flatId?: string;
}

type VoterProfile = { name: string; flatNumber: string };

function normKind(row: { poll_kind?: string | null }): 'standard' | 'election' {
  return row.poll_kind === 'election' ? 'election' : 'standard';
}

const PollManager = ({
  adminName = 'Admin',
  isResident = false,
  voterId = '',
  voterPhone = '',
  memberId = '',
  memberName = '',
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
  const [sectionTab, setSectionTab] = useState<'elections' | 'polls'>('elections');
  const [showForm, setShowForm] = useState(false);
  const [pf, setPf] = useState({ question: '', description: '', options: ['', ''] });

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

  const activeElections = useMemo(
    () => electionPolls.filter((p) => p.is_active || (p.election_phase && p.election_phase !== 'applied')),
    [electionPolls],
  );

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
    if (societyId) {
      await invokePushNotification({
        title: 'New Poll',
        message: `Vote now: ${notifyTitle}`,
        target_type: 'all',
        society_id: societyId,
      });
    }
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

  const closePoll = async (poll: any) => {
    const ok = await confirmAction('Close Poll?', 'This will stop accepting new votes.', 'Yes, Close', 'Cancel');
    if (!ok) return;
    await supabase.from('polls').update({ is_active: false }).eq('id', poll.id);
    showSuccess('Closed!', 'Poll has been closed');
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

      <div className="flex items-center gap-3 mb-3">
        <div className="w-10 h-10 rounded-xl bg-purple-500/10 flex items-center justify-center">
          <Vote className="w-5 h-5 text-purple-500" />
        </div>
        <div>
          <h1 className="page-title">Polls &amp; Elections</h1>
          <p className="text-[11px] text-muted-foreground">
            Two sections: <strong>Society Elections</strong> (committee posts, ranked voting) and <strong>General Polls</strong> (single-choice questions).
          </p>
        </div>
      </div>

      {/* Section switcher */}
      <div className="flex gap-2 mb-4 p-1 bg-muted rounded-xl">
        <button
          type="button"
          onClick={() => setSectionTab('elections')}
          className={`flex-1 flex items-center justify-center gap-1.5 py-2.5 px-3 rounded-lg text-xs font-medium transition-all ${
            sectionTab === 'elections' ? 'bg-primary text-primary-foreground shadow-sm' : 'text-muted-foreground hover:text-foreground'
          }`}
        >
          <Landmark className="w-3.5 h-3.5 shrink-0" />
          Society Elections
          {activeElections.length > 0 && (
            <span className={`text-[10px] px-1.5 py-0.5 rounded-full ${sectionTab === 'elections' ? 'bg-primary-foreground/20' : 'bg-primary/15 text-primary'}`}>
              {activeElections.length}
            </span>
          )}
        </button>
        <button
          type="button"
          onClick={() => setSectionTab('polls')}
          className={`flex-1 flex items-center justify-center gap-1.5 py-2.5 px-3 rounded-lg text-xs font-medium transition-all ${
            sectionTab === 'polls' ? 'bg-primary text-primary-foreground shadow-sm' : 'text-muted-foreground hover:text-foreground'
          }`}
        >
          <ListChecks className="w-3.5 h-3.5 shrink-0" />
          General Polls
          {standardPolls.filter((p) => p.is_active).length > 0 && (
            <span className={`text-[10px] px-1.5 py-0.5 rounded-full ${sectionTab === 'polls' ? 'bg-primary-foreground/20' : 'bg-primary/15 text-primary'}`}>
              {standardPolls.filter((p) => p.is_active).length}
            </span>
          )}
        </button>
      </div>

      {sectionTab === 'elections' && (
        <div className="space-y-3">
          {!isResident && <ElectionResultsBanner societyId={societyId} adminOnly />}
          <ElectionModule
            embedded
            adminName={adminName}
            isResident={isResident}
            societyId={societyId}
            voterId={voterId}
            voterPhone={voterPhone}
            memberId={memberId}
            memberName={memberName}
            flatNumber={flatNumber}
            flatId={flatId}
            electionPolls={electionPolls}
            options={options}
            ballots={ballots}
            voterProfiles={voterProfiles}
            onReload={loadAll}
          />
        </div>
      )}

      {sectionTab === 'polls' && (
        <div className="space-y-3">
          <div className="rounded-lg border border-border/80 bg-card/40 p-3">
            <p className="text-xs text-muted-foreground">
              General polls are for society questions and feedback — one option per member. For managing-committee posts use <button type="button" className="text-primary underline font-medium" onClick={() => setSectionTab('elections')}>Society Elections</button>.
            </p>
          </div>

          {!isResident && (
            <>
              <button
                type="button"
                onClick={() => setShowForm(!showForm)}
                className="btn-primary flex items-center justify-center gap-2 w-full sm:w-auto"
              >
                <Plus className="w-4 h-4" /> New general poll
              </button>

              {showForm && (
                <div className="card-section p-4 flex flex-col gap-3">
                  <p className="text-xs font-semibold text-muted-foreground uppercase">New general poll</p>
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
            </>
          )}

          {standardPolls.length === 0 ? (
            <div className="card-section p-6 text-center">
              <ListChecks className="w-8 h-8 text-muted-foreground mx-auto mb-2 opacity-50" />
              <p className="text-sm text-muted-foreground">No general polls yet.</p>
              {isResident && <p className="text-xs text-muted-foreground mt-1">The admin will create polls for society questions here.</p>}
            </div>
          ) : (
            standardPolls.map((poll) => {
        const pollOpts = options.filter((o) => o.poll_id === poll.id);
        const pollVotes = votes.filter((v) => v.poll_id === poll.id);
        const totalVotes = pollOpts.reduce((s, o) => s + (o.votes_count || 0), 0);
        const hasVoted = votes.some((v) => v.poll_id === poll.id && v.voter_id === voterId);

        return (
          <div key={poll.id} className="card-section p-4 mb-3">
            <div className="flex justify-between items-start mb-2">
              <div>
                <span className="text-[10px] uppercase font-medium text-muted-foreground">General poll</span>
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
            })
          )}
        </div>
      )}
    </div>
  );
};

export default PollManager;
