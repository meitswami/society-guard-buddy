import { useMemo } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { fetchSocietyFinanceCoreSafe } from '@/services/finance/financeService';
import { financeQueryKeys } from './financeQueryKeys';

function recordToMap(record: Record<string, string>) {
  return new Map(Object.entries(record));
}

export function useSocietyFinanceCore(societyId: string | null | undefined, adminName: string) {
  const queryClient = useQueryClient();
  const query = useQuery({
    queryKey: financeQueryKeys.core(societyId),
    queryFn: () => fetchSocietyFinanceCoreSafe(societyId, adminName),
    enabled: Boolean(societyId),
  });

  const expenseCategoryById = useMemo(
    () => recordToMap(query.data?.expenseCategoryById ?? {}),
    [query.data?.expenseCategoryById],
  );
  const primaryByFlatId = useMemo(
    () => recordToMap(query.data?.primaryByFlatId ?? {}),
    [query.data?.primaryByFlatId],
  );

  const reload = async () => {
    await query.refetch();
  };

  const invalidate = () => {
    void queryClient.invalidateQueries({ queryKey: financeQueryKeys.core(societyId) });
  };

  return {
    flats: query.data?.flats ?? [],
    primaryByFlatId,
    societyName: query.data?.societyName ?? '',
    residentUsers: query.data?.residentUsers ?? [],
    autoReminderEnabled: query.data?.autoReminderEnabled ?? true,
    autoReminderSchedule: query.data?.autoReminderSchedule ?? 'once_12pm',
    charges: query.data?.charges ?? [],
    paymentExpenseGroups: query.data?.paymentExpenseGroups ?? [],
    payments: query.data?.payments ?? [],
    ledgerEntries: query.data?.ledgerEntries ?? [],
    expenseCategoryById,
    isLoading: query.isLoading,
    isFetching: query.isFetching,
    error: query.error,
    reload,
    invalidate,
  };
}
