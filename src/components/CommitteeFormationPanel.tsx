import { useState } from 'react';
import { Users, UserPlus } from 'lucide-react';
import { toast } from 'sonner';
import { supabase } from '@/integrations/supabase/client';
import { PersonPhotoSide } from '@/components/PersonPhotoSide';
import {
  emptyFormationState,
  type CommitteeFormationState,
  type ElectionResultsPayload,
  type FormationMember,
} from '@/lib/electionTally';
import { countFormedCommittee } from '@/lib/electionApply';
import {
  DEFAULT_TARGET_COMMITTEE_SIZE,
  MIN_COMMITTEE_SIZE,
} from '@/lib/electionGovernance';

type Props = {
  poll: {
    id: string;
    election_results: ElectionResultsPayload | null;
    target_committee_size?: number | null;
  };
  isResident: boolean;
  memberName?: string;
  flatNumber?: string;
  flatId?: string;
  memberId?: string;
  optionMemberIds?: Record<string, string>;
  photoByMemberId?: Record<string, string>;
  onReload: () => void;
};

function formationOf(results: ElectionResultsPayload | null | undefined): CommitteeFormationState {
  return results?.formation ?? emptyFormationState();
}

/**
 * Vacancy fill after tally — bye-laws: majority of remaining committee (not runner-up seating).
 * Voluntary interest + admin-proposed names only; no 2nd/3rd-place checkboxes.
 */
