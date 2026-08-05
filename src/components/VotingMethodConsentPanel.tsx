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
  const optEffect = (method: ElectionVotingMethod) => {
    const o = VOTING_METHOD_OPTIONS[method];
    return hi ? o.effectHi : o.effectEn;
  };

  const openConsent = async () => {
    if (!societyId) return;
    const ok = await confirmAction(
      hi ? 'सदस्य सहमति खोलें?' : 'Open member consent?',
      hi
        ? 'सदस्य विकल्प A (गुप्त मतपत्र) या विकल्प B (हाथ उठाकर) देखकर सहमति देंगे। सभी पात्र सदस्यों की सहमति के बाद ही विधि अंतिम होगी।'
        : 'Members will see Option A (Secret Ballot) and Option B (Show of Hands), with effects, and record consent. The method is finalized only after all eligible members have consented.',
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
      toast.success(hi ? 'सदस्य सहमति खुली' : 'Member consent opened');
      onReload();
      void load();
    }
  };

  const castConsent = async (choice: ElectionVotingMethod) => {
    if (!societyId || !memberId) {
      toast.error(hi ? 'सदस्य प्रोफ़ाइल आवश्यक है' : 'Member profile required');
      return;
    }
    const label = optLabel(choice);
    const ok = await confirmAction(
      hi ? 'सहमति दर्ज करें?' : 'Record your consent?',
      hi
        ? `आप ${label} चुन रहे हैं। जमा होने के बाद बदल नहीं सकते।`
        : `You are choosing ${label}. This cannot be changed after submission.`,
      hi ? 'सहमति दें' : 'Confirm consent',
      hi ? 'रद्द' : 'Cancel',
    );
    if (!ok) return;
    setBusy(true);
    const { error } = await submitVotingMethodConsent({
      societyId,
      pollId: poll.id,
      memberId,
      choice,
      memberName,
      flatNumber,
    });
    setBusy(false);
    if (error) toast.error(error);
    else {
      toast.success(hi ? 'सहमति दर्ज हो गई' : 'Consent recorded');
      void load();
    }
  };

  const finalize = async (method: ElectionVotingMethod, allowPartial: boolean) => {
    if (!societyId) return;
    if (eligibleCount == null) {
      toast.error(hi ? 'पात्र सदस्य संख्या उपलब्ध नहीं' : 'Eligible member count unavailable');
      return;
    }
    const ok = await confirmAction(
      hi ? 'मतदान विधि अंतिम करें?' : 'Finalize voting method?',
      allowPartial
        ? hi
          ? `आंशिक सहमति (${tally.total}/${eligibleCount}) के साथ ${optLabel(method)} अंतिम करें? बैठक प्रस्ताव आवश्यक।`
          : `Finalize ${optLabel(method)} with partial consent (${tally.total}/${eligibleCount})? Only if the meeting so resolves.`
        : hi
          ? `सभी ${eligibleCount} पात्र सदस्यों की सहमति मिल गई। ${optLabel(method)} अंतिम करें?`
          : `All ${eligibleCount} eligible members have consented. Finalize ${optLabel(method)}?`,
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

  return (
    <div className="mt-3 rounded-lg border border-border/70 bg-muted/20 p-3 space-y-3">
      <div>
        <p className="text-xs font-semibold text-foreground">
          {hi ? 'मतदान विधि — विकल्प A या B' : 'Voting method — Option A or B'}
        </p>
        <p className="text-[11px] text-muted-foreground mt-0.5">
          {hi
            ? 'उपविधियाँ दोनों विधियों की अनुमति देती हैं। सदस्य प्रभाव देखें, सहमति दें; सभी पात्र सदस्यों की सहमति के बाद अंतिम।'
            : 'Bye-laws permit both methods. Members see the effect of each option, record consent; finalize after all eligible members have consented.'}
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
              <p className="text-[10px] text-muted-foreground">
                {hi ? 'सहमति' : 'Consents'}: <strong className="text-foreground">{count}</strong>
              </p>
              {isResident && poll.voting_method_consent_open && !finalized && !myConsent && (
                <button
                  type="button"
                  disabled={busy}
                  onClick={() => void castConsent(method)}
                  className="text-xs px-2.5 py-1.5 rounded-lg bg-indigo-600 text-white w-full"
                >
                  {hi ? `विकल्प ${o.code} की सहमति` : `Consent to Option ${o.code}`}
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

      <p className="text-[11px] text-muted-foreground">
        {hi ? 'प्रगति' : 'Progress'}:{' '}
        <strong className="text-foreground">
          {tally.total}
          {eligibleCount != null ? ` / ${eligibleCount}` : ''}
        </strong>{' '}
        {hi ? 'पात्र सदस्यों की सहमति' : 'eligible members consented'}
        {allConsented ? (hi ? ' — पूर्ण' : ' — complete') : null}
        {leading ? (
          <>
            {' · '}
            {hi ? 'अग्रणी' : 'Leading'}: {optLabel(leading)}
          </>
        ) : tally.total > 0 ? (
          <> · {hi ? 'बराबरी / कोई स्पष्ट बहुमत नहीं' : 'Tie / no clear lead'}</>
        ) : null}
      </p>

      {finalized ? (
        <p className="text-xs text-emerald-700 dark:text-emerald-300">
          {hi ? 'अंतिम विधि' : 'Finalized'}:{' '}
          <strong>{optLabel(poll.voting_method as ElectionVotingMethod)}</strong>
          {poll.voting_method_recorded_by ? ` · ${poll.voting_method_recorded_by}` : ''}
          {poll.separate_office_votes
            ? hi
              ? ' · प्रति-पद अलग मत अनुमोदित'
              : ' · separate office votes approved'
            : ''}
        </p>
      ) : (
        !isResident && (
          <div className="space-y-2">
            {!poll.voting_method_consent_open ? (
              <button
                type="button"
                disabled={busy}
                onClick={() => void openConsent()}
                className="text-xs px-3 py-1.5 rounded-lg bg-indigo-600 text-white"
              >
                {hi ? 'सदस्य सहमति खोलें (A / B)' : 'Open member consent (A / B)'}
              </button>
            ) : (
              <>
                <label className="text-[11px] flex items-center gap-1.5">
                  <input
                    type="checkbox"
                    checked={separateOffice}
                    onChange={(e) => setSeparateOffice(e.target.checked)}
                  />
                  {hi
                    ? 'प्रति-पद अलग मतपत्र स्पष्ट रूप से अनुमोदित'
                    : 'Approve separate per-office votes (only if expressly established)'}
                </label>
                <div className="flex flex-wrap gap-2">
                  <button
                    type="button"
                    disabled={busy || !leading || !allConsented}
                    onClick={() => leading && void finalize(leading, false)}
                    className="text-xs px-3 py-1.5 rounded-lg bg-emerald-600 text-white disabled:opacity-50"
                  >
                    {hi
                      ? 'सभी सदस्यों की सहमति के बाद अंतिम करें'
                      : 'Finalize after all members consent'}
                  </button>
                  {leading && !allConsented && (
                    <button
                      type="button"
                      disabled={busy || tally.total < 1}
                      onClick={() => void finalize(leading, true)}
                      className="text-xs px-3 py-1.5 rounded-lg border border-amber-600 text-amber-800 dark:text-amber-200"
                    >
                      {hi ? 'आंशिक सहमति से अंतिम (बैठक प्रस्ताव)' : 'Finalize with partial consent (meeting resolution)'}
                    </button>
                  )}
                  {!leading && tally.total > 0 && (
                    <>
                      <button
                        type="button"
                        disabled={busy || !allConsented}
                        onClick={() => void finalize('secret_ballot', !allConsented)}
                        className="text-xs px-3 py-1.5 rounded-lg border border-border"
                      >
                        {hi ? 'बराबरी पर A अंतिम' : 'Tie-break: finalize A'}
                      </button>
                      <button
                        type="button"
                        disabled={busy || !allConsented}
                        onClick={() => void finalize('show_of_hands', !allConsented)}
                        className="text-xs px-3 py-1.5 rounded-lg border border-border"
                      >
                        {hi ? 'बराबरी पर B अंतिम' : 'Tie-break: finalize B'}
                      </button>
                    </>
                  )}
                </div>
                <p className="text-[10px] text-muted-foreground">
                  {hi
                    ? 'अंतिम होने तक मतदान विंडो नहीं खोली जा सकती।'
                    : 'Voting cannot open until a method is finalized.'}
                </p>
              </>
            )}
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
