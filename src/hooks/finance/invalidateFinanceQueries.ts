import type { QueryClient } from '@tanstack/react-query';
import { financeQueryKeys } from './financeQueryKeys';

/** Invalidate all society-scoped finance TanStack Query caches after a mutation. */
export async function invalidateFinanceQueries(
  queryClient: QueryClient,
  societyId: string | null | undefined,
) {
  await Promise.all([
    queryClient.invalidateQueries({ queryKey: financeQueryKeys.core(societyId) }),
    queryClient.invalidateQueries({ queryKey: financeQueryKeys.flatReport(societyId) }),
    queryClient.invalidateQueries({ queryKey: financeQueryKeys.eventReference(societyId) }),
    queryClient.invalidateQueries({ queryKey: [...financeQueryKeys.all, 'module-aggregations', societyId] }),
    queryClient.invalidateQueries({ queryKey: financeQueryKeys.periodReportBatch(societyId) }),
  ]);
  await queryClient.refetchQueries({ queryKey: financeQueryKeys.all, type: 'active' });
}
