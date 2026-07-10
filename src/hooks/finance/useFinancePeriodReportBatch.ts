import { useQuery } from '@tanstack/react-query';
import { fetchLatestFinancePeriodReportBatch } from '@/services/finance/financeService';
import { financeQueryKeys } from './financeQueryKeys';

export function useFinancePeriodReportBatch(societyId: string | null | undefined, enabled = true) {
  const query = useQuery({
    queryKey: financeQueryKeys.periodReportBatch(societyId),
    queryFn: () => fetchLatestFinancePeriodReportBatch(societyId!),
    enabled: Boolean(societyId) && enabled,
  });

  return {
    batchId: query.data ?? null,
    isLoading: query.isLoading,
    error: query.error,
    reload: () => query.refetch(),
  };
}
