import { useMemo } from 'react';
import { useQuery } from '@tanstack/react-query';
import { fetchSocietyFinanceReportData } from '@/services/finance/financeService';
import { filterSocietyLedgerEntries } from '@/lib/financePeriodReport';
import { financeQueryKeys } from '@/hooks/finance/financeQueryKeys';

/** Loads society finance data using the same queries as Finance module. */
export function useSocietyFinanceReportData(societyId: string | undefined) {
  const query = useQuery({
    queryKey: financeQueryKeys.periodReport(societyId),
    queryFn: () => fetchSocietyFinanceReportData(societyId!),
    enabled: Boolean(societyId),
  });

  const expenseCategoryById = useMemo(
    () => new Map(Object.entries(query.data?.expenseCategoryById ?? {})),
    [query.data?.expenseCategoryById],
  );

  const societyLedgerEntries = useMemo(
    () => filterSocietyLedgerEntries(query.data?.ledgerEntries ?? [], expenseCategoryById),
    [query.data?.ledgerEntries, expenseCategoryById],
  );

  return {
    loading: query.isLoading,
    payments: query.data?.payments ?? [],
    societyLedgerEntries,
    expenseCategoryById,
    reserveTransfers: query.data?.reserveTransfers ?? [],
    error: query.error,
    reload: () => query.refetch(),
  };
}
