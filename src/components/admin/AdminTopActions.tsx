import { Search } from 'lucide-react';
import AdminDisplaySizeButton from '@/components/admin/AdminDisplaySizeButton';
import LanguageToggle from '@/components/LanguageToggle';
import { useLanguage } from '@/i18n/LanguageContext';

interface Props {
  onOpenSearch: () => void;
}

/** Floating admin actions: language, global search + display size. */
const AdminTopActions = ({ onOpenSearch }: Props) => {
  const { t } = useLanguage();

  return (
    <div className="fixed top-[max(0.5rem,env(safe-area-inset-top))] right-3 z-[55] flex items-center gap-1.5">
      <LanguageToggle />
      <button
        type="button"
        onClick={onOpenSearch}
        className="p-2 rounded-lg bg-primary text-primary-foreground shadow-md hover:opacity-90"
        title={t('adminNav.search')}
        aria-label={t('adminNav.search')}
      >
        <Search className="w-4 h-4" />
      </button>
      <AdminDisplaySizeButton />
    </div>
  );
};

export default AdminTopActions;
