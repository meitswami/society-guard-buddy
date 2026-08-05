import { useQuery } from '@tanstack/react-query';
import { fetchReportModuleAggregations } from '@/lib/reportAggregations';
import { financeQueryKeys } from '@/hooks/finance/financeQueryKeys';

export function useReportModuleAggregations(
  societyId: string | null | undefined,
  periodFrom: string,
  periodTo: string,
  enabled = true,
) {
  const query = useQuery({
    queryKey: [...financeQueryKeys.all, 'module-aggregations', societyId, periodFrom, periodTo] as const,
    queryFn: () => fetchReportModuleAggregations(societyId!, periodFrom, periodTo),
    enabled: Boolean(societyId) && enabled && periodFrom <= periodTo,
    staleTime: 60_000,
  });

  return {
    maintenanceStatuses: query.data?.maintenanceStatuses ?? [],
    maintenanceLinkSummary: query.data?.maintenanceLinkSummary ?? null,
    donationStatuses: query.data?.donationStatuses ?? [],
    splitStatuses: query.data?.splitStatuses ?? [],
    isLoading: query.isLoading,
  };
}
