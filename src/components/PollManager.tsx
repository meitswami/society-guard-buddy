import { useState, useEffect } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { Vote, Plus, BarChart3, Trash2 } from 'lucide-react';
import { toast } from 'sonner';

interface Props { adminName?: string; isResident?: boolean; voterId?: string; flatNumber?: string; }

const PollManager = ({ adminName = 'Admin', isResident = false, voterId = '', flatNumber = '' }: Props) => {
  const [polls, setPolls] = useState<any[]>([]);
  const [options, setOptions] = useState<any[]>([]);
  const [votes, setVotes] = useState<any[]>([]);
  const [showForm, setShowForm] = useState(false);
  const [pf, setPf] = useState({ question: '', description: '', options: ['', ''] });

  useEffect(() => { loadAll(); }, []);
  const loadAll = async () => {
    const [p, o, v] = await Promise.all([
      supabase.from('polls').select('*').order('created_at', { ascending: false }),
      supabase.from('poll_options').select('*'),
      supabase.from('poll_votes').select('*'),
    ]);
    if (p.data) setPolls(p.data);
    if (o.data) setOptions(o.data);
    if (v.data) setVotes(v.data);
  };

  const addPoll = async () => {
    if (!pf.question || pf.options.filter(o => o.trim()).length < 2) return;
    const { data: poll } = await supabase.from('polls').insert([{
      question: pf.question, description: pf.description || null, created_by: adminName,
    }]).select().single();
    if (poll) {
      const opts = pf.options.filter(o => o.trim()).map(o => ({ poll_id: poll.id, option_text: o.trim() }));
      await supabase.from('poll_options').insert(opts);
    }
    setPf({ question: '', description: '', options: ['', ''] });
    setShowForm(false); toast.success('Poll created'); loadAll();
    // Notify
    await supabase.from('notifications').insert([{
      title: 'New Poll', message: `Vote now: ${pf.question}`, type: 'poll', target_type: 'all', created_by: adminName,
    }]);
  };

  const castVote = async (pollId: string, optionId: string) => {
    const existing = votes.find(v => v.poll_id === pollId && v.voter_id === voterId);
    if (existing) { toast.error('Already voted'); return; }
    await supabase.from('poll_votes').insert([{
      poll_id: pollId, option_id: optionId, voter_id: voterId, voter_type: 'resident', flat_number: flatNumber,
    }]);
    await supabase.from('poll_options').update({ votes_count: (options.find(o => o.id === optionId)?.votes_count || 0) + 1 }).eq('id', optionId);
    toast.success('Vote cast!'); loadAll();
  };

  const closePoll = async (id: string) => {
    await supabase.from('polls').update({ is_active: false }).eq('id', id);
    toast.success('Poll closed'); loadAll();
  };

  return (
    <div className="page-container pb-24">
      <div className="flex items-center gap-3 mb-4">
        <div className="w-10 h-10 rounded-xl bg-purple-500/10 flex items-center justify-center">
          <Vote className="w-5 h-5 text-purple-500" />
        </div>
        <h1 className="page-title">Polls & Voting</h1>
      </div>

      {!isResident && (
        <>
          <button onClick={() => setShowForm(!showForm)} className="btn-primary w-full mb-4 flex items-center justify-center gap-2">
            <Plus className="w-4 h-4" /> Create Poll
          </button>
          {showForm && (
            <div className="card-section p-4 mb-4 flex flex-col gap-3">
              <input className="input-field" placeholder="Question" value={pf.question} onChange={e => setPf({...pf, question: e.target.value})} />
              <textarea className="input-field" placeholder="Description (optional)" value={pf.description} onChange={e => setPf({...pf, description: e.target.value})} />
              {pf.options.map((o, i) => (
                <div key={i} className="flex gap-2">
                  <input className="input-field flex-1 text-sm" placeholder={`Option ${i + 1}`} value={o}
                    onChange={e => { const opts = [...pf.options]; opts[i] = e.target.value; setPf({...pf, options: opts}); }} />
                  {i > 1 && <button onClick={() => setPf({...pf, options: pf.options.filter((_, j) => j !== i)})} className="text-destructive"><Trash2 className="w-4 h-4" /></button>}
                </div>
              ))}
              <button onClick={() => setPf({...pf, options: [...pf.options, '']})} className="text-xs text-primary underline">+ Add Option</button>
              <button onClick={addPoll} className="btn-primary">Create Poll</button>
            </div>
          )}
        </>
      )}

      {polls.map(poll => {
        const pollOpts = options.filter(o => o.poll_id === poll.id);
        const pollVotes = votes.filter(v => v.poll_id === poll.id);
        const totalVotes = pollOpts.reduce((s, o) => s + (o.votes_count || 0), 0);
        const hasVoted = votes.some(v => v.poll_id === poll.id && v.voter_id === voterId);

        return (
          <div key={poll.id} className="card-section p-4 mb-3">
            <div className="flex justify-between items-start mb-2">
              <div>
                <p className="font-semibold">{poll.question}</p>
                {poll.description && <p className="text-xs text-muted-foreground">{poll.description}</p>}
              </div>
              <span className={`text-[10px] px-2 py-0.5 rounded-full ${poll.is_active ? 'bg-green-500/20 text-green-600' : 'bg-muted text-muted-foreground'}`}>
                {poll.is_active ? 'Active' : 'Closed'}
              </span>
            </div>
            <p className="text-xs text-muted-foreground mb-3">{totalVotes} votes</p>

            <div className="space-y-2">
              {pollOpts.map(opt => {
                const pct = totalVotes > 0 ? ((opt.votes_count || 0) / totalVotes * 100) : 0;
                return (
                  <div key={opt.id}>
                    {isResident && poll.is_active && !hasVoted ? (
                      <button onClick={() => castVote(poll.id, opt.id)} className="w-full text-left p-2 rounded-lg border border-border hover:bg-primary/5 text-sm">
                        {opt.option_text}
                      </button>
                    ) : (
                      <div className="relative p-2 rounded-lg bg-muted/50 overflow-hidden">
                        <div className="absolute inset-0 bg-primary/10 rounded-lg" style={{ width: `${pct}%` }} />
                        <div className="relative flex justify-between text-sm">
                          <span>{opt.option_text}</span>
                          <span className="font-mono text-xs">{opt.votes_count || 0} ({pct.toFixed(0)}%)</span>
                        </div>
                      </div>
                    )}
                  </div>
                );
              })}
            </div>

            {!isResident && poll.is_active && (
              <button onClick={() => closePoll(poll.id)} className="text-xs text-destructive underline mt-2">Close Poll</button>
            )}
          </div>
        );
      })}
    </div>
  );
};

export default PollManager;
