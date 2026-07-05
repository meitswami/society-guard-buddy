import { useCallback, useEffect, useState } from 'react';
import { supabase } from '@/integrations/supabase/client';
import type { FinanceOpeningBalanceAnchor } from '@/lib/financePeriodReport';

export type OpeningBalanceAnchorRow = FinanceOpeningBalanceAnchor & {
  id: string;
};

function mapAnchorRow(row: {
  id: string;
  as_on_date: string;
  cash_amount: number | null;
  bank_amount: number | null;
  other_amount: number | null;
  notes?: string | null;
}): OpeningBalanceAnchorRow {
  return {
    id: row.id,
    as_on_date: String(row.as_on_date).slice(0, 10),
    cash_amount: row.cash_amount == null ? null : Number(row.cash_amount),
    bank_amount: row.bank_amount == null ? null : Number(row.bank_amount),
    other_amount: row.other_amount == null ? null : Number(row.other_amount),
    notes: row.notes ?? null,
  };
}

export function useSocietyOpeningBalanceAnchors(societyId: string | null) {
  const [anchors, setAnchors] = useState<OpeningBalanceAnchorRow[]>([]);
  const [loading, setLoading] = useState(false);

  const reload = useCallback(async () => {
    if (!societyId) {
      setAnchors([]);
      return;
    }
    setLoading(true);
    try {
      const { data, error } = await (supabase as any)
        .from('finance_opening_balance_anchors')
        .select('id, as_on_date, cash_amount, bank_amount, other_amount, notes')
        .eq('society_id', societyId)
        .order('as_on_date', { ascending: false });
      if (error) throw error;
      setAnchors(((data ?? []) as Parameters<typeof mapAnchorRow>[0][]).map(mapAnchorRow));
    } catch {
      setAnchors([]);
    } finally {
      setLoading(false);
    }
  }, [societyId]);

  useEffect(() => {
    void reload();
  }, [reload]);

  const saveAnchor = async (input: {
    id?: string;
    as_on_date: string;
    cash_amount: number | null;
    bank_amount: number | null;
    other_amount: number | null;
    notes?: string | null;
  }) => {
    if (!societyId) throw new Error('No society selected');
    if (
      input.cash_amount == null &&
      input.bank_amount == null &&
      input.other_amount == null
    ) {
      throw new Error('Enter at least one channel amount (cash, bank, or other)');
    }
    const payload = {
      society_id: societyId,
      as_on_date: input.as_on_date.slice(0, 10),
      cash_amount: input.cash_amount,
      bank_amount: input.bank_amount,
      other_amount: input.other_amount,
      notes: input.notes?.trim() || null,
      updated_at: new Date().toISOString(),
    };
    const { error } = await (supabase as any)
      .from('finance_opening_balance_anchors')
      .upsert(payload, { onConflict: 'society_id,as_on_date' });
    if (error) throw error;
    await reload();
  };

  const deleteAnchor = async (id: string) => {
    const { error } = await (supabase as any).from('finance_opening_balance_anchors').delete().eq('id', id);
    if (error) throw error;
    await reload();
  };

  return { anchors, loading, reload, saveAnchor, deleteAnchor };
}
