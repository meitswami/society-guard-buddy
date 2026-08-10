import { supabase } from '@/integrations/supabase/client';
import type { SocietyPaymentMajorHead } from '@/lib/financeExpenseHead';
import { uploadFinancePeriodReportPdf } from '@/lib/notificationMediaStorage';
import type { FinanceReminderSchedule } from '@/services/finance/financeService';
import { dispatchDirectoryChannels } from '@/lib/dispatchDirectoryChannels';
import { fetchSocietyNotificationSound } from '@/lib/societyNotificationSound';

export type MutationResult<T = void> = { data: T; error: null } | { data: null; error: string };

function err(message: string | undefined | null): MutationResult<never> {
  return { data: null, error: message ?? 'Unknown error' };
}

export type MaintenanceChargeInput = {
  title: string;
  amount: number;
  frequency: string;
  due_day: number;
  expense_group_id: string | null;
};

export type CreateExpenseGroupInput = {
  societyId: string;
  name: string;
  major_head: SocietyPaymentMajorHead;
  description?: string | null;
  created_by: string;
};

export async function createPaymentExpenseGroup(
  input: CreateExpenseGroupInput,
): Promise<MutationResult<{ id: string }>> {
  const { data, error } = await supabase
    .from('expense_groups')
    .insert({
      society_id: input.societyId,
      name: input.name,
      major_head: input.major_head,
      description: input.description?.trim() || null,
      group_kind: 'general',
      created_by: input.created_by,
    })
    .select('id')
    .single();
  if (error || !data) return err(error?.message ?? 'Could not create payment sub-head');
  return { data: { id: data.id }, error: null };
}

export type UpdateExpenseGroupInput = {
  societyId: string;
  groupId: string;
  name: string;
  description: string | null;
  major_head: SocietyPaymentMajorHead;
};

export async function updatePaymentExpenseGroup(input: UpdateExpenseGroupInput): Promise<MutationResult> {
  const { error } = await supabase
    .from('expense_groups')
    .update({
      name: input.name,
      description: input.description,
      major_head: input.major_head,
      event_id: null,
    })
    .eq('id', input.groupId)
    .eq('society_id', input.societyId);
  if (error) return err(error.message);
  return { data: undefined, error: null };
}

export async function deletePaymentExpenseGroup(societyId: string, groupId: string): Promise<MutationResult> {
  const { count, error: countErr } = await supabase
    .from('expenses')
    .select('id', { count: 'exact', head: true })
    .eq('group_id', groupId);
  if (countErr) return err(countErr.message);
  if ((count ?? 0) > 0) {
    return err('Remove all recorded payments in this head before deleting it.');
  }

  const { count: chargeCount, error: chargeErr } = await supabase
    .from('maintenance_charges')
    .select('id', { count: 'exact', head: true })
    .eq('expense_group_id', groupId)
    .eq('society_id', societyId);
  if (chargeErr) return err(chargeErr.message);
  if ((chargeCount ?? 0) > 0) {
    return err('Unlink or delete receipt types using this payment head first.');
  }

  const { error } = await supabase.from('expense_groups').delete().eq('id', groupId).eq('society_id', societyId);
  if (error) return err(error.message);
  return { data: undefined, error: null };
}

export async function updateMaintenanceCharge(
  societyId: string,
  chargeId: string,
  input: MaintenanceChargeInput,
): Promise<MutationResult> {
  const { error } = await supabase
    .from('maintenance_charges')
    .update({
      title: input.title,
      amount: input.amount,
      frequency: input.frequency,
      due_day: input.due_day,
      expense_group_id: input.expense_group_id,
    })
    .eq('id', chargeId)
    .eq('society_id', societyId);
  if (error) return err(error.message);
  return { data: undefined, error: null };
}

export async function insertMaintenanceCharge(
  societyId: string,
  adminName: string,
  input: MaintenanceChargeInput,
): Promise<MutationResult> {
  const { error } = await supabase.from('maintenance_charges').insert([
    {
      title: input.title,
      amount: input.amount,
      frequency: input.frequency,
      due_day: input.due_day,
      created_by: adminName,
      society_id: societyId,
      expense_group_id: input.expense_group_id,
    },
  ]);
  if (error) return err(error.message);
  return { data: undefined, error: null };
}

