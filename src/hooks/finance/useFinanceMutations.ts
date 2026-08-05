import { useCallback } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import {
  createPaymentExpenseGroup,
  deleteFinanceEntry,
  deleteMaintenanceCharge,
  deleteMaintenancePaymentRow,
  deletePaymentExpenseGroup,
  distributePoolToAllFlats,
  insertMaintenanceCharge,
  insertNotificationRows,
  invokeMaintenanceReminderTest,
  notifyPaymentDecision,
  persistFinanceRecord,
  recallFinancePeriodReportNotifications,
  sendMaintenanceReminders,
  sendFinancePeriodReportToMembers,
  sendPushNotification,
  updateFinanceEntry,
  updateFinanceEntryStatus,
  updateMaintenanceCharge,
  updateMaintenancePayment,
  updateMaintenancePaymentStatus,
  updatePaymentExpenseGroup,
  upsertFinanceReminderSettings,
  type CreateExpenseGroupInput,
  type UpdateExpenseGroupInput,
  type DistributePoolInput,
  type MaintenanceChargeInput,
  type MaintenancePaymentDeleteRow,
  type MaintenancePaymentStatus,
  type PaymentDecisionNotifyInput,
  type PersistFinanceRecordInput,
  type PeriodReportNotificationRow,
} from '@/services/finance/financeMutations';
import { invalidateFinanceQueries } from './invalidateFinanceQueries';

function assertNoError<T>(result: { data: T; error: null } | { data: null; error: string }): T {
  if (result.error) throw new Error(result.error);
  return result.data;
}

