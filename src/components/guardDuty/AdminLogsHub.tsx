import { useState } from 'react';
import { FileText, ClipboardCheck } from 'lucide-react';
import LogsPage from '@/pages/LogsPage';
import GuardDutyReview from '@/components/guardDuty/GuardDutyReview';
import { useLanguage } from '@/i18n/LanguageContext';
import { cn } from '@/lib/utils';

type Tab = 'visitors' | 'duty';

type Props = {
  initialSearchQuery?: string;
  onInitialSearchConsumed?: () => void;
};

const AdminLogsHub = ({ initialSearchQuery, onInitialSearchConsumed }: Props) => {
  const { t } = useLanguage();
  const [tab, setTab] = useState<Tab>('visitors');

  return (
    <div className="page-container space-y-4">
      <h1 className="page-title">{t('nav.logs')}</h1>
      <div className="grid grid-cols-2 gap-2">
        <button
          type="button"
          onClick={() => setTab('visitors')}
          className={cn(
            'flex items-center justify-center gap-2 rounded-xl border-2 p-3 font-semibold text-sm active:scale-[0.98]',
            tab === 'visitors' ? 'border-primary bg-primary/15 text-primary' : 'border-border bg-card',
          )}
        >
          <FileText className="w-5 h-5" />
          {t('duty.visitorLogs')}
        </button>
        <button
          type="button"
          onClick={() => setTab('duty')}
          className={cn(
            'flex items-center justify-center gap-2 rounded-xl border-2 p-3 font-semibold text-sm active:scale-[0.98]',
            tab === 'duty' ? 'border-primary bg-primary/15 text-primary' : 'border-border bg-card',
          )}
        >
          <ClipboardCheck className="w-5 h-5" />
          {t('duty.adminTab')}
        </button>
      </div>

      {tab === 'visitors' ? (
        <LogsPage
          initialSearchQuery={initialSearchQuery}
          onInitialSearchConsumed={onInitialSearchConsumed}
          embedded
        />
      ) : (
        <GuardDutyReview />
      )}
    </div>
  );
};

export default AdminLogsHub;