export async function deleteMaintenanceCharge(societyId: string, chargeId: string): Promise<MutationResult> {
  const { error } = await supabase
    .from('maintenance_charges')
    .delete()
    .eq('id', chargeId)
    .eq('society_id', societyId);
  if (error) return err(error.message);
  return { data: undefined, error: null };
}

export type FinanceEntryAllocationRow = {
  flat_number: string;
  flat_id: string | null;
  amount: number;
};

export type DistributePoolInput = {
  entryId: string;
  allocationRows: FinanceEntryAllocationRow[];
  maintenancePaymentRows: Record<string, unknown>[];
  aggregateFlatCount: number;
  title: string;
};

export async function distributePoolToAllFlats(input: DistributePoolInput): Promise<MutationResult> {
  const { error: allocErr } = await supabase.from('finance_entry_allocations').insert(
    input.allocationRows.map((a) => ({
      finance_entry_id: input.entryId,
      flat_id: a.flat_id,
      flat_number: a.flat_number,
      amount: a.amount,
    })),
  );
  if (allocErr) return err(allocErr.message);

  if (input.maintenancePaymentRows.length > 0) {
    const { error: payErr } = await supabase.from('maintenance_payments').insert(input.maintenancePaymentRows);
    if (payErr) {
      await supabase.from('finance_entry_allocations').delete().eq('finance_entry_id', input.entryId);
      return err(payErr.message);
    }
  }

  const now = new Date().toISOString();
  const { error: updErr } = await supabase
    .from('finance_entries')
    .update({
      allocation_style: 'split_total_equally',
      aggregate_flat_count: input.aggregateFlatCount,
      distributed_at: now,
      title: input.title,
    })
    .eq('id', input.entryId);
  if (updErr) return err(updErr.message);

  return { data: undefined, error: null };
}

export type FinanceEntryInsert = Record<string, unknown>;

export type PersistFinanceRecordInput = {
  entry: FinanceEntryInsert;
  counterparty?: { name: string; relation_to_society: string | null };
  allocations: FinanceEntryAllocationRow[];
  maintenancePayments: Record<string, unknown>[];
};

export async function persistFinanceRecord(
  input: PersistFinanceRecordInput,
): Promise<MutationResult<{ entryId: string }>> {
  const { data: feRow, error: feErr } = await supabase
    .from('finance_entries')
    .insert(input.entry)
    .select('id')
    .single();
  if (feErr || !feRow?.id) return err(feErr?.message ?? 'Could not save finance entry');

  const entryId = feRow.id as string;

  if (input.counterparty) {
    const { error: cpErr } = await supabase.from('finance_entry_counterparties').insert({
      finance_entry_id: entryId,
      name: input.counterparty.name,
      relation_to_society: input.counterparty.relation_to_society,
    });
    if (cpErr) return err(cpErr.message);
  }

  if (input.allocations.length > 0) {
    const { error: allocErr } = await supabase.from('finance_entry_allocations').insert(
      input.allocations.map((a) => ({
        finance_entry_id: entryId,
        flat_id: a.flat_id,
        flat_number: a.flat_number,
        amount: a.amount,
      })),
    );
    if (allocErr) return err(allocErr.message);
  }

  if (input.maintenancePayments.length > 0) {
    const { error: payErr } = await supabase
      .from('maintenance_payments')
      .insert(input.maintenancePayments.map((row) => ({ ...row, finance_entry_id: entryId })));
    if (payErr) return err(payErr.message);
  }

  return { data: { entryId }, error: null };
}

export type PaymentDecisionNotifyInput = {
  societyId: string;
  adminName: string;
  flatNumber: string;
  title: string;
  message: string;
};

export async function notifyPaymentDecision(input: PaymentDecisionNotifyInput): Promise<void> {
  const sound = await fetchSocietyNotificationSound(input.societyId);
  await (supabase as any).from('notifications').insert([
    {
      society_id: input.societyId,
      title: input.title,
      message: input.message,
      type: 'maintenance_payment_decision',
      target_type: 'flat',
      target_id: input.flatNumber,
      created_by: input.adminName,
      sound_key: sound.sound_key,
      sound_custom_url: sound.sound_custom_url,
    },
  ]);
  await supabase.functions.invoke('send-push-notification', {
    body: {
      title: input.title,
      message: input.message,
      target_type: 'flat',
      target_flat_numbers: [input.flatNumber],
      target_ids: [],
      media_items: [],
      society_id: input.societyId,
      sound_key: sound.sound_key,
      sound_custom_url: sound.sound_custom_url ?? '',
    },
  });
  await dispatchDirectoryChannels({
    societyId: input.societyId,
    title: input.title,
    message: input.message,
    channels: { whatsapp: true, email: true },
    target: { type: 'flat', flatNumbers: [input.flatNumber] },
  });
}

