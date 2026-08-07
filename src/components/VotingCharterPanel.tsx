import { useEffect, useState } from 'react';
import { Download, ChevronDown, ChevronUp, ScrollText, Loader2 } from 'lucide-react';
import { toast } from 'sonner';
import {
  ELECTION_PROGRAM_STEPS,
  VOTING_CHARTER_SUMMARY,
  VOTING_CHARTER_TITLE_KEY,
} from '@/lib/votingCharter';
import {
  buildVotingCharterPdfBlob,
  votingCharterPdfFilename,
  votingCharterShareMessage,
} from '@/lib/votingCharterPdf';
import { savePdfToDevice } from '@/lib/reportExportUtils';
import {
  fetchSocietyLetterhead,
  letterheadAddressLine,
  letterheadContactLine,
  type SocietyLetterhead,
} from '@/lib/pdfLetterhead';
import SharePdfWhatsAppButton from '@/components/SharePdfWhatsAppButton';
import { useLanguage } from '@/i18n/LanguageContext';
import { useStore } from '@/store/useStore';
import type { Lang } from '@/i18n/translations';

type Props = {
  societyName?: string;
  /** Prefer explicit prop; falls back to zustand store. */
  societyId?: string | null;
  /** PDF download / WhatsApp share — admin only; members get on-screen display. */
  isAdmin?: boolean;
};

