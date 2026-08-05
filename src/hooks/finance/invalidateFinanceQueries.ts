import type { QueryClient } from '@tanstack/react-query';
import { financeQueryKeys } from './financeQueryKeys';

/** Invalidate society-scoped finance caches after a mutation (active queries refetch once). */
export async function invalidateFinanceQueries(
  queryClient: QueryClient,
  _societyId: string | null | undefined,
) {
  await queryClient.invalidateQueries({ queryKey: financeQueryKeys.all });
}
