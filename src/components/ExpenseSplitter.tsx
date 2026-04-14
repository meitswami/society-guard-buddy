import { useState, useEffect } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { Split, Plus, Check } from 'lucide-react';
import { toast } from 'sonner';
import { confirmAction, showSuccess } from '@/lib/swal';

interface Props { adminName?: string; }

const ExpenseSplitter = ({ adminName = 'Admin' }: Props) => {
  const [groups, setGroups] = useState<any[]>([]);
  const [expenses, setExpenses] = useState<any[]>([]);
  const [splits, setSplits] = useState<any[]>([]);
  const [flats, setFlats] = useState<any[]>([]);
  const [includeVacantFlats, setIncludeVacantFlats] = useState(false);
  const [splitMode, setSplitMode] = useState<'even' | 'custom'>('even');
  const [customSplits, setCustomSplits] = useState<Record<string, string>>({});
  const [showGroupForm, setShowGroupForm] = useState(false);
  const [showExpenseForm, setShowExpenseForm] = useState<string | null>(null);
  const [gf, setGf] = useState({ name: '', description: '' });
  const [ef, setEf] = useState({ title: '', total_amount: '', paid_by_flat: '' });

  useEffect(() => { loadAll(); }, []);
  const loadAll = async () => {
    const [g, e, s, f] = await Promise.all([
      supabase.from('expense_groups').select('*').order('created_at', { ascending: false }),
      supabase.from('expenses').select('*').order('created_at', { ascending: false }),
      supabase.from('expense_splits').select('*'),
      supabase.from('flats').select('flat_number, id, is_occupied').order('flat_number'),
    ]);
    if (g.data) setGroups(g.data);
    if (e.data) setExpenses(e.data);
    if (s.data) setSplits(s.data);
    if (f.data) setFlats(f.data);
  };

  const addGroup = async () => {
    if (!gf.name) return;
    await supabase.from('expense_groups').insert([{ name: gf.name, description: gf.description || null, created_by: adminName }]);
    setGf({ name: '', description: '' }); setShowGroupForm(false);
    toast.success('Group created'); loadAll();
  };

  const activeFlats = includeVacantFlats
    ? flats
    : flats.filter((f) => f.is_occupied);

  const resetExpenseForm = () => {
    setEf({ title: '', total_amount: '', paid_by_flat: '' });
    setSplitMode('even');
    setCustomSplits({});
    setShowExpenseForm(null);
  };

  const toggleCustomFlat = (flatNumber: string, on: boolean) => {
    setCustomSplits((prev) => {
      const next = { ...prev };
      if (on) next[flatNumber] = next[flatNumber] ?? '';
      else delete next[flatNumber];
      return next;
    });
  };

  const setCustomFlatAmount = (flatNumber: string, amount: string) => {
    setCustomSplits((prev) => ({ ...prev, [flatNumber]: amount }));
  };

  const addExpense = async (groupId: string) => {
    if (!ef.title || !ef.total_amount || !ef.paid_by_flat) return;
    const total = Number(ef.total_amount);
    if (!total || total <= 0) {
      toast.error('Enter a valid total amount');
      return;
    }
    if (activeFlats.length === 0) {
      toast.error('No eligible flats found for split');
      return;
    }
    const { data: expense } = await supabase.from('expenses').insert([{
      group_id: groupId, title: ef.title, total_amount: total,
      paid_by_flat: ef.paid_by_flat, paid_by_name: adminName,
    }]).select().single();
    if (expense) {
      let splitRows: Array<{
        expense_id: string;
        flat_number: string;
        amount: number;
        is_settled: boolean;
        settled_at: string | null;
      }> = [];

      if (splitMode === 'even') {
        const splitAmount = total / activeFlats.length;
        splitRows = activeFlats.map(f => ({
          expense_id: expense.id, flat_number: f.flat_number,
          amount: Number(splitAmount.toFixed(2)),
          is_settled: f.flat_number === ef.paid_by_flat,
          settled_at: f.flat_number === ef.paid_by_flat ? new Date().toISOString() : null,
        }));
      } else {
        const entries = Object.entries(customSplits).filter(([_, v]) => Number(v) > 0);
        if (entries.length === 0) {
          toast.error('Select flats and enter custom amounts');
          return;
        }
        const customTotal = Number(
          entries.reduce((sum, [_, v]) => sum + Number(v), 0).toFixed(2),
        );
        if (Math.abs(customTotal - total) > 0.01) {
          toast.error(`Custom split total ₹${customTotal.toFixed(2)} must match expense total ₹${total.toFixed(2)}`);
          return;
        }
        splitRows = entries.map(([flatNumber, amount]) => ({
          expense_id: expense.id,
          flat_number: flatNumber,
          amount: Number(Number(amount).toFixed(2)),
          is_settled: flatNumber === ef.paid_by_flat,
          settled_at: flatNumber === ef.paid_by_flat ? new Date().toISOString() : null,
        }));
      }
      await supabase.from('expense_splits').insert(splitRows);
    }
    resetExpenseForm();
    toast.success(splitMode === 'custom' ? 'Expense added with custom split' : 'Expense added & split equally');
    loadAll();
  };

  const settleUp = async (splitId: string) => {
    const ok = await confirmAction('Settle Up?', 'Mark this split as settled?', 'Yes, Settle', 'Cancel');
    if (!ok) return;
    await supabase.from('expense_splits').update({ is_settled: true, settled_at: new Date().toISOString() }).eq('id', splitId);
    showSuccess('Settled!', 'Payment marked as settled'); loadAll();
  };

  // Calculate balances per flat
  const balances: Record<string, number> = {};
  flats.forEach(f => { balances[f.flat_number] = 0; });
  expenses.forEach(exp => {
    const expSplits = splits.filter(s => s.expense_id === exp.id);
    expSplits.forEach(s => {
      if (!s.is_settled && s.flat_number !== exp.paid_by_flat) {
        balances[s.flat_number] = (balances[s.flat_number] || 0) - s.amount;
        balances[exp.paid_by_flat] = (balances[exp.paid_by_flat] || 0) + s.amount;
      }
    });
  });

  return (
    <div className="page-container pb-24">
      <div className="flex items-center gap-3 mb-4">
        <div className="w-10 h-10 rounded-xl bg-orange-500/10 flex items-center justify-center">
          <Split className="w-5 h-5 text-orange-500" />
        </div>
        <h1 className="page-title">Expense Splitter</h1>
      </div>

      {/* Balances */}
      <div className="card-section p-4 mb-4">
        <p className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-2">Balances</p>
        <div className="space-y-1">
          {Object.entries(balances).filter(([_, v]) => v !== 0).map(([flat, amount]) => (
            <div key={flat} className="flex justify-between text-sm">
              <span>Flat {flat}</span>
              <span className={amount > 0 ? 'text-green-600 font-bold' : 'text-destructive font-bold'}>
                {amount > 0 ? `+₹${amount.toFixed(2)}` : `-₹${Math.abs(amount).toFixed(2)}`}
              </span>
            </div>
          ))}
          {Object.values(balances).every(v => v === 0) && <p className="text-xs text-muted-foreground">All settled! 🎉</p>}
        </div>
      </div>

      <div className="card-section p-3 mb-4">
        <div className="flex items-center justify-between gap-3">
          <div>
            <p className="text-xs font-medium text-foreground">Split target flats</p>
            <p className="text-[10px] text-muted-foreground">
              {includeVacantFlats
                ? `Using all flats (${flats.length})`
                : `Using occupied/sold flats (${activeFlats.length})`}
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

      <button onClick={() => setShowGroupForm(!showGroupForm)} className="btn-primary w-full mb-4 flex items-center justify-center gap-2">
        <Plus className="w-4 h-4" /> New Expense Group
      </button>

      {showGroupForm && (
        <div className="card-section p-4 mb-4 flex flex-col gap-3">
          <input className="input-field" placeholder="Group Name (e.g. Diwali Party)" value={gf.name} onChange={e => setGf({...gf, name: e.target.value})} />
          <textarea className="input-field" placeholder="Description" value={gf.description} onChange={e => setGf({...gf, description: e.target.value})} />
          <button onClick={addGroup} className="btn-primary">Create Group</button>
        </div>
      )}

      {groups.map(g => {
        const gExpenses = expenses.filter(e => e.group_id === g.id);
        return (
          <div key={g.id} className="card-section p-4 mb-3">
            <p className="font-semibold mb-1">{g.name}</p>
            {g.description && <p className="text-xs text-muted-foreground mb-2">{g.description}</p>}

            <button onClick={() => {
              if (showExpenseForm === g.id) {
                resetExpenseForm();
              } else {
                setShowExpenseForm(g.id);
              }
            }}
              className="text-xs text-primary underline mb-2 flex items-center gap-1">
              <Plus className="w-3 h-3" /> Add Expense
            </button>

            {showExpenseForm === g.id && (
              <div className="flex flex-col gap-2 mb-3 pt-2 border-t border-border">
                <input className="input-field text-sm" placeholder="Expense Title" value={ef.title} onChange={e => setEf({...ef, title: e.target.value})} />
                <input className="input-field text-sm" placeholder="Total Amount (₹)" type="number" value={ef.total_amount} onChange={e => setEf({...ef, total_amount: e.target.value})} />
                <select className="input-field text-sm" value={ef.paid_by_flat} onChange={e => setEf({...ef, paid_by_flat: e.target.value})}>
                  <option value="">Paid By (Flat)</option>
                  {activeFlats.map(f => <option key={f.id} value={f.flat_number}>Flat {f.flat_number}</option>)}
                </select>
                <select
                  className="input-field text-sm"
                  value={splitMode}
                  onChange={(e) => {
                    const mode = e.target.value as 'even' | 'custom';
                    setSplitMode(mode);
                    if (mode === 'even') setCustomSplits({});
                  }}
                >
                  <option value="even">Even split across eligible flats</option>
                  <option value="custom">Custom split (selected flats + amount each)</option>
                </select>
                {splitMode === 'even' ? (
                  <p className="text-[11px] text-muted-foreground">
                    This expense will be split equally across {activeFlats.length} eligible flats.
                  </p>
                ) : (
                  <div className="rounded-lg border border-border p-2.5 space-y-2">
                    <p className="text-[11px] font-medium text-foreground">Custom split</p>
                    <p className="text-[10px] text-muted-foreground">
                      Select flats and enter amount per flat. Sum must equal total amount.
                    </p>
                    <div className="max-h-48 overflow-y-auto space-y-1.5">
                      {activeFlats.map((f) => {
                        const checked = customSplits[f.flat_number] !== undefined;
                        return (
                          <div key={f.id} className="flex items-center gap-2">
                            <label className="flex items-center gap-2 text-xs flex-1">
                              <input
                                type="checkbox"
                                checked={checked}
                                onChange={(e) => toggleCustomFlat(f.flat_number, e.target.checked)}
                              />
                              <span>Flat {f.flat_number}</span>
                            </label>
                            {checked && (
                              <input
                                className="input-field text-xs w-28"
                                placeholder="₹ amount"
                                type="number"
                                value={customSplits[f.flat_number] ?? ''}
                                onChange={(e) => setCustomFlatAmount(f.flat_number, e.target.value)}
                              />
                            )}
                          </div>
                        );
                      })}
                    </div>
                    <p className="text-[10px] text-muted-foreground">
                      Current custom total: ₹
                      {Object.values(customSplits).reduce((sum, v) => sum + (Number(v) || 0), 0).toFixed(2)}
                    </p>
                  </div>
                )}
                <button onClick={() => addExpense(g.id)} className="btn-primary text-sm">
                  {splitMode === 'custom' ? 'Add with Custom Split' : 'Add & Split Equally'}
                </button>
              </div>
            )}

            {gExpenses.map(exp => {
              const expSplits = splits.filter(s => s.expense_id === exp.id);
              return (
                <div key={exp.id} className="bg-muted/30 rounded-lg p-3 mb-2">
                  <div className="flex justify-between mb-1">
                    <span className="text-sm font-medium">{exp.title}</span>
                    <span className="font-bold text-sm">₹{exp.total_amount}</span>
                  </div>
                  <p className="text-[10px] text-muted-foreground mb-2">Paid by Flat {exp.paid_by_flat}</p>
                  <div className="space-y-1">
                    {expSplits.map(s => (
                      <div key={s.id} className="flex justify-between items-center text-xs">
                        <span>Flat {s.flat_number}</span>
                        <div className="flex items-center gap-2">
                          <span>₹{s.amount}</span>
                          {s.is_settled ? (
                            <span className="text-[10px] px-1.5 py-0.5 rounded bg-green-500/20 text-green-600">✓</span>
                          ) : (
                            <button onClick={() => settleUp(s.id)} className="text-[10px] px-1.5 py-0.5 rounded bg-primary/10 text-primary">Settle</button>
                          )}
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              );
            })}
          </div>
        );
      })}
    </div>
  );
};

export default ExpenseSplitter;
