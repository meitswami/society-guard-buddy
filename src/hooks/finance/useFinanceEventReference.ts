import { useQuery } from '@tanstack/react-query';
import { fetchFinanceEventReference } from '@/services/finance/financeService';
import { financeQueryKeys } from './financeQueryKeys';

export function useFinanceEventReference(societyId: string | null | undefined, enabled = true) {
  const query = useQuery({
    queryKey: financeQueryKeys.eventReference(societyId),
    queryFn: () => fetchFinanceEventReference(societyId!),
    enabled: Boolean(societyId) && enabled,
    staleTime: 60_000,
  });

  return {
    contributions: query.data?.contributions ?? [],
    foodExpenses: query.data?.foodExpenses ?? [],
    isLoading: query.isLoading,
    isFetching: query.isFetching,
    error: query.error,
    reload: () => query.refetch(),
  };
}
