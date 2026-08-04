import { useEffect, useState } from 'react';
import { Download, ChevronDown, ChevronUp, ScrollText, Loader2 } from 'lucide-react';
import { toast } from 'sonner';
import {
  ELECTION_PROGRAM_STEPS,
  VOTING_CHARTER_SECTIONS,
  VOTING_CHARTER_TITLE_KEY,
} from '@/lib/votingCharter';
import {
  buildVotingCharterPdfBlob,
  votingCharterPdfFilename,
  votingCharterShareMessage,
} from '@/lib/votingCharterPdf';
import { triggerDownload } from '@/lib/reportExportUtils';
import SharePdfWhatsAppButton from '@/components/SharePdfWhatsAppButton';
import { useLanguage } from '@/i18n/LanguageContext';
import { useStore } from '@/store/useStore';
import { supabase } from '@/integrations/supabase/client';
import type { Lang } from '@/i18n/translations';

type Props = {
  societyName?: string;
};

const VotingCharterPanel = ({ societyName: societyNameProp }: Props) => {
  const { t, lang } = useLanguage();
  const societyId = useStore((s) => s.societyId);
  const [open, setOpen] = useState(true);
  const [programOpen, setProgramOpen] = useState(true);
  const [societyName, setSocietyName] = useState(societyNameProp || '');
  const [busyLang, setBusyLang] = useState<Lang | null>(null);

  useEffect(() => {
    if (societyNameProp) {
      setSocietyName(societyNameProp);
      return;
    }
    if (!societyId) return;
    void supabase
      .from('societies')
      .select('name')
      .eq('id', societyId)
      .maybeSingle()
      .then(({ data }) => {
        if (data?.name) setSocietyName(data.name);
      });
  }, [societyId, societyNameProp]);

  const getBlob = (pdfLang: Lang) =>
    buildVotingCharterPdfBlob({
      societyName,
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
      triggerDownload(blob, votingCharterPdfFilename(societyName, pdfLang));
      toast.success(pdfLang === 'hi' ? 'हिंदी चार्टर PDF डाउनलोड हो गया' : 'English charter PDF downloaded');
    } catch (err) {
      console.error('Voting charter PDF download failed', err);
      toast.error(
        pdfLang === 'hi'
          ? 'हिंदी PDF डाउनलोड नहीं हो सका — कृपया पुनः प्रयास करें'
          : 'Could not download English PDF — please try again',
      );
    } finally {
      setBusyLang(null);
    }
  };

  const btnClass =
    'text-xs px-2.5 py-1.5 rounded-lg border border-indigo-500/40 bg-background/80 inline-flex items-center gap-1.5 hover:bg-indigo-500/10 disabled:opacity-60';

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
          <div className="flex flex-wrap gap-2 pt-2">
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
              {busyLang === 'hi' ? 'तैयार हो रहा है…' : 'हिंदी PDF'}
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
              filename={votingCharterPdfFilename(societyName, lang === 'hi' ? 'hi' : 'en')}
              message={votingCharterShareMessage(lang === 'hi' ? 'hi' : 'en')}
              label={t('votingCharter.shareWhatsApp')}
              disabled={!!busyLang}
            />
          </div>
          <p className="text-[10px] text-muted-foreground">
            {lang === 'hi'
              ? 'हिंदी PDF बटन दबाएँ — चार्टर देवनागरी में बनेगा। English PDF अलग से अंग्रेज़ी में डाउनलोड होता है।'
              : 'Use Hindi PDF for Devanagari charter text. English PDF downloads the English version.'}
          </p>

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
              <div className="px-2.5 pb-2.5 space-y-2 border-t border-indigo-500/15">
                <p className="text-[11px] text-muted-foreground pt-2">{t('votingCharter.program.intro')}</p>
                <ol className="space-y-2">
                  {ELECTION_PROGRAM_STEPS.map((step, i) => (
                    <li key={step.stepKey} className="flex gap-2 text-xs">
                      <span className="shrink-0 w-5 h-5 rounded-full bg-indigo-500/15 text-indigo-700 dark:text-indigo-300 text-[10px] font-bold flex items-center justify-center">
                        {i + 1}
                      </span>
                      <div>
                        <p className="font-semibold text-foreground">{t(step.stepKey)}</p>
                        <p className="text-muted-foreground mt-0.5 leading-relaxed">{t(step.detailKey)}</p>
                      </div>
                    </li>
                  ))}
                </ol>
              </div>
            )}
          </div>

          <p className="text-[10px] font-semibold uppercase tracking-wider text-muted-foreground">
            {t('votingCharter.rulesHeading')}
          </p>
          {VOTING_CHARTER_SECTIONS.map((sec) => (
            <div key={sec.headingKey}>
              <p className="text-[10px] font-semibold uppercase tracking-wider text-muted-foreground mt-2">
                {t(sec.headingKey)}
              </p>
              <ul className="mt-1 space-y-1 text-xs text-foreground list-disc pl-4">
                {sec.pointKeys.map((key) => (
                  <li key={key}>{t(key)}</li>
                ))}
              </ul>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

export default VotingCharterPanel;
