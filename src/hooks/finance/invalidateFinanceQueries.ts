import type { QueryClient } from '@tanstack/react-query';
import { financeQueryKeys } from './financeQueryKeys';

/** Invalidate all society-scoped finance TanStack Query caches after a mutation. */
export function invalidateFinanceQueries(
  queryClient: QueryClient,
  societyId: string | null | undefined,
) {
  return Promise.all([
    queryClient.invalidateQueries({ queryKey: financeQueryKeys.core(societyId) }),
    queryClient.invalidateQueries({ queryKey: financeQueryKeys.flatReport(societyId) }),
    queryClient.invalidateQueries({ queryKey: financeQueryKeys.eventReference(societyId) }),
    queryClient.invalidateQueries({ queryKey: financeQueryKeys.periodReportBatch(societyId) }),
  ]);
}
