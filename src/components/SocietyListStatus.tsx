import { RefreshCw } from 'lucide-react';
import { useLanguage } from '@/i18n/LanguageContext';

interface Props {
  loading: boolean;
  error: string | null;
  count: number;
  onRetry: () => void;
}

/** Shown under the society picker when the list failed to load or came back empty. */
const SocietyListStatus = ({ loading, error, count, onRetry }: Props) => {
  const { t } = useLanguage();
  if (loading || (!error && count > 0)) return null;
  return (
    <div className="flex items-center justify-between gap-2 rounded-lg border border-destructive/30 bg-destructive/5 px-3 py-2">
      <p className="text-xs text-destructive leading-snug">
        {error ? t('login.societiesLoadFailed') : t('login.societiesEmpty')}
      </p>
      <button
        type="button"
        onClick={onRetry}
        className="flex shrink-0 items-center gap-1 rounded-md bg-secondary px-2.5 py-1.5 text-xs font-semibold text-secondary-foreground"
      >
        <RefreshCw className="h-3.5 w-3.5" /> {t('login.retry')}
      </button>
    </div>
  );
};

export default SocietyListStatus;