const CommitteeFormationPanel = ({
  poll,
  isResident,
  memberName = '',
  flatNumber = '',
  flatId = '',
  memberId = '',
  photoByMemberId = {},
  onReload,
}: Props) => {
  const [execName, setExecName] = useState('');
  const [execFlat, setExecFlat] = useState('');
  const [saving, setSaving] = useState(false);

  const results = poll.election_results;
  if (!results || typeof results !== 'object') return null;

  const target = Number(poll.target_committee_size) || DEFAULT_TARGET_COMMITTEE_SIZE;
  const formation = formationOf(results);
  const formed = countFormedCommittee(results);
  const remaining = Math.max(0, target - formed);

  const persistFormation = async (next: CommitteeFormationState) => {
    setSaving(true);
    const nextResults: ElectionResultsPayload = { ...results, formation: next };
    const { error } = await supabase
      .from('polls')
      .update({ election_results: nextResults as unknown as Record<string, unknown> })
      .eq('id', poll.id);
    setSaving(false);
    if (error) {
      toast.error(error.message);
      return;
    }
    toast.success('Committee formation updated');
    onReload();
  };

  const volunteerSelf = () => {
    if (!memberName.trim()) {
      toast.error('Your member profile is required to volunteer.');
      return;
    }
    const key = `vol-${memberId || memberName}-${flatNumber}`;
    if ((formation.voluntary ?? []).some((v) => v.key === key || (memberId && v.member_id === memberId))) {
      toast.error('You are already listed as a volunteer.');
      return;
    }
    const row: FormationMember = {
      key,
      name: memberName.trim(),
      flat_number: flatNumber || null,
      flat_id: flatId || null,
      member_id: memberId || null,
      source: 'voluntary',
    };
    void persistFormation({ ...formation, voluntary: [...(formation.voluntary ?? []), row] });
  };

  const removeVoluntary = (key: string) => {
    if (isResident) return;
    void persistFormation({
      ...formation,
      voluntary: (formation.voluntary ?? []).filter((v) => v.key !== key),
    });
  };

  const addExecutiveProposed = () => {
    if (!execName.trim()) {
      toast.error('Enter a member name.');
      return;
    }
    const key = `exec-${Date.now()}-${execName.trim()}`;
    const row: FormationMember = {
      key,
      name: execName.trim(),
      flat_number: execFlat.trim() || null,
      source: 'executive_proposed',
    };
    setExecName('');
    setExecFlat('');
    void persistFormation({
      ...formation,
      executive_proposed: [...(formation.executive_proposed ?? []), row],
    });
  };

  const removeExec = (key: string) => {
    void persistFormation({
      ...formation,
      executive_proposed: (formation.executive_proposed ?? []).filter((e) => e.key !== key),
    });
  };

  const alreadyVolunteered =
    !!memberId &&
    (formation.voluntary ?? []).some((v) => v.member_id === memberId || v.name === memberName);

  return (
    <div className="mt-3 rounded-lg border border-amber-500/35 bg-amber-500/5 p-3 space-y-3">
      <div className="flex items-start gap-2">
        <Users className="w-4 h-4 text-amber-700 shrink-0 mt-0.5" />
        <div>
          <p className="text-xs font-semibold text-amber-900 dark:text-amber-200 uppercase tracking-wide">
            Management Committee ({MIN_COMMITTEE_SIZE} seats)
          </p>
          <p className="text-[11px] text-muted-foreground mt-0.5">
            Progress: <strong className="text-foreground">{formed}</strong> / {target}.{' '}
            {remaining > 0
              ? `${remaining} seat(s) open — fill by vacancy procedure (majority of remaining committee), not runner-up seating.`
              : 'Full roster.'}
          </p>
        </div>
      </div>

      <div>
        <p className="text-[11px] font-semibold text-foreground mb-1">Voluntary interest</p>
        {(formation.voluntary ?? []).length === 0 ? (
          <p className="text-[11px] text-muted-foreground">No volunteers yet.</p>
        ) : (
          <ul className="space-y-1 text-xs">
            {(formation.voluntary ?? []).map((v) => (
              <li key={v.key} className="flex justify-between gap-2 items-center">
                <PersonPhotoSide
                  name={v.name}
                  photo={v.member_id ? photoByMemberId[v.member_id] : undefined}
                  size="sm"
                  className="flex-1"
                >
                  <span>
                    {v.name}
                    {v.flat_number ? ` · Flat ${v.flat_number}` : ''}
                  </span>
                </PersonPhotoSide>
                {!isResident && (
                  <button type="button" className="text-destructive underline text-[10px]" onClick={() => removeVoluntary(v.key)}>
                    Remove
                  </button>
                )}
              </li>
            ))}
          </ul>
        )}
        {isResident && remaining > 0 && !alreadyVolunteered && (
          <button
            type="button"
            disabled={saving}
            onClick={() => volunteerSelf()}
            className="mt-2 text-xs px-2.5 py-1.5 rounded-lg bg-amber-600 text-white inline-flex items-center gap-1"
          >
            <UserPlus className="w-3.5 h-3.5" /> I volunteer for the Committee
          </button>
        )}
      </div>

      {!isResident && (
        <div>
          <p className="text-[11px] font-semibold text-foreground mb-1">Proposed for vacancy fill</p>
          {(formation.executive_proposed ?? []).length > 0 && (
            <ul className="space-y-1 text-xs mb-2">
              {(formation.executive_proposed ?? []).map((e) => (
                <li key={e.key} className="flex justify-between gap-2 items-center">
                  <PersonPhotoSide
                    name={e.name}
                    photo={e.member_id ? photoByMemberId[e.member_id] : undefined}
                    size="sm"
                    className="flex-1"
                  >
                    <span>
                      {e.name}
                      {e.flat_number ? ` · Flat ${e.flat_number}` : ''}
                    </span>
                  </PersonPhotoSide>
                  <button type="button" className="text-destructive underline text-[10px]" onClick={() => removeExec(e.key)}>
                    Remove
                  </button>
                </li>
              ))}
            </ul>
          )}
          {remaining > 0 && (
            <div className="flex flex-wrap gap-2 items-end">
              <div className="min-w-[140px] flex-1">
                <label className="text-[10px] text-muted-foreground">Name</label>
                <input
                  className="input-field mt-0.5"
                  value={execName}
                  onChange={(e) => setExecName(e.target.value)}
                  placeholder="Member name"
                />
              </div>
              <div className="w-24">
                <label className="text-[10px] text-muted-foreground">Flat</label>
                <input
                  className="input-field mt-0.5"
                  value={execFlat}
                  onChange={(e) => setExecFlat(e.target.value)}
                  placeholder="e.g. A-12"
                />
              </div>
              <button
                type="button"
                disabled={saving}
                onClick={() => addExecutiveProposed()}
                className="text-xs px-2.5 py-1.5 rounded-lg border border-border"
              >
                Propose
              </button>
            </div>
          )}
        </div>
      )}

      {formed < MIN_COMMITTEE_SIZE && (
        <p className="text-[11px] text-amber-800 dark:text-amber-200">
          Bye-laws require {MIN_COMMITTEE_SIZE} Management Committee members before publishing the roster.
        </p>
      )}
    </div>
  );
};

export default CommitteeFormationPanel;
