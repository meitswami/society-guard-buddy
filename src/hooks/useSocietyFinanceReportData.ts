import { useSocietyFinanceData } from '@/hooks/useSocietyFinanceData';

/** @deprecated Use `useSocietyFinanceData` — kept for backward compatibility. */
export function useSocietyFinanceReportData(societyId: string | undefined) {
  const data = useSocietyFinanceData(societyId, 'Report');

  return {
    loading: data.loading,
    payments: data.payments,
    societyLedgerEntries: data.societyLedgerEntries,
    expenseCategoryById: data.expenseCategoryById,
    reserveTransfers: data.reserveTransfers,
    error: data.error,
    reload: data.loadAll,
  };
}