export type MaintenancePaymentStatus = 'pending' | 'verified' | 'rejected';

export async function updateMaintenancePaymentStatus(
  paymentId: string,
  status: MaintenancePaymentStatus,
  adminName: string,
  reason?: string,
): Promise<MutationResult> {
  const reviewedAt = new Date().toISOString();
  let payload: Record<string, unknown>;

  if (status === 'verified') {
    payload = {
      payment_status: 'verified',
      verified_by: adminName,
      verified_at: reviewedAt,
      reviewed_at: reviewedAt,
      rejection_reason: null,
    };
  } else if (status === 'rejected') {
    payload = {
      payment_status: 'rejected',
      verified_by: adminName,
      verified_at: reviewedAt,
      reviewed_at: reviewedAt,
      rejection_reason: reason?.trim() || 'Rejected by admin',
    };
  } else {
    payload = {
      payment_status: 'pending',
      verified_by: null,
      verified_at: null,
      reviewed_at: null,
      rejection_reason: null,
    };
  }

  const { error } = await (supabase as any).from('maintenance_payments').update(payload).eq('id', paymentId);
  if (error) return err(error.message);
  return { data: undefined, error: null };
}

export async function updateMaintenancePayment(
  paymentId: string,
  payload: Record<string, unknown>,
): Promise<MutationResult> {
  const { error } = await (supabase as any).from('maintenance_payments').update(payload).eq('id', paymentId);
  if (error) return err(error.message);
  return { data: undefined, error: null };
}

export type MaintenancePaymentDeleteRow = {
  id: string;
  flat_number: string;
  finance_entry_id?: string | null;
};

export async function deleteMaintenancePaymentRow(p: MaintenancePaymentDeleteRow): Promise<MutationResult> {
  const feId = p.finance_entry_id as string | null | undefined;
  if (feId) {
    await supabase
      .from('finance_entry_allocations')
      .delete()
      .eq('finance_entry_id', feId)
      .eq('flat_number', String(p.flat_number));
  }
  await supabase.from('maintenance_payments').delete().eq('id', p.id);
  if (feId) {
    const { data: restAllocs } = await supabase
      .from('finance_entry_allocations')
      .select('amount')
      .eq('finance_entry_id', feId);
    const { data: restMps } = await supabase
      .from('maintenance_payments')
      .select('id')
      .eq('finance_entry_id', feId);
    const total = restAllocs?.reduce((s, a) => s + Number(a.amount), 0) ?? 0;
    const acount = restAllocs?.length ?? 0;
    const mpLeft = restMps?.length ?? 0;
    if (acount === 0 && mpLeft === 0) {
      await supabase.from('finance_entries').delete().eq('id', feId);
    } else if (acount > 0) {
      await supabase
        .from('finance_entries')
        .update({ total_amount: total, aggregate_flat_count: acount })
        .eq('id', feId);
    } else if (mpLeft > 0) {
      await supabase.from('maintenance_payments').update({ finance_entry_id: null }).eq('finance_entry_id', feId);
      await supabase.from('finance_entries').delete().eq('id', feId);
    }
  }
  return { data: undefined, error: null };
}

export async function updateFinanceEntryStatus(
  entryId: string,
  payment_status: string,
): Promise<MutationResult> {
  const { error } = await supabase.from('finance_entries').update({ payment_status }).eq('id', entryId);
  if (error) return err(error.message);
  return { data: undefined, error: null };
}

export async function updateFinanceEntry(
  entryId: string,
  payload: Record<string, unknown>,
): Promise<MutationResult> {
  const { error } = await supabase.from('finance_entries').update(payload).eq('id', entryId);
  if (error) return err(error.message);
  return { data: undefined, error: null };
}

export async function deleteFinanceEntry(entryId: string): Promise<MutationResult> {
  const { error } = await supabase.from('finance_entries').delete().eq('id', entryId);
  if (error) return err(error.message);
  return { data: undefined, error: null };
}

