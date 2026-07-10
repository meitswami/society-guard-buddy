import { Search } from 'lucide-react';
import AdminDisplaySizeButton from '@/components/admin/AdminDisplaySizeButton';

interface Props {
  onOpenSearch: () => void;
}

/** Floating admin actions: global search + display size (button-only info). */
const AdminTopActions = ({ onOpenSearch }: Props) => (
  <div className="fixed top-[max(0.5rem,env(safe-area-inset-top))] right-3 z-[55] flex items-center gap-1.5">
    <button
      type="button"
      onClick={onOpenSearch}
      className="p-2 rounded-lg bg-primary text-primary-foreground shadow-md hover:opacity-90"
      title="Search across modules"
      aria-label="Search across modules"
    >
      <Search className="w-4 h-4" />
    </button>
    <AdminDisplaySizeButton />
  </div>
);

export default AdminTopActions;
