import { useEffect, useMemo, useState } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { Award } from 'lucide-react';
import type { ElectionResultsPayload } from '@/lib/electionTally';
import { PersonPhotoSide } from '@/components/PersonPhotoSide';
import { fetchMemberPhotoMap } from '@/lib/memberPhotos';

function isResultsPayload(x: unknown): x is ElectionResultsPayload {
  if (!x || typeof x !== 'object') return false;
  const o = x as Record<string, unknown>;
  return 'president' in o && 'committee' in o;
}

function ResultsBlock({
  results,
  optionMemberIds,
  photoByMemberId,
}: {
  results: ElectionResultsPayload;
  optionMemberIds: Record<string, string>;
  photoByMemberId: Record<string, string>;
}) {
  const photoFor = (optionId?: string) => {
    if (!optionId) return undefined;
    const mid = optionMemberIds[optionId];
    return mid ? photoByMemberId[mid] : undefined;
  };
  const line = (label: string, w: { name: string; score: number; option_id: string } | null) =>
    w ? (
      <PersonPhotoSide name={w.name} photo={photoFor(w.option_id)} size="sm" className="py-0.5">
        <p className="text-sm leading-snug">
          <span className="text-muted-foreground">{label}:</span>{' '}
          <span className="font-semibold text-foreground">{w.name}</span>
          <span className="text-[10px] text-muted-foreground ml-1">({w.score} votes)</span>
        </p>
      </PersonPhotoSide>
    ) : null;
  return (
    <div className="space-y-1 mt-1">
      {line('President', results.president)}
      {line('Vice-President', results.vice_president)}
      {line('Secretary', results.secretary)}
      {line('Treasurer', results.treasurer)}
      {results.committee?.length > 0 && (
        <div className="space-y-1 pt-1">
          <p className="text-xs text-muted-foreground">Executive Members</p>
          {results.committee.map((c) => (
            <PersonPhotoSide key={c.option_id} name={c.name} photo={photoFor(c.option_id)} size="sm">
              <p className="text-sm font-medium leading-snug">
                {c.name}
                <span className="text-[10px] text-muted-foreground font-normal ml-1">({c.score} votes)</span>
              </p>
            </PersonPhotoSide>
          ))}
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
  const [optionMemberIds, setOptionMemberIds] = useState<Record<string, string>>({});
  const [photoByMemberId, setPhotoByMemberId] = useState<Record<string, string>>({});

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
      if (cancelled) return;
      const pollRows = (data ?? []) as { id: string; question: string; election_results: unknown }[];
      setRows(pollRows);
      const pollIds = pollRows.map((r) => r.id);
      if (pollIds.length === 0) {
        setOptionMemberIds({});
        setPhotoByMemberId({});
        return;
      }
      const { data: opts } = await supabase
        .from('poll_options')
        .select('id, member_id')
        .in('poll_id', pollIds);
      if (cancelled) return;
      const midMap: Record<string, string> = {};
      for (const o of opts ?? []) {
        if (o.member_id) midMap[o.id as string] = o.member_id as string;
      }
      setOptionMemberIds(midMap);
      const photos = await fetchMemberPhotoMap(Object.values(midMap));
      if (!cancelled) setPhotoByMemberId(photos);
    })();
    return () => {
      cancelled = true;
    };
  }, [societyId, adminOnly]);

  const valid = useMemo(() => rows.filter((r) => isResultsPayload(r.election_results)), [rows]);
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
          <ResultsBlock
            results={r.election_results as ElectionResultsPayload}
            optionMemberIds={optionMemberIds}
            photoByMemberId={photoByMemberId}
          />
        </div>
      ))}
      <p className="text-[10px] text-muted-foreground">
        Publish winners to the Committee module when ready. Residents see the roster only after publish. Photos fill
        from each member&apos;s profile in My Family &amp; Staff.
      </p>
    </div>
  );
}
