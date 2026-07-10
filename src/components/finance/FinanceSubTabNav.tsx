import { Bell, ChevronDown } from 'lucide-react';
import type { FinanceSubTab } from '@/lib/financeManagerTypes';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { cn } from '@/lib/utils';

const CREATE_ITEMS: { id: FinanceSubTab; label: string }[] = [
  { id: 'maintenance', label: 'Receipt type' },
  { id: 'create_payment', label: 'Payment type' },
];

const RECORD_ITEMS: { id: FinanceSubTab; label: string }[] = [
  { id: 'payments', label: 'Record receipt' },
  { id: 'record_payment', label: 'Record payment' },
];

const STANDALONE_TABS: { id: FinanceSubTab; label: string }[] = [
  { id: 'receipts', label: 'Transactions' },
  { id: 'totals', label: 'Totals' },
];

interface Props {
  activeTab: FinanceSubTab;
  onTabChange: (tab: FinanceSubTab) => void;
  showReminders: boolean;
  onToggleReminders: () => void;
}

function groupActive(active: FinanceSubTab, ids: FinanceSubTab[]) {
  return ids.includes(active);
}

function NavDropdown({
  label,
  items,
  activeTab,
  onTabChange,
}: {
  label: string;
  items: { id: FinanceSubTab; label: string }[];
  activeTab: FinanceSubTab;
  onTabChange: (tab: FinanceSubTab) => void;
}) {
  const active = groupActive(
    activeTab,
    items.map((i) => i.id),
  );
  const activeItem = items.find((i) => i.id === activeTab);

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <button
          type="button"
          className={cn(
            'px-3 py-1.5 rounded-lg text-xs font-medium whitespace-nowrap inline-flex items-center gap-1',
            active ? 'bg-primary text-primary-foreground' : 'bg-secondary text-secondary-foreground',
          )}
        >
          {activeItem ? `${label}: ${activeItem.label}` : label}
          <ChevronDown className="w-3 h-3 opacity-70" />
        </button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="start" className="min-w-[10rem]">
        {items.map(({ id, label: itemLabel }) => (
          <DropdownMenuItem key={id} onClick={() => onTabChange(id)} className="text-xs cursor-pointer">
            {itemLabel}
          </DropdownMenuItem>
        ))}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}

export function FinanceSubTabNav({ activeTab, onTabChange, showReminders, onToggleReminders }: Props) {
  return (
    <div className="flex gap-1 mb-4 overflow-x-auto items-center">
      <NavDropdown label="Create" items={CREATE_ITEMS} activeTab={activeTab} onTabChange={onTabChange} />
      <NavDropdown label="Record" items={RECORD_ITEMS} activeTab={activeTab} onTabChange={onTabChange} />
      {STANDALONE_TABS.map(({ id, label }) => (
        <button
          key={id}
          type="button"
          onClick={() => onTabChange(id)}
          className={cn(
            'px-3 py-1.5 rounded-lg text-xs font-medium whitespace-nowrap',
            activeTab === id ? 'bg-primary text-primary-foreground' : 'bg-secondary text-secondary-foreground',
          )}
        >
          {label}
        </button>
      ))}
      <button
        type="button"
        onClick={onToggleReminders}
        className={cn(
          'px-3 py-1.5 rounded-lg text-xs font-medium whitespace-nowrap inline-flex items-center gap-1 ml-auto shrink-0',
          showReminders ? 'bg-amber-500/15 text-amber-700 border border-amber-500/30' : 'bg-secondary text-secondary-foreground',
        )}
      >
        <Bell className="w-3.5 h-3.5" />
        {showReminders ? 'Hide reminders' : 'Reminders'}
      </button>
    </div>
  );
}
