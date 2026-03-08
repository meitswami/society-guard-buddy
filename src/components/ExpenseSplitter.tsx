import { useState, useEffect } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { Split, Plus, Check } from 'lucide-react';
import { toast } from 'sonner';

interface Props { adminName?: string; }

const ExpenseSplitter = ({ adminName = 'Admin' }: Props) => {
  const [groups, setGroups] = useState<any[]>([]);
  const [expenses, setExpenses] = useState<any[]>([]);
  const [splits, setSplits] = useState<any[]>([]);
  const [flats, setFlats] = useState<any[]>([]);
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
      supabase.from('flats').select('flat_number, id').order('flat_number'),
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

  const addExpense = async (groupId: string) => {
    if (!ef.title || !ef.total_amount || !ef.paid_by_flat) return;
    const splitAmount = Number(ef.total_amount) / flats.length;
    const { data: expense } = await supabase.from('expenses').insert([{
      group_id: groupId, title: ef.title, total_amount: Number(ef.total_amount),
      paid_by_flat: ef.paid_by_flat, paid_by_name: adminName,
    }]).select().single();
    if (expense) {
      const splitRows = flats.map(f => ({
        expense_id: expense.id, flat_number: f.flat_number,
        amount: Number(splitAmount.toFixed(2)),
        is_settled: f.flat_number === ef.paid_by_flat,
        settled_at: f.flat_number === ef.paid_by_flat ? new Date().toISOString() : null,
      }));
      await supabase.from('expense_splits').insert(splitRows);
    }
    setEf({ title: '', total_amount: '', paid_by_flat: '' }); setShowExpenseForm(null);
    toast.success('Expense added & split equally'); loadAll();
  };

  const settleUp = async (splitId: string) => {
    await supabase.from('expense_splits').update({ is_settled: true, settled_at: new Date().toISOString() }).eq('id', splitId);
    toast.success('Settled!'); loadAll();
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

            <button onClick={() => setShowExpenseForm(showExpenseForm === g.id ? null : g.id)}
              className="text-xs text-primary underline mb-2 flex items-center gap-1">
              <Plus className="w-3 h-3" /> Add Expense
            </button>

            {showExpenseForm === g.id && (
              <div className="flex flex-col gap-2 mb-3 pt-2 border-t border-border">
                <input className="input-field text-sm" placeholder="Expense Title" value={ef.title} onChange={e => setEf({...ef, title: e.target.value})} />
                <input className="input-field text-sm" placeholder="Total Amount (₹)" type="number" value={ef.total_amount} onChange={e => setEf({...ef, total_amount: e.target.value})} />
                <select className="input-field text-sm" value={ef.paid_by_flat} onChange={e => setEf({...ef, paid_by_flat: e.target.value})}>
                  <option value="">Paid By (Flat)</option>
                  {flats.map(f => <option key={f.id} value={f.flat_number}>Flat {f.flat_number}</option>)}
                </select>
                <button onClick={() => addExpense(g.id)} className="btn-primary text-sm">Add & Split Equally</button>
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