export async function sendMaintenanceReminders(
  societyId: string,
  adminName: string,
  flatNumbers: string[],
): Promise<MutationResult> {
  const flats = [...new Set(flatNumbers.filter(Boolean))];
  if (flats.length === 0) return { data: undefined, error: null };

  const title = 'Maintenance Due Reminder';
  const sound = await fetchSocietyNotificationSound(societyId);
  for (const flatNumber of flats) {
    const { error } = await supabase.from('notifications').insert([
      {
        society_id: societyId,
        title,
        message: `Dear resident of Flat ${flatNumber}, your maintenance payment is due. Please pay at the earliest.`,
        type: 'payment_reminder',
        target_type: 'flat',
        target_id: flatNumber,
        created_by: adminName,
        sound_key: sound.sound_key,
        sound_custom_url: sound.sound_custom_url,
      },
    ]);
    if (error) return err(error.message);
  }

  try {
    await supabase.functions.invoke('send-push-notification', {
      body: {
        title,
        message: 'Your maintenance payment is due. Please pay at the earliest.',
        target_type: 'flat',
        target_flat_numbers: flats,
        target_ids: [],
        media_items: [],
        society_id: societyId,
        sound_key: sound.sound_key,
        sound_custom_url: sound.sound_custom_url ?? '',
      },
    });
  } catch (e) {
    console.warn('Push invoke failed', e);
  }

  try {
    const { data: settings } = await (supabase as any)
      .from('finance_reminder_settings')
      .select('reminder_whatsapp, reminder_email')
      .eq('society_id', societyId)
      .maybeSingle();
    const wantWa = settings?.reminder_whatsapp === true;
    const wantEmail = settings?.reminder_email === true;
    if (wantWa || wantEmail) {
      await dispatchDirectoryChannels({
        societyId,
        title,
        message: 'Your maintenance payment is due. Please pay at the earliest.',
        channels: { whatsapp: wantWa, email: wantEmail },
        target: { type: 'flat', flatNumbers: flats },
      });
    }
  } catch (e) {
    console.warn('Directory channel reminder failed', e);
  }

  return { data: undefined, error: null };
}

export async function upsertFinanceReminderSettings(
  societyId: string,
  enabled: boolean,
  schedule: FinanceReminderSchedule,
  dueDay: number,
  opts?: {
    autoIssueEnabled?: boolean;
    autoIssueWhatsapp?: boolean;
    autoIssueEmail?: boolean;
    reminderWhatsapp?: boolean;
    reminderEmail?: boolean;
    billSoundKey?: string;
  },
): Promise<MutationResult> {
  const normalizedDueDay = Math.min(28, Math.max(1, Number(dueDay) || 1));
  const { error } = await (supabase as any).from('finance_reminder_settings').upsert(
    {
      society_id: societyId,
      enabled,
      schedule,
      due_day: normalizedDueDay,
      timezone: 'Asia/Kolkata',
      auto_issue_enabled: opts?.autoIssueEnabled ?? true,
      auto_issue_whatsapp: opts?.autoIssueWhatsapp ?? true,
      auto_issue_email: opts?.autoIssueEmail ?? false,
      reminder_whatsapp: opts?.reminderWhatsapp ?? false,
      reminder_email: opts?.reminderEmail ?? false,
      bill_sound_key: opts?.billSoundKey || 'melody',
      updated_at: new Date().toISOString(),
    },
    { onConflict: 'society_id' },
  );
  if (error) return err(error.message);
  return { data: undefined, error: null };
}

export async function invokeMaintenanceReminderTest(societyId: string): Promise<MutationResult<{ sent: number }>> {
  const { data, error } = await supabase.functions.invoke('maintenance-reminder', {
    body: {
      society_id: societyId,
      force_slot: '12pm',
    },
  });
  if (error) return err(String((error as { message?: string })?.message || 'Unknown function error'));
  return { data: { sent: Number((data as { sent?: number })?.sent ?? 0) }, error: null };
}

export type MonthlyBillIssueResult = {
  issued: number;
  flats?: number;
  whatsapp_sent?: number;
  whatsapp_failed?: number;
  whatsapp_configured?: boolean;
  charge_title?: string;
  amount?: number;
  note?: string;
};

