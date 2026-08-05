import { useCallback, useEffect, useState } from 'react';
import { toast } from 'sonner';
import { confirmAction } from '@/lib/swal';
import { supabase } from '@/integrations/supabase/client';
import type { ElectionVotingMethod } from '@/lib/electionGovernance';
import {
  VOTING_METHOD_OPTIONS,
  fetchVotingMethodConsents,
  finalizeVotingMethodFromConsent,
  leadingConsentMethod,
  openVotingMethodConsent,
  submitVotingMethodConsent,
  tallyFromConsents,
  type VotingMethodConsentRow,
} from '@/lib/electionVotingMethodConsent';
import { recordElectionVotingMethod } from '@/lib/electionAudit';
import { useLanguage } from '@/i18n/LanguageContext';

type Props = {
  poll: {
    id: string;
    voting_method?: string | null;
    voting_method_recorded_by?: string | null;
    voting_method_consent_open?: boolean | null;
    separate_office_votes?: boolean | null;
    election_quorum_required?: number | null;
    member_count_at_election?: number | null;
  };
  societyId: string | null;
  isResident: boolean;
  adminName?: string;
  memberId?: string;
  memberName?: string;
  flatNumber?: string;
  onReload: () => void;
};

/**
 * Record Secret Ballot / Show of Hands before polling (bye-laws).
 * Optional member consent (A/B); admin may finalize by meeting resolution.
 */