/** TanStack Query mutations for FinanceManager with automatic cache invalidation. */
export function useFinanceMutations(societyId: string | null) {
  const queryClient = useQueryClient();

  const invalidateAll = useCallback(async () => {
    await invalidateFinanceQueries(queryClient, societyId);
  }, [queryClient, societyId]);

  const withInvalidate = useCallback(
    <T, V>(mutationFn: (vars: V) => Promise<{ data: T; error: null } | { data: null; error: string }>) => ({
      mutationFn: async (vars: V) => assertNoError(await mutationFn(vars)),
      // Await so mutateAsync callers don't need a second loadAll()/invalidate.
      onSuccess: () => invalidateAll(),
    }),
    [invalidateAll],
  );

  const createExpenseGroup = useMutation(
    withInvalidate((input: CreateExpenseGroupInput) => createPaymentExpenseGroup(input)),
  );

  const saveExpenseGroup = useMutation(
    withInvalidate((input: UpdateExpenseGroupInput) => updatePaymentExpenseGroup(input)),
  );

  const deleteExpenseGroup = useMutation(
    withInvalidate((groupId: string) => {
      if (!societyId) return Promise.resolve({ data: null, error: 'No society selected' });
      return deletePaymentExpenseGroup(societyId, groupId);
    }),
  );

  const saveCharge = useMutation(
    withInvalidate(
      (input: { chargeId?: string; charge: MaintenanceChargeInput; adminName: string }) => {
        if (!societyId) return Promise.resolve({ data: null, error: 'No society selected' });
        if (input.chargeId) {
          return updateMaintenanceCharge(societyId, input.chargeId, input.charge);
        }
        return insertMaintenanceCharge(societyId, input.adminName, input.charge);
      },
    ),
  );

  const deleteCharge = useMutation(
    withInvalidate((chargeId: string) => {
      if (!societyId) return Promise.resolve({ data: null, error: 'No society selected' });
      return deleteMaintenanceCharge(societyId, chargeId);
    }),
  );

  const distributePool = useMutation(withInvalidate((input: DistributePoolInput) => distributePoolToAllFlats(input)));

  const recordFinanceEntry = useMutation(withInvalidate((input: PersistFinanceRecordInput) => persistFinanceRecord(input)));

  const setPaymentStatus = useMutation(
    withInvalidate(
      (input: {
        paymentId: string;
        status: MaintenancePaymentStatus;
        adminName: string;
        reason?: string;
      }) => updateMaintenancePaymentStatus(input.paymentId, input.status, input.adminName, input.reason),
    ),
  );

  const savePayment = useMutation(
    withInvalidate((input: { paymentId: string; payload: Record<string, unknown> }) =>
      updateMaintenancePayment(input.paymentId, input.payload),
    ),
  );

  const removePayment = useMutation(
    withInvalidate((row: MaintenancePaymentDeleteRow) => deleteMaintenancePaymentRow(row)),
  );

  const setLedgerStatus = useMutation(
    withInvalidate((input: { entryId: string; payment_status: string }) =>
      updateFinanceEntryStatus(input.entryId, input.payment_status),
    ),
  );

  const saveLedger = useMutation(
    withInvalidate((input: { entryId: string; payload: Record<string, unknown> }) =>
      updateFinanceEntry(input.entryId, input.payload),
    ),
  );

  const removeLedger = useMutation(withInvalidate((entryId: string) => deleteFinanceEntry(entryId)));

  const sendReminders = useMutation(
    withInvalidate((input: { adminName: string; flatNumbers: string[] }) => {
      if (!societyId) return Promise.resolve({ data: null, error: 'No society selected' });
      return sendMaintenanceReminders(societyId, input.adminName, input.flatNumbers);
    }),
  );

  const saveReminderSettings = useMutation(
    withInvalidate((input: { enabled: boolean; schedule: 'once_12pm' | 'twice_12pm_7pm'; dueDay: number }) => {
      if (!societyId) return Promise.resolve({ data: null, error: 'No society selected' });
      return upsertFinanceReminderSettings(societyId, input.enabled, input.schedule, input.dueDay);
    }),
  );

  const testReminder = useMutation({
    mutationFn: async () => {
      if (!societyId) throw new Error('No society selected');
      return assertNoError(await invokeMaintenanceReminderTest(societyId));
    },
  });

  const notifyPayment = useMutation({
    mutationFn: (input: PaymentDecisionNotifyInput) => notifyPaymentDecision(input),
  });

  const insertNotifications = useMutation({
    mutationFn: async (rows: PeriodReportNotificationRow[]) => assertNoError(await insertNotificationRows(rows)),
  });

  const recallPeriodReport = useMutation({
    mutationFn: async (batchId: string) => {
      if (!societyId) throw new Error('No society selected');
      return assertNoError(await recallFinancePeriodReportNotifications(societyId, batchId));
    },
    onSuccess: () => void invalidateAll(),
  });

  const sendPeriodReportToMembers = useMutation({
    mutationFn: async (input: Omit<Parameters<typeof sendFinancePeriodReportToMembers>[0], 'societyId'>) => {
      if (!societyId) throw new Error('No society selected');
      return assertNoError(await sendFinancePeriodReportToMembers({ ...input, societyId }));
    },
    onSuccess: () => void invalidateAll(),
  });

  return {
    invalidateAll,
    createExpenseGroup: createExpenseGroup.mutateAsync,
    saveExpenseGroup: saveExpenseGroup.mutateAsync,
    deleteExpenseGroup: deleteExpenseGroup.mutateAsync,
    saveCharge: saveCharge.mutateAsync,
    deleteCharge: deleteCharge.mutateAsync,
    distributePool: distributePool.mutateAsync,
    recordFinanceEntry: recordFinanceEntry.mutateAsync,
    setPaymentStatus: setPaymentStatus.mutateAsync,
    savePayment: savePayment.mutateAsync,
    removePayment: removePayment.mutateAsync,
    setLedgerStatus: setLedgerStatus.mutateAsync,
    saveLedger: saveLedger.mutateAsync,
    removeLedger: removeLedger.mutateAsync,
    sendReminders: sendReminders.mutateAsync,
    saveReminderSettings: saveReminderSettings.mutateAsync,
    testReminder: testReminder.mutateAsync,
    notifyPayment: notifyPayment.mutateAsync,
    insertNotifications: insertNotifications.mutateAsync,
    recallPeriodReport: recallPeriodReport.mutateAsync,
    sendPeriodReportToMembers: sendPeriodReportToMembers.mutateAsync,
    sendPushNotification,
    isPending:
      createExpenseGroup.isPending ||
      saveExpenseGroup.isPending ||
      deleteExpenseGroup.isPending ||
      saveCharge.isPending ||
      deleteCharge.isPending ||
      distributePool.isPending ||
      recordFinanceEntry.isPending ||
      setPaymentStatus.isPending ||
      savePayment.isPending ||
      removePayment.isPending ||
      setLedgerStatus.isPending ||
      saveLedger.isPending ||
      removeLedger.isPending ||
      sendReminders.isPending ||
      saveReminderSettings.isPending ||
      testReminder.isPending ||
      recallPeriodReport.isPending ||
      sendPeriodReportToMembers.isPending,
  };
}
