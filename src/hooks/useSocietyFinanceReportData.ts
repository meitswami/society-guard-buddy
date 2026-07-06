import { useEffect, useMemo, useState } from 'react';
import { supabase } from '@/integrations/supabase/client';
import {
  filterSocietyLedgerEntries,
  type FinancePeriodLedgerEntry,
  type FinancePeriodPayment,
  type FinancePeriodReserveTransfer,
} from '@/lib/financePeriodReport';

/** Loads society finance data using the same queries as Finance module. */
export function useSocietyFinanceReportData(societyId: string | undefined) {
  const [payments, setPayments] = useState<FinancePeriodPayment[]>([]);
  const [ledgerEntries, setLedgerEntries] = useState<FinancePeriodLedgerEntry[]>([]);
  const [expenseCategoryById, setExpenseCategoryById] = useState<Map<string, string>>(new Map());
  const [reserveTransfers, setReserveTransfers] = useState<FinancePeriodReserveTransfer[]>([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    const load = async () => {
      if (!societyId) {
        setPayments([]);
        setLedgerEntries([]);
        setExpenseCategoryById(new Map());
        setReserveTransfers([]);
        return;
      }
      setLoading(true);

      const { data: chargeRows } = await supabase.from('maintenance_charges').select('id').eq('society_id', societyId);
      const chargeIds = (chargeRows as { id: string }[] | null)?.map((c) => c.id) ?? [];

      let payRows: FinancePeriodPayment[] = [];
      if (chargeIds.length > 0) {
        const { data: p } = await supabase
          .from('maintenance_payments')
          .select('id, payment_status, amount, payment_method, due_date, finance_entry_id, flat_number, created_at, notes, transaction_id, resident_name, charge_id')
          .in('charge_id', chargeIds)
          .order('created_at', { ascending: false })
          .limit(2500);
        payRows = (p as FinancePeriodPayment[]) ?? [];
      }
      setPayments(payRows);

      const { data: led } = await supabase
        .from('finance_entries')
        .select(
          'id, record_mode, destination, total_amount, entry_month, created_at, payment_status, payment_method, title, notes, transaction_id, transaction_date, expense_id, charge_id, aggregate_flat_count',
        )
        .eq('society_id', societyId)
        .order('created_at', { ascending: false })
        .limit(2500);
      const ledRows = (led as FinancePeriodLedgerEntry[]) ?? [];
      setLedgerEntries(ledRows);

      const linkedExpenseIds = ledRows.map((e) => e.expense_id).filter((id): id is string => Boolean(id));
      if (linkedExpenseIds.length > 0) {
        const { data: expCats } = await supabase.from('expenses').select('id, expense_category').in('id', linkedExpenseIds);
        const map = new Map<string, string>();
        for (const ex of (expCats as { id: string; expense_category: string }[] | null) ?? []) {
          map.set(ex.id, ex.expense_category);
        }
        setExpenseCategoryById(map);
      } else {
        setExpenseCategoryById(new Map());
      }

      const { data: rtData } = await supabase
        .from('reserve_fund_transfers')
        .select('id, entry_month, amount, direction, payment_method, notes, created_at')
        .eq('society_id', societyId)
        .order('entry_month', { ascending: false })
        .limit(500);
      setReserveTransfers(rtData ?? []);

      setLoading(false);
    };
    void load();
  }, [societyId]);

  const societyLedgerEntries = useMemo(
    () => filterSocietyLedgerEntries(ledgerEntries, expenseCategoryById),
    [ledgerEntries, expenseCategoryById],
  );

  return { loading, payments, societyLedgerEntries, expenseCategoryById, reserveTransfers };
}
