import { useEffect, useMemo, useState } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { fetchSocietyFinanceCoreSafe } from '@/services/finance/financeService';
import type { FinanceLedgerRow } from '@/lib/financeManagerTypes';
import { financeQueryKeys } from '@/hooks/finance/financeQueryKeys';
import { invalidateFinanceQueries } from '@/hooks/finance/invalidateFinanceQueries';

function recordToMap(record: Record<string, string>) {
  return new Map(Object.entries(record));
}

/** Society-scoped finance data for FinanceManager (TanStack Query + service layer). */
export function useFinanceManagerData(societyId: string | null, adminName: string) {
  const queryClient = useQueryClient();
  const query = useQuery({
    queryKey: financeQueryKeys.core(societyId),
    queryFn: () => fetchSocietyFinanceCoreSafe(societyId, adminName),
    enabled: Boolean(societyId),
    staleTime: 60_000,
    placeholderData: (previousData) => previousData,
  });

  const expenseCategoryById = useMemo(
    () => recordToMap(query.data?.expenseCategoryById ?? {}),
    [query.data?.expenseCategoryById],
  );
  const primaryByFlatId = useMemo(
    () => recordToMap(query.data?.primaryByFlatId ?? {}),
    [query.data?.primaryByFlatId],
  );

  const [autoReminderEnabled, setAutoReminderEnabled] = useState(true);
  const [autoReminderSchedule, setAutoReminderSchedule] = useState<'once_12pm' | 'twice_12pm_7pm'>('once_12pm');
  const [reminderDueDay, setReminderDueDay] = useState(1);
  const [autoIssueEnabled, setAutoIssueEnabled] = useState(true);
  const [autoIssueWhatsapp, setAutoIssueWhatsapp] = useState(true);
  const [autoIssueEmail, setAutoIssueEmail] = useState(false);
  const [reminderWhatsapp, setReminderWhatsapp] = useState(false);
  const [reminderEmail, setReminderEmail] = useState(false);
  const [billSoundKey, setBillSoundKey] = useState('melody');

  useEffect(() => {
    if (query.data) {
      setAutoReminderEnabled(query.data.autoReminderEnabled);
      setAutoReminderSchedule(query.data.autoReminderSchedule);
      setReminderDueDay(query.data.reminderDueDay);
      setAutoIssueEnabled(query.data.autoIssueEnabled);
      setAutoIssueWhatsapp(query.data.autoIssueWhatsapp);
      setAutoIssueEmail(query.data.autoIssueEmail);
      setReminderWhatsapp(query.data.reminderWhatsapp);
      setReminderEmail(query.data.reminderEmail);
      setBillSoundKey(query.data.billSoundKey);
    }
  }, [
    query.data?.autoReminderEnabled,
    query.data?.autoReminderSchedule,
    query.data?.reminderDueDay,
    query.data?.autoIssueEnabled,
    query.data?.autoIssueWhatsapp,
    query.data?.autoIssueEmail,
    query.data?.reminderWhatsapp,
    query.data?.reminderEmail,
    query.data?.billSoundKey,
    query.data,
  ]);

  const loadAll = async () => {
    await invalidateFinanceQueries(queryClient, societyId);
  };

  const invalidate = () => {
    void queryClient.invalidateQueries({ queryKey: financeQueryKeys.core(societyId) });
  };

  return {
    charges: query.data?.charges ?? [],
    payments: query.data?.payments ?? [],
    ledgerEntries: (query.data?.ledgerEntries ?? []) as FinanceLedgerRow[],
    expenseCategoryById,
    flats: query.data?.flats ?? [],
    primaryByFlatId,
    societyName: query.data?.societyName ?? '',
    residentUsers: query.data?.residentUsers ?? [],
    paymentExpenseGroups: query.data?.paymentExpenseGroups ?? [],
    reserveTransfers: query.data?.reserveTransfers ?? [],
    autoReminderEnabled,
    setAutoReminderEnabled,
    autoReminderSchedule,
    setAutoReminderSchedule,
    reminderDueDay,
    setReminderDueDay,
    autoIssueEnabled,
    setAutoIssueEnabled,
    autoIssueWhatsapp,
    setAutoIssueWhatsapp,
    autoIssueEmail,
    setAutoIssueEmail,
    reminderWhatsapp,
    setReminderWhatsapp,
    reminderEmail,
    setReminderEmail,
    billSoundKey,
    setBillSoundKey,
    isLoading: query.isLoading,
    isFetching: query.isFetching,
    error: query.error,
    loadAll,
    invalidate,
  };
}