const VotingCharterPanel = ({
  societyName: societyNameProp,
  societyId: societyIdProp,
  isAdmin = false,
}: Props) => {
  const { t, lang } = useLanguage();
  const storeSocietyId = useStore((s) => s.societyId);
  const societyId = societyIdProp ?? storeSocietyId;
  const [open, setOpen] = useState(true);
  const [programOpen, setProgramOpen] = useState(true);
  const [societyName, setSocietyName] = useState(societyNameProp || '');
  const [letterhead, setLetterhead] = useState<SocietyLetterhead | null>(null);
  const [busyLang, setBusyLang] = useState<Lang | null>(null);

  useEffect(() => {
    if (societyNameProp) setSocietyName(societyNameProp);
  }, [societyNameProp]);

  useEffect(() => {
    if (!societyId) {
      // Still show a name-only band when parent passed societyName without id.
      if (societyNameProp?.trim()) {
        setLetterhead({ name: societyNameProp.trim(), letterheadMode: 'auto' });
      } else {
        setLetterhead(null);
      }
      return;
    }
    let cancelled = false;
    void fetchSocietyLetterhead(societyId)
      .then((lh) => {
        if (cancelled) return;
        if (lh) {
          setLetterhead(lh);
          if (!societyNameProp && lh.name) setSocietyName(lh.name);
          return;
        }
        console.warn('[VotingCharterPanel] letterhead fetch returned null for', societyId);
        const fallbackName = societyNameProp?.trim() || 'Society';
        setLetterhead({ name: fallbackName, letterheadMode: 'auto' });
        if (!societyNameProp) setSocietyName(fallbackName);
      })
      .catch((err) => {
        console.warn('[VotingCharterPanel] letterhead fetch error', err);
        if (cancelled) return;
        const fallbackName = societyNameProp?.trim() || 'Society';
        setLetterhead({ name: fallbackName, letterheadMode: 'auto' });
      });
    return () => {
      cancelled = true;
    };
  }, [societyId, societyNameProp]);

  const getBlob = (pdfLang: Lang) =>
    buildVotingCharterPdfBlob({
      societyId,
      societyName: letterhead?.name || societyName,
      letterhead,
      lang: pdfLang,
    });

  const downloadPdf = async (pdfLang: Lang) => {
    if (busyLang) return;
    setBusyLang(pdfLang);
    try {
      const blob = await getBlob(pdfLang);
      if (!blob || blob.size < 100) {
        throw new Error('PDF was empty');
      }
      const result = await savePdfToDevice(blob, votingCharterPdfFilename(societyName, pdfLang));
      if (result === 'cancelled') return;
      if (result === 'shared') {
        toast.success(pdfLang === 'hi' ? 'नियमपत्र पीडीएफ सहेजें / साझा करें' : 'Use Share to save the charter PDF');
      } else if (result === 'opened') {
        toast.success(
          pdfLang === 'hi'
            ? 'पीडीएफ खुला — साझा करें → फ़ाइलों में सहेजें चुनें'
            : 'PDF opened — use Share → Save to Files to keep it',
        );
      } else {
        toast.success(pdfLang === 'hi' ? 'हिंदी नियमपत्र पीडीएफ प्राप्त हो गया' : 'English charter PDF downloaded');
      }
    } catch (err) {
      console.error('Voting charter PDF download failed', err);
      toast.error(
        pdfLang === 'hi'
          ? 'हिंदी पीडीएफ प्राप्त नहीं हो सका — कृपया पुनः प्रयास करें'
          : 'Could not download English PDF — please try again',
      );
    } finally {
      setBusyLang(null);
    }
  };

  const btnClass =
    'text-xs px-2.5 py-1.5 rounded-lg border border-indigo-500/40 bg-background/80 inline-flex items-center gap-1.5 hover:bg-indigo-500/10 disabled:opacity-60';

  const displayName = (letterhead?.name || societyName || '').trim() || 'Society';
  const addressLine = letterhead ? letterheadAddressLine(letterhead) : '';
  const contactLine = letterhead ? letterheadContactLine(letterhead) : '';
  const logoSrc = letterhead?.logoDataUrl || letterhead?.logoUrl || null;
  const letterheadImg =
    letterhead?.letterheadMode === 'image'
      ? letterhead.letterheadDataUrl || letterhead.letterheadUrl || null
      : null;

  return (
    <div className="mb-4 rounded-xl border border-indigo-500/30 bg-indigo-500/5 overflow-hidden">
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        className="w-full flex items-center justify-between gap-2 px-3 py-2.5 text-left hover:bg-indigo-500/10 transition-colors"
      >
        <span className="flex items-center gap-2 text-sm font-semibold text-indigo-700 dark:text-indigo-300">
          <ScrollText className="w-4 h-4 shrink-0" />
          {t(VOTING_CHARTER_TITLE_KEY)}
        </span>
        {open ? <ChevronUp className="w-4 h-4 text-muted-foreground" /> : <ChevronDown className="w-4 h-4 text-muted-foreground" />}
      </button>
      {open && (
        <div className="px-3 pb-3 space-y-3 border-t border-indigo-500/20">
          {/* Always show a letterhead band (name at minimum) — not gated on image URL. */}
          <div className="pt-2.5 border-b border-indigo-500/20 pb-3 bg-background/50 -mx-3 px-3 rounded-none">
            {letterheadImg ? (
              <img
                src={letterheadImg}
                alt={displayName}
                className="w-full max-h-24 object-contain object-left"
              />
            ) : (
              <div className="flex items-start gap-3">
                {logoSrc ? (
                  <img
                    src={logoSrc}
                    alt=""
                    className="w-12 h-12 object-contain rounded border border-indigo-500/20 shrink-0 bg-background"
                  />
                ) : (
                  <div
                    className="w-12 h-12 rounded border border-indigo-500/25 bg-indigo-500/10 shrink-0 flex items-center justify-center text-indigo-700 dark:text-indigo-300 text-sm font-bold"
                    aria-hidden
                  >
                    {(displayName[0] || 'S').toUpperCase()}
                  </div>
                )}
                <div className="min-w-0 space-y-0.5">
                  <p className="text-base font-bold text-foreground leading-snug tracking-tight">{displayName}</p>
                  {addressLine ? (
                    <p className="text-[11px] text-muted-foreground leading-snug">{addressLine}</p>
                  ) : (
                    <p className="text-[11px] text-muted-foreground/80 leading-snug">
                      {t('votingCharter.summary.title')}
                    </p>
                  )}
                  {contactLine && (
                    <p className="text-[11px] text-muted-foreground leading-snug">{contactLine}</p>
                  )}
                </div>
              </div>
            )}
            <div className="mt-2.5 h-[2px] w-full bg-[#374178]/80" />
          </div>

          {isAdmin && (
            <>
              <div className="flex flex-wrap gap-2 pt-0.5">
                <button
                  type="button"
                  disabled={!!busyLang}
                  onClick={(e) => {
                    e.preventDefault();
                    e.stopPropagation();
                    void downloadPdf('hi');
                  }}
                  className={btnClass}
                >
                  {busyLang === 'hi' ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <Download className="w-3.5 h-3.5" />}
                  {busyLang === 'hi' ? 'तैयार हो रहा है…' : 'हिंदी पीडीएफ'}
                </button>
                <button
                  type="button"
                  disabled={!!busyLang}
                  onClick={(e) => {
                    e.preventDefault();
                    e.stopPropagation();
                    void downloadPdf('en');
                  }}
                  className={btnClass}
                >
                  {busyLang === 'en' ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <Download className="w-3.5 h-3.5" />}
                  {busyLang === 'en' ? 'Preparing…' : 'English PDF'}
                </button>
                <SharePdfWhatsAppButton
                  getBlob={() => getBlob(lang === 'hi' ? 'hi' : 'en')}
                  filename={votingCharterPdfFilename(societyName || displayName, lang === 'hi' ? 'hi' : 'en')}
                  message={votingCharterShareMessage(lang === 'hi' ? 'hi' : 'en')}
                  label={t('votingCharter.shareWhatsApp')}
                  disabled={!!busyLang}
                />
              </div>
            </>
          )}

          <div className="rounded-lg border border-indigo-500/25 bg-background/60 px-3 py-2.5 space-y-1.5 mt-2">
            <p className="text-sm font-semibold text-indigo-800 dark:text-indigo-200">
              {t(VOTING_CHARTER_SUMMARY.titleKey)}
            </p>
            <p className="text-xs text-foreground">{t(VOTING_CHARTER_SUMMARY.postsKey)}</p>
            <ul className="text-xs text-muted-foreground space-y-1 list-none pt-0.5">
              <li>{t(VOTING_CHARTER_SUMMARY.voteRightKey)}</li>
              <li>{t(VOTING_CHARTER_SUMMARY.proxyKey)}</li>
              <li>{t(VOTING_CHARTER_SUMMARY.quorumKey)}</li>
            </ul>
          </div>

          <div className="rounded-lg border border-indigo-500/20 bg-background/40">
            <button
              type="button"
              onClick={() => setProgramOpen((v) => !v)}
              className="w-full flex items-center justify-between gap-2 px-2.5 py-2 text-left"
            >
              <span className="text-xs font-semibold text-foreground">{t('votingCharter.program.heading')}</span>
              {programOpen ? (
                <ChevronUp className="w-3.5 h-3.5 text-muted-foreground" />
              ) : (
                <ChevronDown className="w-3.5 h-3.5 text-muted-foreground" />
              )}
            </button>
            {programOpen && (
              <div className="px-2.5 pb-2.5 space-y-3 border-t border-indigo-500/15">
                <p className="text-[11px] text-muted-foreground pt-2 leading-relaxed">
                  {t('votingCharter.program.intro')}
                </p>
                <ol className="space-y-3">
                  {ELECTION_PROGRAM_STEPS.map((step, i) => (
                    <li key={step.stepKey} className="flex gap-2 text-xs">
                      <span className="shrink-0 w-5 h-5 rounded-full bg-indigo-500/15 text-indigo-700 dark:text-indigo-300 text-[10px] font-bold flex items-center justify-center mt-0.5">
                        {i + 1}
                      </span>
                      <div className="min-w-0 space-y-1.5">
                        <p className="font-semibold text-foreground leading-snug">{t(step.stepKey)}</p>
                        <p className="text-muted-foreground leading-relaxed">{t(step.detailKey)}</p>
                        {step.pointKeys.length > 0 && (
                          <ul className="list-disc pl-4 space-y-1 text-foreground/90">
                            {step.pointKeys.map((key) => (
                              <li key={key} className="leading-relaxed">
                                {t(key)}
                              </li>
                            ))}
                          </ul>
                        )}
                      </div>
                    </li>
                  ))}
                </ol>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
};

export default VotingCharterPanel;
