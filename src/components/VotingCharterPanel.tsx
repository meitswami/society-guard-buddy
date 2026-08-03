import { useState } from 'react';
import { ScrollText, ChevronDown, ChevronUp } from 'lucide-react';
import { VOTING_CHARTER_SECTIONS, VOTING_CHARTER_TITLE_KEY } from '@/lib/votingCharter';
import { useLanguage } from '@/i18n/LanguageContext';

const VotingCharterPanel = () => {
  const { t } = useLanguage();
  const [open, setOpen] = useState(true);

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
