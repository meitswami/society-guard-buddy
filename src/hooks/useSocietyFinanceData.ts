import { useMemo } from 'react';
import { useFinanceManagerData } from '@/hooks/useFinanceManagerData';
import { filterSocietyLedgerEntries } from '@/lib/financePeriodReport';
import type { FinancePeriodPayment } from '@/lib/financePeriodReport';

/**
 * Single finance data source for Report page and period-report consumers.
 * Uses the same TanStack cache as FinanceManager (`finance/core`).
 */
export function useSocietyFinanceData(societyId: string | null | undefined, contextLabel = 'Report') {
  const finance = useFinanceManagerData(societyId, contextLabel);

  const societyLedgerEntries = useMemo(
    () => filterSocietyLedgerEntries(finance.ledgerEntries, finance.expenseCategoryById),
    [finance.ledgerEntries, finance.expenseCategoryById],
  );

  const payments = useMemo(
    () => (finance.payments ?? []) as FinancePeriodPayment[],
    [finance.payments],
  );

  return {
    ...finance,
    payments,
    societyLedgerEntries,
    reserveTransfers: finance.reserveTransfers ?? [],
    loading: finance.isLoading,
    societyName: finance.societyName || 'Society',
  };
}