const VotingMethodConsentPanel = ({
  poll,
  societyId,
  isResident,
  adminName = 'Admin',
  memberId = '',
  memberName = '',
  flatNumber = '',
  onReload,
}: Props) => {
  const { lang } = useLanguage();
  const hi = lang === 'hi';
  const [rows, setRows] = useState<VotingMethodConsentRow[]>([]);
  const [eligibleCount, setEligibleCount] = useState<number | null>(null);
  const [busy, setBusy] = useState(false);
  const [separateOffice, setSeparateOffice] = useState(Boolean(poll.separate_office_votes));

  const load = useCallback(async () => {
    const { rows: r, error } = await fetchVotingMethodConsents(poll.id);
    if (error) toast.error(error);
    else setRows(r);

    if (societyId) {
      const { count } = await supabase
        .from('members')
        .select('id, flats!inner(society_id)', { count: 'exact', head: true })
        .eq('flats.society_id', societyId)
        .is('date_leave', null);
      setEligibleCount(count ?? null);
    }
  }, [poll.id, societyId]);

  useEffect(() => {
    void load();
  }, [load]);

  const tally = tallyFromConsents(rows);
  const myConsent = memberId ? rows.find((r) => r.member_id === memberId) : undefined;
  const leading = leadingConsentMethod(tally);
  const allConsented =
    eligibleCount != null && eligibleCount > 0 && tally.total >= eligibleCount;
  const finalized = Boolean(poll.voting_method);

  const optLabel = (method: ElectionVotingMethod) => {
    const o = VOTING_METHOD_OPTIONS[method];
    return hi ? o.titleHi : o.titleEn;
  };

  const openConsent = async () => {
    if (!societyId) return;
    const ok = await confirmAction(
      hi ? 'सदस्य सहमति खोलें?' : 'Open member consent?',
      hi
        ? 'सदस्य विकल्प A (गुप्त मतपत्र) या विकल्प B (हाथ उठाकर) देखकर सहमति देंगे।'
        : 'Members will see Option A (Secret Ballot) and Option B (Show of Hands) and may record consent.',
      hi ? 'खोलें' : 'Open consent',
      hi ? 'रद्द' : 'Cancel',
    );
    if (!ok) return;
    setBusy(true);
    const { error } = await openVotingMethodConsent({
      pollId: poll.id,
      societyId,
      openedBy: adminName,
    });
    setBusy(false);
    if (error) toast.error(error);
    else {
      toast.success(hi ? 'सहमति खुली' : 'Member consent opened');
      onReload();
    }
  };

  const castConsent = async (method: ElectionVotingMethod) => {
    if (!societyId || !memberId) {
      toast.error(hi ? 'सदस्य प्रोफ़ाइल आवश्यक है।' : 'Member profile required.');
      return;
    }
    setBusy(true);
    const { error } = await submitVotingMethodConsent({
      societyId,
      pollId: poll.id,
      memberId,
      choice: method,
      memberName,
      flatNumber,
    });
    setBusy(false);
    if (error) toast.error(error);
    else {
      toast.success(hi ? 'सहमति दर्ज' : 'Consent recorded');
      void load();
    }
  };

  const finalizeFromConsent = async (method: ElectionVotingMethod, allowPartial: boolean) => {
    if (!societyId || eligibleCount == null) return;
    const ok = await confirmAction(
      hi ? 'मतदान विधि अंतिम करें?' : 'Finalize voting method?',
      hi
        ? `विधि: ${optLabel(method)}${allowPartial ? ' (आंशिक सहमति / बैठक प्रस्ताव)' : ''}`
        : `Method: ${optLabel(method)}${allowPartial ? ' (partial consent / meeting resolution)' : ''}`,
      hi ? 'अंतिम करें' : 'Finalize',
      hi ? 'रद्द' : 'Cancel',
    );
    if (!ok) return;
    setBusy(true);
    const { error } = await finalizeVotingMethodFromConsent({
      pollId: poll.id,
      societyId,
      method,
      recordedBy: adminName,
      eligibleMemberCount: eligibleCount,
      consentTotal: tally.total,
      allowPartial,
      separateOfficeVotes: separateOffice,
    });
    setBusy(false);
    if (error) toast.error(error);
    else {
      toast.success(
        method === 'secret_ballot'
          ? hi
            ? 'विकल्प A अंतिम — गुप्त मतपत्र'
            : 'Option A finalized — Secret Ballot'
          : hi
            ? 'विकल्प B अंतिम — हाथ उठाकर'
            : 'Option B finalized — Show of Hands',
      );
      onReload();
    }
  };

  /** Admin records method by meeting resolution (no full-member consent required). */
  const recordByResolution = async (method: ElectionVotingMethod) => {
    const ok = await confirmAction(
      hi ? 'बैठक प्रस्ताव से विधि दर्ज करें?' : 'Record method by meeting resolution?',
      hi
        ? `${optLabel(method)}. मतदान खोलने से पहले विधि दर्ज होनी चाहिए।`
        : `${optLabel(method)}. Method must be recorded before polling opens.`,
      hi ? 'दर्ज करें' : 'Record',
      hi ? 'रद्द' : 'Cancel',
    );
    if (!ok) return;
    setBusy(true);
    const { error } = await recordElectionVotingMethod({
      pollId: poll.id,
      method,
      recordedBy: adminName,
      separateOfficeVotes: separateOffice,
    });
    if (!error) {
      await supabase.from('polls').update({ voting_method_consent_open: false }).eq('id', poll.id);
    }
    setBusy(false);
    if (error) toast.error(error);
    else {
      toast.success(hi ? 'मतदान विधि दर्ज' : 'Voting method recorded');
      onReload();
    }
  };

  return (
    <div className="mt-3 rounded-lg border border-border/70 bg-muted/20 p-3 space-y-3">
      <div>
        <p className="text-xs font-semibold text-foreground">
          {hi ? 'मतदान विधि — विकल्प A या B' : 'Voting method — Option A or B'}
        </p>
        <p className="text-[11px] text-muted-foreground mt-0.5">
          {hi
            ? 'उपविधि दोनों विधियाँ अनुमति देती है। मतदान खोलने से पहले विधि दर्ज करें।'
            : 'Bye-laws permit both methods. Record the method before opening the poll.'}
        </p>
      </div>

      <div className="grid gap-2 sm:grid-cols-2">
        {(['secret_ballot', 'show_of_hands'] as const).map((method) => {
          const o = VOTING_METHOD_OPTIONS[method];
          const count = method === 'secret_ballot' ? tally.secret_ballot : tally.show_of_hands;
          const selected = myConsent?.choice === method;
          return (
            <div
              key={method}
              className={`rounded-lg border p-2.5 space-y-1.5 ${
                selected ? 'border-indigo-500 bg-indigo-500/10' : 'border-border/60 bg-background/50'
              }`}
            >
              <p className="text-xs font-semibold text-foreground">{hi ? o.titleHi : o.titleEn}</p>
              <p className="text-[11px] text-muted-foreground leading-relaxed">
                {hi ? o.effectHi : o.effectEn}
              </p>
              {poll.voting_method_consent_open && (
                <p className="text-[10px] text-muted-foreground">
                  {hi ? 'सहमति' : 'Consents'}: <strong className="text-foreground">{count}</strong>
                </p>
              )}
              {isResident && poll.voting_method_consent_open && !finalized && !myConsent && (
                <button
                  type="button"
                  disabled={busy}
                  onClick={() => void castConsent(method)}
                  className="text-xs px-2.5 py-1.5 rounded-lg bg-indigo-600 text-white w-full"
                >
                  {hi ? `विकल्प ${o.code} को सहमति` : `Consent to Option ${o.code}`}
                </button>
              )}
              {selected && (
                <p className="text-[10px] text-emerald-700 dark:text-emerald-300 font-medium">
                  {hi ? 'आपकी सहमति दर्ज है' : 'Your consent is recorded'}
                </p>
              )}
            </div>
          );
        })}
      </div>

      {poll.voting_method_consent_open && !finalized && (
        <p className="text-[11px] text-muted-foreground">
          {hi ? 'प्रगति' : 'Progress'}:{' '}
          <strong className="text-foreground">
            {tally.total}
            {eligibleCount != null ? ` / ${eligibleCount}` : ''}
          </strong>{' '}
          {hi ? 'पात्र सदस्यों ने सहमति दी' : 'eligible members consented'}
          {leading ? (
            <>
              {' · '}
              {hi ? 'अग्रणी' : 'Leading'}: {optLabel(leading)}
            </>
          ) : null}
        </p>
      )}

      {finalized ? (
        <p className="text-xs text-emerald-700 dark:text-emerald-300">
          {hi ? 'अंतिम विधि' : 'Finalized'}:{' '}
          <strong>{optLabel(poll.voting_method as ElectionVotingMethod)}</strong>
          {poll.voting_method_recorded_by ? ` · ${poll.voting_method_recorded_by}` : ''}
          {poll.separate_office_votes
            ? hi
              ? ' · प्रति-पद मत अनुमोदित'
              : ' · separate office votes approved'
            : ''}
        </p>
      ) : (
        !isResident && (
          <div className="space-y-2">
            <label className="text-[11px] flex items-center gap-1.5">
              <input
                type="checkbox"
                checked={separateOffice}
                onChange={(e) => setSeparateOffice(e.target.checked)}
              />
              {hi
                ? 'प्रति-पद मत अनुमोदित (केवल यदि स्पष्ट रूप से स्थापित)'
                : 'Approve separate per-office votes (only if expressly established)'}
            </label>

            <div className="flex flex-wrap gap-2">
              <button
                type="button"
                disabled={busy}
                onClick={() => void recordByResolution('secret_ballot')}
                className="text-xs px-3 py-1.5 rounded-lg bg-emerald-600 text-white"
              >
                {hi ? 'A दर्ज करें (प्रस्ताव)' : 'Record A (resolution)'}
              </button>
              <button
                type="button"
                disabled={busy}
                onClick={() => void recordByResolution('show_of_hands')}
                className="text-xs px-3 py-1.5 rounded-lg bg-emerald-600 text-white"
              >
                {hi ? 'B दर्ज करें (प्रस्ताव)' : 'Record B (resolution)'}
              </button>
            </div>

            {!poll.voting_method_consent_open ? (
              <button
                type="button"
                disabled={busy}
                onClick={() => void openConsent()}
                className="text-xs px-3 py-1.5 rounded-lg border border-border"
              >
                {hi ? 'वैकल्पिक: सदस्य सहमति खोलें' : 'Optional: open member consent'}
              </button>
            ) : (
              <div className="flex flex-wrap gap-2">
                <button
                  type="button"
                  disabled={busy || !leading || !allConsented}
                  onClick={() => leading && void finalizeFromConsent(leading, false)}
                  className="text-xs px-3 py-1.5 rounded-lg border border-border disabled:opacity-50"
                >
                  {hi ? 'सभी सहमति के बाद अंतिम' : 'Finalize after all consent'}
                </button>
                {leading && !allConsented && tally.total > 0 && (
                  <button
                    type="button"
                    disabled={busy}
                    onClick={() => void finalizeFromConsent(leading, true)}
                    className="text-xs px-3 py-1.5 rounded-lg border border-amber-600 text-amber-800 dark:text-amber-200"
                  >
                    {hi ? 'आंशिक सहमति से अंतिम' : 'Finalize with partial consent'}
                  </button>
                )}
              </div>
            )}
            <p className="text-[10px] text-muted-foreground">
              {hi
                ? 'मतदान तब तक नहीं खुल सकता जब तक विधि अंतिम न हो।'
                : 'Voting cannot open until a method is finalized.'}
            </p>
          </div>
        )
      )}

      {!isResident && rows.length > 0 && (
        <details className="text-[11px]">
          <summary className="cursor-pointer text-muted-foreground">
            {hi ? 'सहमति सूची' : 'Consent list'} ({rows.length})
          </summary>
          <ul className="mt-1 space-y-0.5 max-h-32 overflow-auto">
            {rows.map((r) => (
              <li key={r.id} className="flex justify-between gap-2">
                <span>
                  {r.member_name || r.member_id.slice(0, 8)}
                  {r.flat_number ? ` · ${r.flat_number}` : ''}
                </span>
                <span className="font-medium">{r.choice === 'secret_ballot' ? 'A' : 'B'}</span>
              </li>
            ))}
          </ul>
        </details>
      )}
    </div>
  );
};

export default VotingMethodConsentPanel;
