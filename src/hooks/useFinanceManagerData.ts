import { useState, useCallback } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { sortFlatsByNumber } from '@/lib/flatMultiSelectOptions';
import {
  buildCurrentMonthChargeTitle,
  isCurrentMonthChargeTitle,
  isMonthlyMaintenanceCharge,
  normalizeTitle,
} from '@/lib/financeChargeHelpers';
import type { FinanceLedgerRow, SocietyFlatRow } from '@/lib/financeManagerTypes';

export function useFinanceManagerData(societyId: string | null, adminName: string) {
  const [charges, setCharges] = useState<unknown[]>([]);
  const [payments, setPayments] = useState<unknown[]>([]);
  const [ledgerEntries, setLedgerEntries] = useState<FinanceLedgerRow[]>([]);
  const [expenseCategoryById, setExpenseCategoryById] = useState<Map<string, string>>(new Map());
  const [flats, setFlats] = useState<SocietyFlatRow[]>([]);
  const [primaryByFlatId, setPrimaryByFlatId] = useState<Map<string, string>>(new Map());
  const [societyName, setSocietyName] = useState('');
  const [residentUsers, setResidentUsers] = useState<
    { id: string; name: string; flat_number: string; flat_id: string }[]
  >([]);
  const [paymentExpenseGroups, setPaymentExpenseGroups] = useState<
    { id: string; name: string; major_head: string | null }[]
  >([]);
  const [autoReminderEnabled, setAutoReminderEnabled] = useState(true);
  const [autoReminderSchedule, setAutoReminderSchedule] = useState<'once_12pm' | 'twice_12pm_7pm'>('once_12pm');

  const loadAll = useCallback(async () => {
    if (!societyId) {
      setCharges([]);
      setPayments([]);
      setFlats([]);
      setPrimaryByFlatId(new Map());
      setSocietyName('');
      setResidentUsers([]);
      return;
    }
    const { data: f } = await supabase
      .from('flats')
      .select('flat_number, id, owner_name, is_occupied')
      .eq('society_id', societyId)
      .order('flat_number');
    if (f) setFlats(sortFlatsByNumber(f));
    const flatIds = (f ?? []).map((x) => x.id);
    const mRes =
      flatIds.length > 0
        ? await supabase.from('members').select('flat_id, name').eq('is_primary', true).in('flat_id', flatIds)
        : { data: [] as { flat_id: string; name: string }[] };
    const map = new Map<string, string>();
    for (const row of mRes.data ?? []) {
      if (row.flat_id && row.name?.trim()) map.set(row.flat_id, row.name.trim());
    }
    setPrimaryByFlatId(map);

    const { data: soc } = await supabase.from('societies').select('name').eq('id', societyId).maybeSingle();
    setSocietyName((soc as { name?: string } | null)?.name ?? '');

    const ruRes =
      flatIds.length > 0
        ? await supabase.from('resident_users').select('id, name, flat_number, flat_id').in('flat_id', flatIds).order('flat_number')
        : { data: [] as { id: string; name: string; flat_number: string; flat_id: string }[] };
    setResidentUsers((ruRes.data ?? []) as { id: string; name: string; flat_number: string; flat_id: string }[]);

    const { data: reminderSetting } = await (supabase as any)
      .from('finance_reminder_settings')
      .select('enabled, schedule')
      .eq('society_id', societyId)
      .maybeSingle();
    if (reminderSetting) {
      setAutoReminderEnabled(!!reminderSetting.enabled);
      setAutoReminderSchedule(reminderSetting.schedule === 'twice_12pm_7pm' ? 'twice_12pm_7pm' : 'once_12pm');
    } else {
      setAutoReminderEnabled(true);
      setAutoReminderSchedule('once_12pm');
    }

    const { data: c } = await supabase
      .from('maintenance_charges')
      .select('*')
      .eq('society_id', societyId)
      .order('created_at', { ascending: false });
    let chargeRows = c ?? [];

    const monthlyMaintenanceCharges = chargeRows.filter(isMonthlyMaintenanceCharge);
    const hasCurrentMonthCharge = monthlyMaintenanceCharges.some((row) => isCurrentMonthChargeTitle(row.title));
    const templateCharge = monthlyMaintenanceCharges[0];

    if (!hasCurrentMonthCharge && templateCharge) {
      const currentTitle = buildCurrentMonthChargeTitle();
      const looksLikeCurrentChargeAlreadyExists = chargeRows.some(
        (row) => normalizeTitle(row.title) === normalizeTitle(currentTitle),
      );
      if (!looksLikeCurrentChargeAlreadyExists) {
        const { error: createMonthErr } = await supabase.from('maintenance_charges').insert([
          {
            title: currentTitle,
            amount: Number(templateCharge.amount) || 0,
            frequency: 'monthly',
            due_day: Number(templateCharge.due_day) || 1,
            created_by: adminName,
            society_id: societyId,
          },
        ]);
        if (!createMonthErr) {
          const { data: refreshedCharges } = await supabase
            .from('maintenance_charges')
            .select('*')
            .eq('society_id', societyId)
            .order('created_at', { ascending: false });
          chargeRows = refreshedCharges ?? chargeRows;
        }
      }
    }

    setCharges(chargeRows);

    const { data: pGroups } = await supabase
      .from('expense_groups')
      .select('id, name, major_head')
      .eq('society_id', societyId)
      .eq('group_kind', 'general')
      .order('name');
    setPaymentExpenseGroups((pGroups ?? []) as { id: string; name: string; major_head: string | null }[]);

    const chargeIds = chargeRows.map((x) => x.id);
    let payRows: unknown[] = [];
    if (chargeIds.length > 0) {
      const { data: p } = await supabase
        .from('maintenance_payments')
        .select('*')
        .in('charge_id', chargeIds)
        .order('created_at', { ascending: false })
        .limit(2500);
      payRows = p ?? [];
    }
    setPayments(payRows);

    const { data: led } = await supabase
      .from('finance_entries')
      .select('*, finance_entry_counterparties(*), finance_entry_allocations(*)')
      .eq('society_id', societyId)
      .order('created_at', { ascending: false })
      .limit(2500);
    const ledRows = (led as FinanceLedgerRow[]) ?? [];
    setLedgerEntries(ledRows);

    const linkedExpenseIds = ledRows.map((e) => e.expense_id).filter((id): id is string => Boolean(id));
    if (linkedExpenseIds.length > 0) {
      const { data: expCats } = await supabase
        .from('expenses')
        .select('id, expense_category')
        .in('id', linkedExpenseIds);
      setExpenseCategoryById(
        new Map(
          (expCats ?? []).map((row) => [
            String((row as { id: string }).id),
            String((row as { expense_category?: string }).expense_category ?? ''),
          ]),
        ),
      );
    } else {
      setExpenseCategoryById(new Map());
    }
  }, [societyId, adminName]);

  return {
    charges,
    setCharges,
    payments,
    setPayments,
    ledgerEntries,
    setLedgerEntries,
    expenseCategoryById,
    setExpenseCategoryById,
    flats,
    setFlats,
    primaryByFlatId,
    societyName,
    residentUsers,
    paymentExpenseGroups,
    setPaymentExpenseGroups,
    autoReminderEnabled,
    setAutoReminderEnabled,
    autoReminderSchedule,
    setAutoReminderSchedule,
    loadAll,
  };
}
