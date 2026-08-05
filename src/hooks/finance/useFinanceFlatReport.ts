import { useQuery } from '@tanstack/react-query';
import { fetchFinanceFlatReport } from '@/services/finance/financeService';
import { financeQueryKeys } from './financeQueryKeys';

export function useFinanceFlatReport(societyId: string | null | undefined, enabled = true) {
  const query = useQuery({
    queryKey: financeQueryKeys.flatReport(societyId),
    queryFn: () => fetchFinanceFlatReport(societyId!),
    enabled: Boolean(societyId) && enabled,
    staleTime: 60_000,
  });

  return {
    expenses: query.data?.expenses ?? [],
    splits: query.data?.splits ?? [],
    isLoading: query.isLoading,
    isFetching: query.isFetching,
    error: query.error,
    reload: () => query.refetch(),
  };
}
