import { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { Split, Plus, Trash2, Pencil } from 'lucide-react';
import { toast } from 'sonner';
import { confirmAction, showSuccess } from '@/lib/swal';
import { useStore } from '@/store/useStore';
import { FlatMultiSelect } from '@/components/FlatMultiSelect';
import { flatOptionsWithPrimaryLabel, residentLabelForFlatRow } from '@/lib/flatMultiSelectOptions';
import { format } from 'date-fns';
import { notifyResidentsOfRecord, type AdminRecordNotifyAudience } from '@/lib/adminRecordNotifications';

interface Props {
  adminName?: string;
}

type FundingSource = 'residents' | 'society_fund';
type SplitMode = 'even' | 'custom';

function parsePaidByFlats(exp: { paid_by_flats?: unknown; paid_by_flat: string }): string[] {
  const raw = exp.paid_by_flats;
  if (Array.isArray(raw) && raw.length) return raw.map(String);
  if (raw && typeof raw === 'object') {
    const arr = raw as string[];
    if (Array.isArray(arr) && arr.length) return arr.map(String);
  }
  return exp.paid_by_flat ? [exp.paid_by_flat] : [];
}

async function uploadExpenseBill(groupId: string, file: File): Promise<string | null> {
  const safe = file.name.replace(/[^\w.-]/g, '_');
  const path = `expense-bills/${groupId}/${crypto.randomUUID()}_${safe}`;
  const { error } = await supabase.storage.from('notification-media').upload(path, file, {
    cacheControl: '3600',
    upsert: false,
  });
  if (error) {
    toast.error(error.message);
    return null;
  }
  const { data } = supabase.storage.from('notification-media').getPublicUrl(path);
  return data.publicUrl;
}

const ExpenseSplitter = ({ adminName = 'Admin' }: Props) => {
  const societyId = useStore((s) => s.societyId);
  const [groups, setGroups] = useState<any[]>([]);
  const [expenses, setExpenses] = useState<any[]>([]);
  const [splits, setSplits] = useState<any[]>([]);
  const [flats, setFlats] = useState<{ id: string; flat_number: string; owner_name: string | null; is_occupied: boolean | null }[]>([]);
  const [primaryByFlatId, setPrimaryByFlatId] = useState<Map<string, string>>(new Map());
  const [includeVacantFlats, setIncludeVacantFlats] = useState(false);
  const [fundingSource, setFundingSource] = useState<FundingSource>('residents');
  const [splitMode, setSplitMode] = useState<SplitMode>('even');
  const [splitFlats, setSplitFlats] = useState<string[]>([]);
  const [paidByFlats, setPaidByFlats] = useState<string[]>([]);
  const [customSplits, setCustomSplits] = useState<Record<string, string>>({});
  const [showGroupForm, setShowGroupForm] = useState(false);
  const [showExpenseForm, setShowExpenseForm] = useState<string | null>(null);
  const [gf, setGf] = useState({ name: '', description: '' });
  const [ef, setEf] = useState({
    title: '',
    total_amount: '',
    vendor_or_service: '',
    service_kind: 'one_time' as 'recurring' | 'one_time' | 'temporary',
    expense_date: format(new Date(), 'yyyy-MM-dd'),
    payment_method: 'cash',
    notes: '',
  });
  const [billUploading, setBillUploading] = useState(false);
  const [expenseNotifyAudience, setExpenseNotifyAudience] = useState<AdminRecordNotifyAudience>('none');
  const [editingGroup, setEditingGroup] = useState<{ id: string; name: string; description: string } | null>(null);
  const [selectedExpenseIds, setSelectedExpenseIds] = useState<Set<string>>(new Set());
  const [expenseEdit, setExpenseEdit] = useState<{
    id: string;
    title: string;
    total_amount: string;
    vendor_or_service: string;
    service_kind: string;
    expense_date: string;
    payment_method: string;
    notes: string;
    record_status: string;
  } | null>(null);

  const activeFlats = includeVacantFlats ? flats : flats.filter((f) => f.is_occupied);

  const loadAll = useCallback(async () => {
    if (!societyId) {
      setGroups([]);
      setExpenses([]);
      setSplits([]);
      setFlats([]);
      setPrimaryByFlatId(new Map());
      return;
    }
    const { data: flatRows } = await supabase
      .from('flats')
      .select('flat_number, id, owner_name, is_occupied')
      .eq('society_id', societyId)
      .order('flat_number');
    if (flatRows) setFlats(flatRows);

    const flatIds = (flatRows ?? []).map((f) => f.id);
    const mRes =
      flatIds.length > 0
        ? await supabase.from('members').select('flat_id, name').eq('is_primary', true).in('flat_id', flatIds)
        : { data: [] as { flat_id: string; name: string }[] };
    const map = new Map<string, string>();
    for (const row of mRes.data ?? []) {
      if (row.flat_id && row.name?.trim()) map.set(row.flat_id, row.name.trim());
    }
    setPrimaryByFlatId(map);

    const { data: g } = await supabase
      .from('expense_groups')
      .select('*')
      .eq('society_id', societyId)
      .order('created_at', { ascending: false });
    if (g) setGroups(g);

    const groupIds = (g ?? []).map((x) => x.id);
    if (groupIds.length === 0) {
      setExpenses([]);
      setSplits([]);
      return;
    }
    const { data: e } = await supabase.from('expenses').select('*').in('group_id', groupIds).order('created_at', { ascending: false });
    if (e) setExpenses(e);
    const expIds = (e ?? []).map((x) => x.id);
    if (expIds.length === 0) {
      setSplits([]);
      return;
    }
    const { data: s } = await supabase.from('expense_splits').select('*').in('expense_id', expIds);
    if (s) setSplits(s);
  }, [societyId]);

  useEffect(() => {
    void loadAll();
  }, [loadAll]);

  const resetExpenseForm = () => {
    setEf({
      title: '',
      total_amount: '',
      vendor_or_service: '',
      service_kind: 'one_time',
      expense_date: format(new Date(), 'yyyy-MM-dd'),
      payment_method: 'cash',
      notes: '',
    });
    setSplitMode('even');
    setSplitFlats([]);
    setPaidByFlats([]);
    setCustomSplits({});
    setFundingSource('residents');
    setExpenseNotifyAudience('none');
    setShowExpenseForm(null);
  };

  const addGroup = async () => {
    if (!societyId) {
      toast.error('Select a society from the admin context');
      return;
    }
    if (!gf.name) return;
    await supabase.from('expense_groups').insert([
      { name: gf.name.trim(), description: gf.description?.trim() || null, created_by: adminName, society_id: societyId },
    ]);
    setGf({ name: '', description: '' });
    setShowGroupForm(false);
    toast.success('Group created');
    loadAll();
  };

  const targetFlatNumbers = (): string[] => {
    const eligible = new Set(activeFlats.map((f) => f.flat_number));
    const chosen = splitFlats.length > 0 ? splitFlats : [...eligible];
    return [...new Set(chosen.filter((n) => eligible.has(n)))];
  };

  const setCustomFlatAmount = (flatNumber: string, amount: string) => {
    setCustomSplits((prev) => ({ ...prev, [flatNumber]: amount }));
  };

  const addExpense = async (groupId: string) => {
    if (!ef.title?.trim() || !ef.total_amount) {
      toast.error('Title and total amount are required');
      return;
    }
    const total = Number(ef.total_amount);
    if (!total || total <= 0) {
      toast.error('Enter a valid total amount');
      return;
    }

    let billUrl: string | null = null;
    const fileInput = document.getElementById(`expense-bill-${groupId}`) as HTMLInputElement | null;
    const file = fileInput?.files?.[0];
    if (file) {
      if (!file.type.startsWith('image/') && !file.type.startsWith('audio/') && file.type !== 'application/pdf') {
        toast.error('Bill attachment: use image, PDF, or short audio');
        return;
      }
      if (file.size > 8 * 1024 * 1024) {
        toast.error('Bill file must be 8MB or smaller');
        return;
      }
      setBillUploading(true);
      billUrl = await uploadExpenseBill(groupId, file);
      setBillUploading(false);
      if (!billUrl) return;
      if (fileInput) fileInput.value = '';
    }

    if (fundingSource === 'society_fund') {
      const { error } = await supabase.from('expenses').insert([
        {
          group_id: groupId,
          title: ef.title.trim(),
          total_amount: total,
          paid_by_flat: 'SOCIETY',
          paid_by_flats: [],
          paid_by_name: adminName,
          split_type: 'society_fund',
          payment_method: ef.payment_method,
          bill_screenshot_url: billUrl,
          service_kind: ef.service_kind,
          vendor_or_service: ef.vendor_or_service?.trim() || null,
          expense_date: ef.expense_date,
          notes: ef.notes?.trim() || null,
          record_status: 'active',
        },
      ]);
      if (error) {
        toast.error(error.message);
        return;
      }

      const notifyAudience = expenseNotifyAudience;
      const groupName = groups.find((x) => x.id === groupId)?.name ?? 'Expense group';
      const allFlatNums = flats.map((f) => f.flat_number);
      const snapTitle = ef.title.trim();
      const snapVendor = ef.vendor_or_service?.trim() || '';
      const snapKind = ef.service_kind;
      const snapPm = ef.payment_method;
      const snapDate = ef.expense_date;
      const snapNotes = ef.notes?.trim() || '';
      const snapBill = billUrl;

      resetExpenseForm();
      let suffix = '';
      if (notifyAudience === 'all' && societyId) {
        const title = `Society expense: ${snapTitle}`;
        const lines = [
          `${adminName} recorded a society / corpus expense in “${groupName}”.`,
          `“${snapTitle}” — ₹${total.toLocaleString('en-IN')} (${snapPm}, ${snapKind}). No per-flat split.`,
        ];
        if (snapVendor) lines.push(`Vendor / service: ${snapVendor}.`);
        if (snapDate) lines.push(`Expense date: ${snapDate}.`);
        if (snapNotes) lines.push(snapNotes);
        lines.push(`Shared with all ${allFlatNums.length} society flat(s).`);
        if (snapBill) lines.push('A receipt image may be attached when available.');
        const ok = await notifyResidentsOfRecord({
          societyId,
          adminName,
          audience: 'all',
          selectedFlatNumbers: [],
          title,
          message: lines.join(' '),
          notificationType: 'society_expense',
          billUrl: snapBill,
          saveSucceededHint:
            'Expense saved, but notifying residents failed. You can send a manual notice from Notifications.',
        });
        if (ok) suffix = ' · Residents notified';
      }
      toast.success('Society expense recorded (no split to flats)' + suffix);
      loadAll();
      return;
    }

    if (paidByFlats.length === 0) {
      toast.error('Select at least one flat under “Paid by (flats)” (who advanced the payment)');
      return;
    }

    const targets = targetFlatNumbers();
    if (targets.length === 0) {
      toast.error('Select flats to split among, or leave empty to use all eligible flats');
      return;
    }

    const paidBySorted = [...paidByFlats];
    const primaryPaidBy = paidBySorted[0];

    let splitRows: Array<{
      expense_id: string;
      flat_number: string;
      amount: number;
      is_settled: boolean;
      settled_at: string | null;
      resident_name: string | null;
    }> = [];

    const splitType = splitMode === 'custom' ? 'custom' : splitFlats.length > 0 ? 'equal_selected' : 'equal_all';

    if (splitMode === 'even') {
      const splitAmount = total / targets.length;
      splitRows = targets.map((num) => {
        const flat = activeFlats.find((f) => f.flat_number === num);
        return {
          expense_id: '',
          flat_number: num,
          amount: Number(splitAmount.toFixed(2)),
          is_settled: paidBySorted.includes(num),
          settled_at: paidBySorted.includes(num) ? new Date().toISOString() : null,
          resident_name: residentLabelForFlatRow(flat?.id, flat?.owner_name ?? null, primaryByFlatId),
        };
      });
    } else {
      const entries = targets
        .map((num) => [num, customSplits[num] ?? ''] as const)
        .filter(([, v]) => Number(v) > 0);
      if (entries.length === 0) {
        toast.error('Enter amounts for flats in custom split');
        return;
      }
      const customTotal = Number(entries.reduce((sum, [, v]) => sum + Number(v), 0).toFixed(2));
      if (Math.abs(customTotal - total) > 0.01) {
        toast.error(`Custom split total ₹${customTotal.toFixed(2)} must match expense total ₹${total.toFixed(2)}`);
        return;
      }
      splitRows = entries.map(([flatNumber, amount]) => {
        const flat = activeFlats.find((f) => f.flat_number === flatNumber);
        return {
          expense_id: '',
          flat_number: flatNumber,
          amount: Number(Number(amount).toFixed(2)),
          is_settled: paidBySorted.includes(flatNumber),
          settled_at: paidBySorted.includes(flatNumber) ? new Date().toISOString() : null,
          resident_name: residentLabelForFlatRow(flat?.id, flat?.owner_name ?? null, primaryByFlatId),
        };
      });
    }

    const { data: expense, error: insErr } = await supabase
      .from('expenses')
      .insert([
        {
          group_id: groupId,
          title: ef.title.trim(),
          total_amount: total,
          paid_by_flat: primaryPaidBy,
          paid_by_flats: paidBySorted,
          paid_by_name: adminName,
          split_type: splitType,
          payment_method: ef.payment_method,
          bill_screenshot_url: billUrl,
          service_kind: ef.service_kind,
          vendor_or_service: ef.vendor_or_service?.trim() || null,
          expense_date: ef.expense_date,
          notes: ef.notes?.trim() || null,
          record_status: 'active',
        },
      ])
      .select()
      .single();
    if (insErr || !expense) {
      toast.error(insErr?.message || 'Could not save expense');
      return;
    }

    splitRows = splitRows.map((r) => ({ ...r, expense_id: expense.id }));
    const { error: spErr } = await supabase.from('expense_splits').insert(splitRows);
    if (spErr) {
      toast.error(spErr.message);
      await supabase.from('expenses').delete().eq('id', expense.id);
      return;
    }

    const notifyAudience = expenseNotifyAudience;
    const groupName = groups.find((x) => x.id === groupId)?.name ?? 'Expense group';
    const allFlatNums = flats.map((f) => f.flat_number);
    const notifyFlats = [...new Set([...targets, ...paidBySorted])];
    const snapTitle = ef.title.trim();
    const snapVendor = ef.vendor_or_service?.trim() || '';
    const snapKind = ef.service_kind;
    const snapPm = ef.payment_method;
    const snapDate = ef.expense_date;
    const snapNotes = ef.notes?.trim() || '';
    const snapBill = billUrl;
    const snapTotal = total;
    const snapTargets = [...targets];
    const snapPaidBy = [...paidBySorted];

    resetExpenseForm();

    let suffix = '';
    if (notifyAudience !== 'none' && societyId) {
      const methodLabel = snapPm.replace(/_/g, ' ');
      const title = `Expense recorded: ${snapTitle}`;
      const lines = [
        `${adminName} added an expense in “${groupName}”.`,
        `“${snapTitle}” — total ₹${snapTotal.toLocaleString('en-IN')} (${methodLabel}, ${snapKind}).`,
        `Split across: ${snapTargets.join(', ')}.`,
        `Paid by (advanced): ${snapPaidBy.join(', ')}.`,
      ];
      if (snapVendor) lines.push(`Vendor / service: ${snapVendor}.`);
      if (snapDate) lines.push(`Expense date: ${snapDate}.`);
      if (snapNotes) lines.push(snapNotes);
      if (notifyAudience === 'all') {
        lines.push(`This update was shared with all ${allFlatNums.length} society flat(s).`);
      }
      if (snapBill) lines.push('Open the notification to view the attached receipt image (when available).');
      const message = lines.join(' ');
      const ok = await notifyResidentsOfRecord({
        societyId,
        adminName,
        audience: notifyAudience,
        selectedFlatNumbers: notifyFlats,
        title,
        message,
        notificationType: 'society_expense',
        billUrl: snapBill,
        saveSucceededHint:
          'Expense saved, but notifying residents failed. You can send a manual notice from Notifications.',
      });
      if (ok) suffix = ' · Residents notified';
    }

    toast.success((splitMode === 'custom' ? 'Expense added with custom split' : 'Expense added & split') + suffix);
    loadAll();
  };

  const settleUp = async (splitId: string) => {
    const ok = await confirmAction('Settle Up?', 'Mark this split as settled?', 'Yes, Settle', 'Cancel');
    if (!ok) return;
    await supabase.from('expense_splits').update({ is_settled: true, settled_at: new Date().toISOString() }).eq('id', splitId);
    showSuccess('Settled!', 'Payment marked as settled');
    loadAll();
  };

  const deleteExpense = async (expenseId: string) => {
    const ok = await confirmAction('Delete expense?', 'This removes the expense and its flat splits.', 'Delete', 'Cancel');
    if (!ok) return;
    await supabase.from('expenses').delete().eq('id', expenseId);
    setSelectedExpenseIds((prev) => {
      const next = new Set(prev);
      next.delete(expenseId);
      return next;
    });
    toast.success('Expense deleted');
    loadAll();
  };

  const deleteGroup = async (groupId: string) => {
    const count = expenses.filter((e) => e.group_id === groupId).length;
    if (count > 0) {
      toast.error('Remove all expenses in this group before deleting it.');
      return;
    }
    const ok = await confirmAction('Delete this group?', 'This cannot be undone.', 'Delete group', 'Cancel');
    if (!ok) return;
    await supabase.from('expense_groups').delete().eq('id', groupId).eq('society_id', societyId);
    if (editingGroup?.id === groupId) setEditingGroup(null);
    toast.success('Group deleted');
    loadAll();
  };

  const saveGroupEdit = async () => {
    if (!editingGroup || !societyId) return;
    const name = editingGroup.name.trim();
    if (!name) {
      toast.error('Group name is required');
      return;
    }
    const { error } = await supabase
      .from('expense_groups')
      .update({
        name,
        description: editingGroup.description.trim() || null,
      })
      .eq('id', editingGroup.id)
      .eq('society_id', societyId);
    if (error) {
      toast.error(error.message);
      return;
    }
    toast.success('Group updated');
    setEditingGroup(null);
    loadAll();
  };

  const openExpenseEdit = (exp: any) => {
    setExpenseEdit({
      id: exp.id,
      title: exp.title ?? '',
      total_amount: String(exp.total_amount ?? ''),
      vendor_or_service: exp.vendor_or_service ?? '',
      service_kind: exp.service_kind ?? 'one_time',
      expense_date: (exp.expense_date || '').toString().slice(0, 10),
      payment_method: exp.payment_method ?? 'cash',
      notes: exp.notes ?? '',
      record_status: exp.record_status ?? 'active',
    });
  };

  const saveExpenseEdit = async () => {
    if (!expenseEdit) return;
    const old = expenses.find((e) => e.id === expenseEdit.id);
    if (!old) return;
    const newTotal = Number(expenseEdit.total_amount);
    if (!newTotal || newTotal <= 0) {
      toast.error('Enter a valid total amount');
      return;
    }
    const oldTotal = Number(old.total_amount);
    const expSplits = splits.filter((s) => s.expense_id === old.id);

    if (old.split_type !== 'society_fund' && expSplits.length > 0 && Math.abs(newTotal - oldTotal) > 0.01) {
      const ratio = newTotal / oldTotal;
      for (const s of expSplits) {
        const { error: uErr } = await supabase
          .from('expense_splits')
          .update({ amount: Number((Number(s.amount) * ratio).toFixed(2)) })
          .eq('id', s.id);
        if (uErr) {
          toast.error(uErr.message);
          return;
        }
      }
    }

    const { error } = await supabase
      .from('expenses')
      .update({
        title: expenseEdit.title.trim(),
        total_amount: newTotal,
        vendor_or_service: expenseEdit.vendor_or_service.trim() || null,
        service_kind: expenseEdit.service_kind,
        expense_date: expenseEdit.expense_date,
        payment_method: expenseEdit.payment_method,
        notes: expenseEdit.notes.trim() || null,
        record_status: expenseEdit.record_status,
      })
      .eq('id', expenseEdit.id);
    if (error) {
      toast.error(error.message);
      return;
    }
    toast.success('Expense updated');
    setExpenseEdit(null);
    loadAll();
  };

  const updateExpenseRecordStatus = async (expenseId: string, record_status: string) => {
    const { error } = await supabase.from('expenses').update({ record_status }).eq('id', expenseId);
    if (error) {
      toast.error(error.message);
      return;
    }
    toast.success('Status updated');
    loadAll();
  };

  const bulkDeleteSelectedExpenses = async () => {
    if (selectedExpenseIds.size === 0) return;
    const ok = await confirmAction(
      `Delete ${selectedExpenseIds.size} expenses?`,
      'This removes each expense and its flat splits.',
      'Delete all',
      'Cancel',
    );
    if (!ok) return;
    for (const id of selectedExpenseIds) {
      await supabase.from('expenses').delete().eq('id', id);
    }
    setSelectedExpenseIds(new Set());
    toast.success('Selected expenses deleted');
    loadAll();
  };

  const bulkSetExpenseRecordStatus = async (record_status: 'active' | 'archived') => {
    if (selectedExpenseIds.size === 0) return;
    const ok = await confirmAction(
      `Set ${selectedExpenseIds.size} expenses to ${record_status}?`,
      '',
      'Apply',
      'Cancel',
    );
    if (!ok) return;
    for (const id of selectedExpenseIds) {
      await supabase.from('expenses').update({ record_status }).eq('id', id);
    }
    setSelectedExpenseIds(new Set());
    toast.success('Status updated');
    loadAll();
  };

  const toggleExpenseSelect = (id: string, checked: boolean) => {
    setSelectedExpenseIds((prev) => {
      const next = new Set(prev);
      if (checked) next.add(id);
      else next.delete(id);
      return next;
    });
  };

  const selectAllExpenses = () => {
    setSelectedExpenseIds(new Set(expenses.map((e) => e.id)));
  };

  const balances: Record<string, number> = {};
  flats.forEach((f) => {
    balances[f.flat_number] = 0;
  });
  expenses.forEach((exp) => {
    if ((exp as { record_status?: string }).record_status === 'archived') return;
    if (exp.split_type === 'society_fund') return;
    const creditors = parsePaidByFlats(exp);
    if (creditors.length === 0) return;
    const expSplits = splits.filter((s) => s.expense_id === exp.id);
    expSplits.forEach((s) => {
      if (!s.is_settled && !creditors.includes(s.flat_number)) {
        balances[s.flat_number] = (balances[s.flat_number] || 0) - s.amount;
        const share = s.amount / creditors.length;
        creditors.forEach((c) => {
          balances[c] = (balances[c] || 0) + share;
        });
      }
    });
  });

  const flatOptions = flatOptionsWithPrimaryLabel(flats, primaryByFlatId);

  if (!societyId) {
    return (
      <div className="page-container pb-24">
        <p className="text-sm text-muted-foreground text-center py-12">Select a society to use expense splitting.</p>
      </div>
    );
  }

  return (
    <div className="page-container pb-24">
      <div className="flex items-center gap-3 mb-4">
        <div className="w-10 h-10 rounded-xl bg-orange-500/10 flex items-center justify-center">
          <Split className="w-5 h-5 text-orange-500" />
        </div>
        <div>
          <h1 className="page-title">Splitwise</h1>
          <p className="text-xs text-muted-foreground">Society bills, shared costs, and per-flat balances</p>
        </div>
      </div>

      <div className="card-section p-3 mb-4">
        <div className="flex items-center justify-between gap-3">
          <div>
            <p className="text-xs font-medium text-foreground">Eligible flats pool</p>
            <p className="text-[10px] text-muted-foreground">
              {includeVacantFlats ? `All flats (${flats.length})` : `Occupied / sold (${activeFlats.length})`}
            </p>
          </div>
          <button
            type="button"
            onClick={() => setIncludeVacantFlats((v) => !v)}
            className="text-xs px-2.5 py-1.5 rounded-lg border border-border"
          >
            {includeVacantFlats ? 'Include vacant: ON' : 'Include vacant: OFF'}
          </button>
        </div>
      </div>

      <div className="card-section p-4 mb-4 space-y-2">
        <p className="text-xs font-medium text-muted-foreground uppercase tracking-wider">Balances</p>
        <div className="space-y-1">
          {Object.entries(balances)
            .filter(([_, v]) => v !== 0)
            .map(([flat, amount]) => (
              <div key={flat} className="flex justify-between text-sm">
                <span>Flat {flat}</span>
                <span className={amount > 0 ? 'text-green-600 font-bold' : 'text-destructive font-bold'}>
                  {amount > 0 ? `+₹${amount.toFixed(2)}` : `-₹${Math.abs(amount).toFixed(2)}`}
                </span>
              </div>
            ))}
          {Object.values(balances).every((v) => v === 0) && <p className="text-xs text-muted-foreground">All settled! 🎉</p>}
        </div>
      </div>

      <button
        type="button"
        onClick={() => setShowGroupForm(!showGroupForm)}
        className="btn-primary w-full mb-4 flex items-center justify-center gap-2"
      >
        <Plus className="w-4 h-4" /> New expense group
      </button>

      {showGroupForm && (
        <div className="card-section p-4 mb-4 flex flex-col gap-3">
          <input
            className="input-field"
            placeholder="Group name (e.g. Society operations, Diwali)"
            value={gf.name}
            onChange={(e) => setGf({ ...gf, name: e.target.value })}
          />
          <textarea
            className="input-field"
            placeholder="Description (optional)"
            value={gf.description}
            onChange={(e) => setGf({ ...gf, description: e.target.value })}
          />
          <button type="button" onClick={addGroup} className="btn-primary">
            Create group
          </button>
        </div>
      )}

      {expenses.length > 0 && (
        <div className="card-section p-2 mb-3 flex flex-wrap gap-2 items-center">
          <button type="button" className="btn-secondary text-[10px] py-1.5 px-2" onClick={selectAllExpenses}>
            Select all expenses
          </button>
          <button
            type="button"
            className="btn-secondary text-[10px] py-1.5 px-2"
            onClick={() => setSelectedExpenseIds(new Set())}
          >
            Clear selection
          </button>
          {selectedExpenseIds.size > 0 && (
            <>
              <span className="text-[10px] text-muted-foreground">{selectedExpenseIds.size} selected</span>
              <button
                type="button"
                className="btn-secondary text-[10px] py-1.5 px-2 border border-destructive text-destructive"
                onClick={() => void bulkDeleteSelectedExpenses()}
              >
                Delete selected
              </button>
              <select
                className="input-field text-[10px] py-1.5 max-w-[210px]"
                defaultValue=""
                onChange={(e) => {
                  const v = e.target.value as '' | 'active' | 'archived';
                  if (!v) return;
                  void bulkSetExpenseRecordStatus(v);
                  e.target.value = '';
                }}
              >
                <option value="">Bulk record status…</option>
                <option value="active">Set active</option>
                <option value="archived">Set archived</option>
              </select>
            </>
          )}
        </div>
      )}

      {groups.map((g) => {
        const gExpenses = expenses.filter((e) => e.group_id === g.id);
        return (
          <div key={g.id} className="card-section p-4 mb-3">
            <div className="flex justify-between items-start gap-2 mb-1">
              <div className="min-w-0 flex-1">
                <p className="font-semibold">{g.name}</p>
                {g.description && <p className="text-xs text-muted-foreground mt-0.5">{g.description}</p>}
              </div>
              <div className="flex items-center gap-1 shrink-0">
                <button
                  type="button"
                  className="p-1.5 text-muted-foreground hover:text-primary"
                  title="Edit group"
                  onClick={() =>
                    setEditingGroup({ id: g.id, name: g.name, description: g.description || '' })
                  }
                >
                  <Pencil className="w-4 h-4" />
                </button>
                {gExpenses.length === 0 ? (
                  <button
                    type="button"
                    className="p-1.5 text-muted-foreground hover:text-destructive"
                    title="Delete group"
                    onClick={() => void deleteGroup(g.id)}
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                ) : (
                  <span
                    className="text-[9px] text-muted-foreground max-w-[52px] text-right leading-tight"
                    title="Delete expenses in this group before removing it"
                  >
                    In use
                  </span>
                )}
              </div>
            </div>

            <button
              type="button"
              onClick={() => {
                if (showExpenseForm === g.id) resetExpenseForm();
                else setShowExpenseForm(g.id);
              }}
              className="text-xs text-primary underline mb-2 flex items-center gap-1"
            >
              <Plus className="w-3 h-3" /> Add expense
            </button>

            {showExpenseForm === g.id && (
              <div className="flex flex-col gap-2 mb-3 pt-2 border-t border-border">
                <input
                  className="input-field text-sm"
                  placeholder="Expense title (e.g. Common area electricity)"
                  value={ef.title}
                  onChange={(e) => setEf({ ...ef, title: e.target.value })}
                />
                <input
                  className="input-field text-sm"
                  placeholder="Vendor / service (optional)"
                  value={ef.vendor_or_service}
                  onChange={(e) => setEf({ ...ef, vendor_or_service: e.target.value })}
                />
                <div className="grid grid-cols-2 gap-2">
                  <select
                    className="input-field text-sm"
                    value={ef.service_kind}
                    onChange={(e) => setEf({ ...ef, service_kind: e.target.value as typeof ef.service_kind })}
                  >
                    <option value="one_time">One-time</option>
                    <option value="recurring">Recurring (monthly)</option>
                    <option value="temporary">Temporary / ad-hoc</option>
                  </select>
                  <input
                    className="input-field text-sm"
                    type="date"
                    value={ef.expense_date}
                    onChange={(e) => setEf({ ...ef, expense_date: e.target.value })}
                  />
                </div>
                <input
                  className="input-field text-sm"
                  placeholder="Total amount (₹)"
                  type="number"
                  value={ef.total_amount}
                  onChange={(e) => setEf({ ...ef, total_amount: e.target.value })}
                />
                <select
                  className="input-field text-sm"
                  value={ef.payment_method}
                  onChange={(e) => setEf({ ...ef, payment_method: e.target.value })}
                >
                  <option value="cash">Cash</option>
                  <option value="upi">UPI</option>
                  <option value="bank_transfer">Bank transfer</option>
                  <option value="cheque">Cheque</option>
                  <option value="other">Other</option>
                </select>
                <textarea
                  className="input-field text-sm min-h-[4rem]"
                  placeholder="Internal notes (optional)"
                  value={ef.notes}
                  onChange={(e) => setEf({ ...ef, notes: e.target.value })}
                />
                <label className="text-[10px] font-medium text-muted-foreground uppercase">Bill / receipt (optional)</label>
                <input id={`expense-bill-${g.id}`} type="file" accept="image/*,application/pdf,audio/*" className="text-xs" />

                <div className="rounded-lg border border-border bg-muted/20 p-2 space-y-2">
                  <p className="text-xs font-medium">Who pays?</p>
                  <label className="flex items-center gap-2 text-xs">
                    <input
                      type="radio"
                      name={`fund-${g.id}`}
                      checked={fundingSource === 'residents'}
                      onChange={() => {
                        setFundingSource('residents');
                        setExpenseNotifyAudience('none');
                      }}
                    />
                    Split across flats (committee paid upfront, flats owe share)
                  </label>
                  <label className="flex items-center gap-2 text-xs">
                    <input
                      type="radio"
                      name={`fund-${g.id}`}
                      checked={fundingSource === 'society_fund'}
                      onChange={() => {
                        setFundingSource('society_fund');
                        setExpenseNotifyAudience('none');
                      }}
                    />
                    Society / corpus only (no split — e.g. absorbed from maintenance pool)
                  </label>
                </div>

                {fundingSource === 'residents' && (
                  <>
                    <FlatMultiSelect
                      flats={flatOptions}
                      selected={paidByFlats}
                      onChange={setPaidByFlats}
                      label="Paid by (flats — who advanced)"
                      compact
                    />
                    <FlatMultiSelect
                      flats={flatOptions}
                      selected={splitFlats}
                      onChange={(nums) => {
                        setSplitFlats(nums);
                        setCustomSplits((prev) => {
                          const next: Record<string, string> = {};
                          for (const n of nums) {
                            if (prev[n] !== undefined) next[n] = prev[n];
                          }
                          return next;
                        });
                      }}
                      label="Split among (leave empty = all eligible flats)"
                      compact
                      emptyHint="Pick flats to limit who shares this bill."
                    />
                    <select
                      className="input-field text-sm"
                      value={splitMode}
                      onChange={(e) => {
                        const mode = e.target.value as SplitMode;
                        setSplitMode(mode);
                        if (mode === 'even') setCustomSplits({});
                      }}
                    >
                      <option value="even">Equal split among flats above (or all if none selected)</option>
                      <option value="custom">Custom amount per flat (only “split among” flats)</option>
                    </select>
                    {splitMode === 'even' ? (
                      <p className="text-[11px] text-muted-foreground">
                        Each selected flat pays ₹
                        {(() => {
                          const t = targetFlatNumbers();
                          const tot = Number(ef.total_amount) || 0;
                          return t.length && tot ? (tot / t.length).toFixed(2) : '…'}
                        )}{' '}
                        (÷ {targetFlatNumbers().length || activeFlats.length} flats)
                      </p>
                    ) : (
                      <div className="rounded-lg border border-border p-2.5 space-y-2">
                        <p className="text-[10px] text-muted-foreground">Amounts must sum to total. Flats listed come from “Split among”.</p>
                        <div className="max-h-48 overflow-y-auto space-y-1.5">
                          {(splitFlats.length ? splitFlats : activeFlats.map((f) => f.flat_number)).map((num) => (
                            <div key={num} className="flex items-center gap-2">
                              <span className="text-xs w-16">Flat {num}</span>
                              <input
                                className="input-field text-xs flex-1"
                                placeholder="₹"
                                type="number"
                                value={customSplits[num] ?? ''}
                                onChange={(e) => setCustomFlatAmount(num, e.target.value)}
                              />
                            </div>
                          ))}
                        </div>
                        <p className="text-[10px] text-muted-foreground">
                          Sum: ₹{Object.entries(customSplits).reduce((sum, [, v]) => sum + (Number(v) || 0), 0).toFixed(2)}
                        </p>
                      </div>
                    )}
                  </>
                )}

                <div className="rounded-lg border border-border p-3 space-y-2 bg-muted/30">
                  <p className="text-xs font-medium text-foreground">Notify residents</p>
                  <p className="text-[10px] text-muted-foreground leading-snug">
                    Optional: send an in-app notice (and push, if configured) when this expense or receipt is saved.
                  </p>
                  <label className="flex items-start gap-2 text-xs cursor-pointer">
                    <input
                      type="radio"
                      name={`exp-notify-${g.id}`}
                      className="mt-0.5"
                      checked={expenseNotifyAudience === 'none'}
                      onChange={() => setExpenseNotifyAudience('none')}
                    />
                    <span>Do not notify</span>
                  </label>
                  {fundingSource === 'residents' && (
                    <label className="flex items-start gap-2 text-xs cursor-pointer">
                      <input
                        type="radio"
                        name={`exp-notify-${g.id}`}
                        className="mt-0.5"
                        checked={expenseNotifyAudience === 'selected_flats'}
                        onChange={() => setExpenseNotifyAudience('selected_flats')}
                      />
                      <span>
                        Flats in this expense ({new Set([...targetFlatNumbers(), ...paidByFlats]).size}) — split
                        participants and who advanced payment
                      </span>
                    </label>
                  )}
                  <label className="flex items-start gap-2 text-xs cursor-pointer">
                    <input
                      type="radio"
                      name={`exp-notify-${g.id}`}
                      className="mt-0.5"
                      checked={expenseNotifyAudience === 'all'}
                      onChange={() => setExpenseNotifyAudience('all')}
                    />
                    <span>All society flats ({flats.length}) — e.g. common-area or guard bills</span>
                  </label>
                </div>

                <button
                  type="button"
                  onClick={() => void addExpense(g.id)}
                  className="btn-primary text-sm"
                  disabled={billUploading}
                >
                  {billUploading ? 'Uploading…' : fundingSource === 'society_fund' ? 'Record society expense' : splitMode === 'custom' ? 'Add with custom split' : 'Add & split equally'}
                </button>
              </div>
            )}

            {gExpenses.map((exp) => {
              const expSplits = splits.filter((s) => s.expense_id === exp.id);
              const creditors = parsePaidByFlats(exp);
              const recStatus = (exp as { record_status?: string }).record_status ?? 'active';
              return (
                <div
                  key={exp.id}
                  className={`bg-muted/30 rounded-lg p-3 mb-2 relative ${
                    recStatus === 'archived' ? 'opacity-80 border border-dashed border-border' : ''
                  }`}
                >
                  <div className="flex gap-2 items-start mb-1">
                    <input
                      type="checkbox"
                      className="mt-1 shrink-0"
                      checked={selectedExpenseIds.has(exp.id)}
                      onChange={(e) => toggleExpenseSelect(exp.id, e.target.checked)}
                      aria-label={`Select ${exp.title}`}
                    />
                    <div className="min-w-0 flex-1">
                      <div className="flex items-start justify-between gap-2">
                        <div className="min-w-0">
                          <span className="text-sm font-medium block truncate">{exp.title}</span>
                          {exp.vendor_or_service && (
                            <span className="text-[10px] text-muted-foreground block truncate">{exp.vendor_or_service}</span>
                          )}
                          <span className="text-[10px] text-muted-foreground capitalize">
                            {exp.service_kind || 'one_time'} · {exp.payment_method || 'cash'} · {exp.expense_date || ''}
                          </span>
                        </div>
                        <span className="font-bold text-sm shrink-0">₹{exp.total_amount}</span>
                      </div>
                      {recStatus === 'archived' && (
                        <span className="text-[9px] px-1.5 py-0.5 rounded bg-muted text-muted-foreground inline-block mt-1">
                          Archived
                        </span>
                      )}
                    </div>
                  </div>
                  {exp.split_type === 'society_fund' ? (
                    <p className="text-[10px] text-muted-foreground mb-2">Paid from society / corpus — no flat split</p>
                  ) : (
                    <p className="text-[10px] text-muted-foreground mb-2">
                      Paid by: {creditors.map((c) => `Flat ${c}`).join(', ')}
                    </p>
                  )}
                  {exp.bill_screenshot_url && (
                    <a
                      href={exp.bill_screenshot_url}
                      target="_blank"
                      rel="noreferrer"
                      className="text-[10px] text-primary underline block mb-2"
                    >
                      View bill / receipt
                    </a>
                  )}
                  {exp.notes && <p className="text-[10px] text-muted-foreground mb-2 italic">{exp.notes}</p>}
                  <div className="space-y-1 mb-2">
                    {expSplits.map((s) => (
                      <div key={s.id} className="flex justify-between items-center text-xs">
                        <span>
                          Flat {s.flat_number}
                          {s.resident_name ? <span className="text-muted-foreground"> · {s.resident_name}</span> : null}
                        </span>
                        <div className="flex items-center gap-2">
                          <span>₹{s.amount}</span>
                          {s.is_settled ? (
                            <span className="text-[10px] px-1.5 py-0.5 rounded bg-green-500/20 text-green-600">✓</span>
                          ) : (
                            <button
                              type="button"
                              onClick={() => void settleUp(s.id)}
                              className="text-[10px] px-1.5 py-0.5 rounded bg-primary/10 text-primary"
                            >
                              Settle
                            </button>
                          )}
                        </div>
                      </div>
                    ))}
                  </div>
                  <div className="flex flex-wrap gap-2 pt-2 border-t border-border/60 items-center">
                    <button
                      type="button"
                      className="btn-secondary text-[10px] py-1 px-2 inline-flex items-center gap-1"
                      onClick={() => openExpenseEdit(exp)}
                    >
                      <Pencil className="w-3 h-3" /> Edit
                    </button>
                    <select
                      className="input-field text-[10px] py-1 max-w-[130px]"
                      value={recStatus}
                      onChange={(e) => void updateExpenseRecordStatus(exp.id, e.target.value)}
                    >
                      <option value="active">Active</option>
                      <option value="archived">Archived</option>
                    </select>
                    <button
                      type="button"
                      className="text-[10px] py-1 px-2 rounded-lg border border-destructive text-destructive inline-flex items-center gap-1"
                      onClick={() => void deleteExpense(exp.id)}
                    >
                      <Trash2 className="w-3 h-3" /> Delete
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        );
      })}

      {editingGroup && (
        <div className="fixed inset-0 z-[70] bg-black/45 p-4 flex items-center justify-center">
          <div className="w-full max-w-md bg-card border border-border rounded-xl p-4 space-y-3 max-h-[90vh] overflow-auto">
            <p className="text-sm font-semibold">Edit expense group</p>
            <input
              className="input-field"
              value={editingGroup.name}
              onChange={(e) => setEditingGroup({ ...editingGroup, name: e.target.value })}
              placeholder="Group name"
            />
            <textarea
              className="input-field"
              value={editingGroup.description}
              onChange={(e) => setEditingGroup({ ...editingGroup, description: e.target.value })}
              placeholder="Description (optional)"
            />
            <div className="flex gap-2">
              <button type="button" className="btn-primary flex-1" onClick={() => void saveGroupEdit()}>
                Save
              </button>
              <button type="button" className="btn-secondary flex-1" onClick={() => setEditingGroup(null)}>
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}

      {expenseEdit && (
        <div className="fixed inset-0 z-[70] bg-black/45 p-4 flex items-center justify-center">
          <div className="w-full max-w-md bg-card border border-border rounded-xl p-4 space-y-3 max-h-[90vh] overflow-auto">
            <p className="text-sm font-semibold">Edit expense</p>
            <p className="text-[10px] text-muted-foreground">
              Changing the total on a split expense rescales each flat’s share proportionally. Edit split lines via Settle
              on each flat when needed.
            </p>
            <input
              className="input-field"
              value={expenseEdit.title}
              onChange={(e) => setExpenseEdit({ ...expenseEdit, title: e.target.value })}
              placeholder="Title"
            />
            <input
              className="input-field"
              type="number"
              value={expenseEdit.total_amount}
              onChange={(e) => setExpenseEdit({ ...expenseEdit, total_amount: e.target.value })}
              placeholder="Total (₹)"
            />
            <input
              className="input-field"
              value={expenseEdit.vendor_or_service}
              onChange={(e) => setExpenseEdit({ ...expenseEdit, vendor_or_service: e.target.value })}
              placeholder="Vendor / service"
            />
            <div className="grid grid-cols-2 gap-2">
              <select
                className="input-field"
                value={expenseEdit.service_kind}
                onChange={(e) => setExpenseEdit({ ...expenseEdit, service_kind: e.target.value })}
              >
                <option value="one_time">One-time</option>
                <option value="recurring">Recurring</option>
                <option value="temporary">Temporary</option>
              </select>
              <input
                className="input-field"
                type="date"
                value={expenseEdit.expense_date}
                onChange={(e) => setExpenseEdit({ ...expenseEdit, expense_date: e.target.value })}
              />
            </div>
            <select
              className="input-field"
              value={expenseEdit.payment_method}
              onChange={(e) => setExpenseEdit({ ...expenseEdit, payment_method: e.target.value })}
            >
              <option value="cash">Cash</option>
              <option value="upi">UPI</option>
              <option value="bank_transfer">Bank transfer</option>
              <option value="cheque">Cheque</option>
              <option value="other">Other</option>
            </select>
            <textarea
              className="input-field min-h-[4rem]"
              value={expenseEdit.notes}
              onChange={(e) => setExpenseEdit({ ...expenseEdit, notes: e.target.value })}
              placeholder="Notes"
            />
            <select
              className="input-field"
              value={expenseEdit.record_status}
              onChange={(e) => setExpenseEdit({ ...expenseEdit, record_status: e.target.value })}
            >
              <option value="active">Active</option>
              <option value="archived">Archived</option>
            </select>
            <div className="flex gap-2">
              <button type="button" className="btn-primary flex-1" onClick={() => void saveExpenseEdit()}>
                Save changes
              </button>
              <button type="button" className="btn-secondary flex-1" onClick={() => setExpenseEdit(null)}>
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default ExpenseSplitter;
