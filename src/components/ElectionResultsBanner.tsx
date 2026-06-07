import { useEffect, useState } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { Award } from 'lucide-react';
import type { ElectionResultsPayload } from '@/lib/electionTally';

function isResultsPayload(x: unknown): x is ElectionResultsPayload {
  if (!x || typeof x !== 'object') return false;
  const o = x as Record<string, unknown>;
  return 'president' in o && 'committee' in o;
}

function ResultsBlock({ results }: { results: ElectionResultsPayload }) {
  const line = (label: string, w: { name: string; score: number } | null) =>
    w ? (
      <p className="text-sm">
        <span className="text-muted-foreground">{label}:</span>{' '}
        <span className="font-semibold text-foreground">{w.name}</span>
        <span className="text-[10px] text-muted-foreground ml-1">({w.score} pts)</span>
      </p>
    ) : null;
  return (
    <div className="space-y-0.5 mt-1">
      {line('President', results.president)}
      {line('Vice-President', results.vice_president)}
      {line('Secretary', results.secretary)}
      {line('Treasurer', results.treasurer)}
      {results.committee.length > 0 && (
        <div>
          <p className="text-xs text-muted-foreground mt-1">Committee members</p>
          <ul className="text-sm font-medium list-disc list-inside">
            {results.committee.map((c) => (
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
}

/** Latest closed society elections — admin portal only until published to committee. */
export function ElectionResultsBanner({
  societyId,
  adminOnly = false,
}: {
  societyId: string | null;
  adminOnly?: boolean;
}) {
  const [rows, setRows] = useState<{ id: string; question: string; election_results: unknown }[]>([]);

  useEffect(() => {
    if (!societyId || !adminOnly) {
      setRows([]);
      return;
    }
    let cancelled = false;
    void (async () => {
      const { data } = await supabase
        .from('polls')
        .select('id, question, election_results, election_phase, election_applied_at')
        .eq('society_id', societyId)
        .eq('poll_kind', 'election')
        .in('election_phase', ['closed', 'applied'])
        .not('election_results', 'is', null)
        .order('created_at', { ascending: false })
        .limit(3);
      if (!cancelled) setRows((data ?? []) as { id: string; question: string; election_results: unknown }[]);
    })();
    return () => {
      cancelled = true;
    };
  }, [societyId, adminOnly]);

  const valid = rows.filter((r) => isResultsPayload(r.election_results));
  if (!adminOnly || valid.length === 0) return null;

  return (
    <div className="mb-4 rounded-xl border border-primary/25 bg-primary/5 p-3 space-y-3">
      <div className="flex items-center gap-2">
        <Award className="w-5 h-5 text-primary shrink-0" />
        <p className="text-sm font-semibold">Election results (admin only)</p>
      </div>
      {valid.map((r) => (
        <div key={r.id} className="rounded-lg bg-card/80 border border-border p-3">
          <p className="text-xs font-medium text-muted-foreground uppercase tracking-wide">Election</p>
          <p className="font-semibold text-sm mt-0.5">{r.question}</p>
          <ResultsBlock results={r.election_results as ElectionResultsPayload} />
        </div>
      ))}
      <p className="text-[10px] text-muted-foreground">Publish winners to the Committee module when ready. Residents see the roster only after publish.</p>
    </div>
  );
}
