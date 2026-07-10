import type { FinanceSubTab } from '@/lib/financeManagerTypes';

const FINANCE_SUB_TABS: { id: FinanceSubTab; label: string }[] = [
  { id: 'maintenance', label: 'Create Receipts' },
  { id: 'payments', label: 'Record receipt' },
  { id: 'record_payment', label: 'Record payment' },
  { id: 'receipts', label: 'Transactions' },
  { id: 'period', label: 'Period report' },
  { id: 'totals', label: 'Totals' },
  { id: 'flat_report', label: 'Flat Report' },
  { id: 'reminders', label: 'Reminders' },
];

interface Props {
  activeTab: FinanceSubTab;
  onTabChange: (tab: FinanceSubTab) => void;
}

export function FinanceSubTabNav({ activeTab, onTabChange }: Props) {
  return (
    <div className="flex gap-1 mb-4 overflow-x-auto">
      {FINANCE_SUB_TABS.map(({ id, label }) => (
        <button
          key={id}
          type="button"
          onClick={() => onTabChange(id)}
          className={`px-3 py-1.5 rounded-lg text-xs font-medium whitespace-nowrap ${
            activeTab === id ? 'bg-primary text-primary-foreground' : 'bg-secondary text-secondary-foreground'
          }`}
        >
          {label}
        </button>
      ))}
    </div>
  );
}
