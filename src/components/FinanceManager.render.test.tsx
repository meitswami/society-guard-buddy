import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { TooltipProvider } from '@/components/ui/tooltip';
import FinanceManager from '@/components/FinanceManager';
import type { FinanceLedgerRow } from '@/lib/financeManagerTypes';

const ledgerWithNullMode = {
  id: 'fe-1',
  society_id: 'soc-1',
  record_mode: null,
  destination: null,
  allocation_style: 'none',
  include_vacant: false,
  entry_month: '2026-07',
  transaction_date: '2026-07-01',
  total_amount: 1000,
  aggregate_flat_count: 0,
  charge_id: null,
  expense_id: null,
  distributed_at: null,
  title: 'Pool receipt',
  notes: null,
  screenshot_url: null,
  transaction_id: null,
  payment_method: 'cash',
  payment_status: 'verified',
  created_by: 'Admin',
  created_at: '2026-07-01T10:00:00Z',
  finance_entry_counterparties: null,
  finance_entry_allocations: [],
} as unknown as FinanceLedgerRow;

vi.mock('@/store/useStore', () => ({
  useStore: (selector: (s: { societyId: string }) => unknown) => selector({ societyId: 'soc-1' }),
}));

vi.mock('@/i18n/LanguageContext', () => ({
  useLanguage: () => ({ t: (k: string) => k }),
}));

vi.mock('@/hooks/useFinanceManagerData', () => ({
  useFinanceManagerData: () => ({
    charges: [{ id: 'ch-1', title: 'July 2026 Maintenance', amount: 500, frequency: 'monthly', due_day: 1 }],
    payments: [],
    ledgerEntries: [ledgerWithNullMode],
    expenseCategoryById: new Map(),
    flats: [{ id: 'flat-1', flat_number: '101', owner_name: 'Owner', is_occupied: true }],
    primaryByFlatId: new Map(),
    societyName: 'Test Society',
    residentUsers: [],
    paymentExpenseGroups: [],
    autoReminderEnabled: true,
    autoReminderSchedule: 'once_12pm',
    reminderDueDay: 1,
    loadAll: vi.fn(),
  }),
}));

vi.mock('@/hooks/finance/useFinanceMutations', () => ({
  useFinanceMutations: () => ({}),
}));

vi.mock('@/hooks/finance/useFinanceEventReference', () => ({
  useFinanceEventReference: () => ({ contributions: [], foodExpenses: [], isLoading: false }),
}));

function renderFinance() {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={client}>
      <TooltipProvider>
        <FinanceManager adminName="Admin" />
      </TooltipProvider>
    </QueryClientProvider>,
  );
}

describe('FinanceManager render', () => {
  beforeEach(() => {
    vi.spyOn(window, 'scrollTo').mockImplementation(() => {});
    Element.prototype.scrollIntoView = vi.fn();
  });

  it('renders Record receipt panel when opened via initial sub-tab', () => {
    const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    render(
      <QueryClientProvider client={client}>
        <TooltipProvider>
          <FinanceManager adminName="Admin" initialSubTab="payments" />
        </TooltipProvider>
      </QueryClientProvider>,
    );
    expect(screen.getByText('Recording style')).toBeInTheDocument();
  });

  it('renders Transactions tab with ledger rows missing record_mode', () => {
    renderFinance();
    fireEvent.click(screen.getByRole('button', { name: 'Transactions' }));
    expect(screen.getByText('Pool receipt')).toBeInTheDocument();
  });
});
