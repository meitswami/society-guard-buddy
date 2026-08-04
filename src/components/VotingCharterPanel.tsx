import { useState } from 'react';
import { Download, ChevronDown, ChevronUp, ScrollText } from 'lucide-react';
import {
  ELECTION_PROGRAM_STEPS,
  VOTING_CHARTER_SECTIONS,
  VOTING_CHARTER_TITLE_KEY,
} from '@/lib/votingCharter';
import { buildVotingCharterPdfBlob, votingCharterPdfFilename } from '@/lib/votingCharterPdf';
import { triggerDownload } from '@/lib/reportExportUtils';
import SharePdfWhatsAppButton from '@/components/SharePdfWhatsAppButton';
import { useLanguage } from '@/i18n/LanguageContext';

type Props = {
  societyName?: string;
};

const VotingCharterPanel = ({ societyName }: Props) => {
  const { t } = useLanguage();
  const [open, setOpen] = useState(true);
  const [programOpen, setProgramOpen] = useState(true);

  const getBlob = () => buildVotingCharterPdfBlob({ societyName, t });
  const filename = votingCharterPdfFilename(societyName);

  const downloadPdf = async () => {
    const blob = await getBlob();
    triggerDownload(blob, filename);
  };

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
              onClick={() => void downloadPdf()}
              className="text-xs px-2.5 py-1.5 rounded-lg border border-indigo-500/40 bg-background/80 inline-flex items-center gap-1.5 hover:bg-indigo-500/10"
            >
              <Download className="w-3.5 h-3.5" />
              {t('votingCharter.download')}
            </button>
            <SharePdfWhatsAppButton
              getBlob={getBlob}
              filename={filename}
              message={t('votingCharter.shareMessage')}
              label={t('votingCharter.shareWhatsApp')}
            />
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