export async function invokeIssueMonthlyMaintenance(
  societyId: string,
  force = true,
): Promise<MutationResult<MonthlyBillIssueResult>> {
  const { data, error } = await supabase.functions.invoke('issue-monthly-maintenance', {
    body: {
      society_id: societyId,
      force,
      amount: 2500,
    },
  });
  if (error) return err(String((error as { message?: string })?.message || 'Unknown function error'));
  const payload = data as {
    issued?: number;
    results?: Array<{
      flats?: number;
      whatsapp_sent?: number;
      whatsapp_failed?: number;
      whatsapp_configured?: boolean;
      charge_title?: string;
      amount?: number;
      skipped?: string;
    }>;
  };
  const first = payload?.results?.[0];
  return {
    data: {
      issued: Number(payload?.issued ?? 0),
      flats: first?.flats,
      whatsapp_sent: first?.whatsapp_sent,
      whatsapp_failed: first?.whatsapp_failed,
      whatsapp_configured: first?.whatsapp_configured,
      charge_title: first?.charge_title,
      amount: first?.amount,
      note: first?.skipped,
    },
    error: null,
  };
}

export type PeriodReportNotificationRow = {
  title: string;
  message: string;
  type: string;
  target_type: string;
  target_id: string;
  society_id: string;
  created_by: string;
  sound_key: string;
  sound_custom_url: string | null;
  delivery_batch_id?: string;
  is_read: boolean;
};

export async function insertNotificationRows(rows: PeriodReportNotificationRow[]): Promise<MutationResult> {
  const { error } = await supabase.from('notifications').insert(rows);
  if (error) return err(error.message);
  return { data: undefined, error: null };
}

export async function sendPushNotification(body: Record<string, unknown>): Promise<void> {
  try {
    await supabase.functions.invoke('send-push-notification', { body });
  } catch (e) {
    console.warn('Push invoke failed', e);
  }
}

export async function sendFinancePeriodReportToMembers(input: {
  societyId: string;
  adminName: string;
  periodLabel: string;
  summaryMessage: string;
  pdfBlob: Blob;
  flatNumbers: string[];
  sendPush: boolean;
}): Promise<MutationResult<{ batchId: string }>> {
  const flats = [...new Set(input.flatNumbers.filter(Boolean))];
  if (flats.length === 0) return err('No flats to notify');

  const batchId = crypto.randomUUID();
  const pdfUrl = await uploadFinancePeriodReportPdf(input.societyId, batchId, input.pdfBlob);
  if (!pdfUrl) return err('Could not upload period report PDF');

  const title = `Finance report · ${input.periodLabel}`;
  const message = `${input.summaryMessage} Open Alerts for details. PDF: ${pdfUrl}`;
  const sound = await fetchSocietyNotificationSound(input.societyId);

  const rows: PeriodReportNotificationRow[] = flats.map((flat) => ({
    title,
    message,
    type: 'finance_period_report',
    target_type: 'flat',
    target_id: flat,
    society_id: input.societyId,
    created_by: input.adminName,
    sound_key: sound.sound_key,
    sound_custom_url: sound.sound_custom_url,
    delivery_batch_id: batchId,
    is_read: false,
  }));

  const insertResult = await insertNotificationRows(rows);
  if (insertResult.error) return insertResult;

  if (input.sendPush) {
    await sendPushNotification({
      title,
      message: input.summaryMessage,
      target_type: 'flat',
      target_flat_numbers: flats,
      target_ids: [],
      media_items: [],
      society_id: input.societyId,
      sound_key: sound.sound_key,
      sound_custom_url: sound.sound_custom_url ?? '',
    });
  }

  return { data: { batchId }, error: null };
}

export async function recallFinancePeriodReportNotifications(
  societyId: string,
  batchId: string,
): Promise<MutationResult<{ targetIds: string[] }>> {
  const { data: batchRows, error: fetchErr } = await supabase
    .from('notifications')
    .select('target_id')
    .eq('delivery_batch_id', batchId)
    .eq('society_id', societyId)
    .eq('type', 'finance_period_report');
  if (fetchErr) return err(fetchErr.message);

  const targetIds = [...new Set((batchRows ?? []).map((r) => r.target_id).filter(Boolean))] as string[];

  const { error: delErr } = await supabase
    .from('notifications')
    .delete()
    .eq('delivery_batch_id', batchId)
    .eq('society_id', societyId)
    .eq('type', 'finance_period_report');
  if (delErr) return err(delErr.message);

  const path = `finance-reports/${societyId}/${batchId}.pdf`;
  await supabase.storage.from('notification-media').remove([path]);

  return { data: { targetIds }, error: null };
}

export async function fetchNotificationReadStatus(batchId: string) {
  return supabase
    .from('notifications')
    .select('id, target_id, is_read, read_at')
    .eq('delivery_batch_id', batchId)
    .order('target_id');
}
