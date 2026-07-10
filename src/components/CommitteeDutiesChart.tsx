import { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useStore } from '@/store/useStore';
import { ClipboardList, Edit2, Plus, Save, Trash2, X } from 'lucide-react';
import { toast } from 'sonner';
import { confirmAction } from '@/lib/swal';
import { DateInput } from '@/components/DateInput';
import { fmtIsoDateToDisplay } from '@/lib/dateFormat';
import {
  type CommitteeDutiesChartRow,
  type CommitteeDutyRow,
  type DutyFormRow,
  STANDARD_DUTY_PRESETS,
  dutiesPeriodLabel,
  formatSupervisorNames,
  parseSupervisorNames,
} from '@/lib/committeeDuty';

interface Props {
  isResident?: boolean;
}

const emptyDutyRow = (sortOrder: number): DutyFormRow => ({
  id: null,
  dutyLabel: '',
  supervisorNames: '',
  sortOrder,
});

const CommitteeDutiesChart = ({ isResident = false }: Props) => {
  const societyId = useStore((s) => s.societyId);
  const [chart, setChart] = useState<CommitteeDutiesChartRow | null>(null);
  const [rows, setRows] = useState<CommitteeDutyRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [editing, setEditing] = useState(false);
  const [periodFrom, setPeriodFrom] = useState('');
  const [periodTo, setPeriodTo] = useState('');
  const [dutyForms, setDutyForms] = useState<DutyFormRow[]>([]);
  const [saving, setSaving] = useState(false);

  const load = useCallback(async () => {
    if (!societyId) {
      setChart(null);
      setRows([]);
      setLoading(false);
      return;
    }
    setLoading(true);
    const { data: chartData, error: chartError } = await supabase
      .from('committee_duties_charts')
      .select('*')
      .eq('society_id', societyId)
      .eq('is_active', true)
      .maybeSingle();
    if (chartError) toast.error(chartError.message);

    const activeChart = (chartData as CommitteeDutiesChartRow | null) ?? null;
    setChart(activeChart);

    if (activeChart) {
      const { data: rowData, error: rowError } = await supabase
        .from('committee_duty_rows')
        .select('*')
        .eq('chart_id', activeChart.id)
        .order('sort_order', { ascending: true })
        .order('duty_label', { ascending: true });
      if (rowError) toast.error(rowError.message);
      setRows((rowData as CommitteeDutyRow[]) ?? []);
    } else {
      setRows([]);
    }
    setLoading(false);
  }, [societyId]);

  useEffect(() => {
    void load();
  }, [load]);

  const startEdit = () => {
    if (chart) {
      setPeriodFrom(chart.period_from.slice(0, 10));
      setPeriodTo(chart.period_to?.slice(0, 10) ?? '');
      setDutyForms(
        rows.length > 0
          ? rows.map((r) => ({
              id: r.id,
              dutyLabel: r.duty_label,
              supervisorNames: formatSupervisorNames(r.supervisor_names),
              sortOrder: r.sort_order,
            }))
          : [emptyDutyRow(0)],
      );
    } else {
      setPeriodFrom('');
      setPeriodTo('');
      setDutyForms([emptyDutyRow(0)]);
    }
    setEditing(true);
  };

  const cancelEdit = () => {
    setEditing(false);
    setDutyForms([]);
  };

  const addDutyRow = () => {
    setDutyForms((prev) => [...prev, emptyDutyRow(prev.length)]);
  };

  const removeDutyRow = (index: number) => {
    setDutyForms((prev) => prev.filter((_, i) => i !== index));
  };

  const updateDutyRow = (index: number, patch: Partial<DutyFormRow>) => {
    setDutyForms((prev) => prev.map((row, i) => (i === index ? { ...row, ...patch } : row)));
  };

  const addPresetDuty = (label: string) => {
    const exists = dutyForms.some((r) => r.dutyLabel.trim().toLowerCase() === label.toLowerCase());
    if (exists) {
      toast.message(`${label} is already in the chart`);
      return;
    }
    setDutyForms((prev) => [...prev, { id: null, dutyLabel: label, supervisorNames: '', sortOrder: prev.length }]);
  };

  const save = async () => {
    if (!societyId) return;
    if (!periodFrom) {
      toast.error('Period start date (From) is required');
      return;
    }
    if (periodTo && periodTo < periodFrom) {
      toast.error('Period end date must be on or after start date');
      return;
    }

    const validRows = dutyForms
      .map((r, i) => ({
        ...r,
        dutyLabel: r.dutyLabel.trim(),
        supervisors: parseSupervisorNames(r.supervisorNames),
        sortOrder: i,
      }))
      .filter((r) => r.dutyLabel);

    if (validRows.length === 0) {
      toast.error('Add at least one duty with a label');
      return;
    }
    for (const row of validRows) {
      if (row.supervisors.length === 0) {
        toast.error(`Supervisor name is required for "${row.dutyLabel}"`);
        return;
      }
    }

    setSaving(true);
    try {
      let chartId = chart?.id ?? null;

      if (chartId) {
        const { error } = await supabase
          .from('committee_duties_charts')
          .update({ period_from: periodFrom, period_to: periodTo.trim() || null })
          .eq('id', chartId);
        if (error) throw error;
        await supabase.from('committee_duty_rows').delete().eq('chart_id', chartId);
      } else {
        const { data, error } = await supabase
          .from('committee_duties_charts')
          .insert([{ society_id: societyId, period_from: periodFrom, period_to: periodTo.trim() || null, is_active: true }])
          .select('id')
          .single();
        if (error) throw error;
        chartId = data.id;
      }

      const insertPayload = validRows.map((r) => ({
        chart_id: chartId!,
        duty_label: r.dutyLabel,
        supervisor_names: r.supervisors,
        sort_order: r.sortOrder,
      }));
      const { error: rowsError } = await supabase.from('committee_duty_rows').insert(insertPayload);
      if (rowsError) throw rowsError;

      toast.success('Duties chart saved');
      setEditing(false);
      void load();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Failed to save duties chart');
    } finally {
      setSaving(false);
    }
  };

  const removeChart = async () => {
    if (!chart) return;
    const ok = await confirmAction(
      'Remove duties chart?',
      'The standard duties chart will be hidden from residents until you create a new one.',
      'Remove',
      'Cancel',
    );
    if (!ok) return;
    const { error } = await supabase.from('committee_duties_charts').update({ is_active: false }).eq('id', chart.id);
    if (error) return toast.error(error.message);
    toast.success('Duties chart removed');
    setEditing(false);
    void load();
  };

  const hasChart = chart && rows.length > 0;

  return (
    <div className="mb-6">
      <div className="flex items-start justify-between gap-3 mb-3">
        <div>
          <h3 className={`${isResident ? 'text-sm' : 'text-base'} font-semibold flex items-center gap-1.5`}>
            <ClipboardList className="w-4 h-4 text-primary" />
            Standard Duties Chart
          </h3>
          <p className="text-xs text-muted-foreground mt-0.5">
            {isResident
              ? 'Who supervises each operational duty for the current period.'
              : 'Assign supervisors to standard duties for a date period; residents see this read-only.'}
          </p>
        </div>
        {!isResident && !editing && (
          <div className="flex gap-1.5 flex-shrink-0">
            {hasChart && (
              <button type="button" onClick={() => void removeChart()} className="p-2 rounded-lg bg-destructive/10 text-destructive" aria-label="Remove chart">
                <Trash2 className="w-3.5 h-3.5" />
              </button>
            )}
            <button type="button" onClick={startEdit} className="btn-secondary flex items-center gap-1 text-xs px-2.5 py-1.5">
              <Edit2 className="w-3.5 h-3.5" />
              {hasChart ? 'Edit' : 'Create'}
            </button>
          </div>
        )}
      </div>

      {loading ? (
        <p className="text-sm text-muted-foreground">Loading duties chart…</p>
      ) : editing && !isResident ? (
        <div className="card-section space-y-4">
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider">Period from *</label>
              <DateInput className="input-field mt-1" value={periodFrom} onChange={(e) => setPeriodFrom(e.target.value)} />
            </div>
            <div>
              <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider">Period to</label>
              <DateInput className="input-field mt-1" value={periodTo} onChange={(e) => setPeriodTo(e.target.value)} />
              <p className="text-[10px] text-muted-foreground mt-1">Leave blank if ongoing</p>
            </div>
          </div>

          <div>
            <p className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-2">Quick add standard duties</p>
            <div className="flex flex-wrap gap-1.5">
              {STANDARD_DUTY_PRESETS.map((label) => (
                <button
                  key={label}
                  type="button"
                  onClick={() => addPresetDuty(label)}
                  className="text-[10px] px-2 py-1 rounded-full border border-border bg-secondary/50 hover:bg-secondary"
                >
                  + {label}
                </button>
              ))}
            </div>
          </div>

          <div className="space-y-2">
            <p className="text-xs font-medium text-muted-foreground uppercase tracking-wider">Duty assignments</p>
            {dutyForms.map((row, index) => (
              <div key={index} className="grid grid-cols-1 sm:grid-cols-[1fr_1.2fr_auto] gap-2 items-start rounded-lg border border-border p-2.5 bg-muted/20">
                <div>
                  <label className="text-[10px] text-muted-foreground">Duty</label>
                  <input
                    className="input-field mt-0.5 text-sm"
                    placeholder="e.g. Security & Gate"
                    value={row.dutyLabel}
                    onChange={(e) => updateDutyRow(index, { dutyLabel: e.target.value })}
                  />
                </div>
                <div>
                  <label className="text-[10px] text-muted-foreground">Supervisor name(s)</label>
                  <input
                    className="input-field mt-0.5 text-sm"
                    placeholder="Comma-separated for multiple"
                    value={row.supervisorNames}
                    onChange={(e) => updateDutyRow(index, { supervisorNames: e.target.value })}
                  />
                </div>
                <button
                  type="button"
                  onClick={() => removeDutyRow(index)}
                  className="p-2 rounded-lg text-destructive hover:bg-destructive/10 self-end"
                  aria-label="Remove duty"
                  disabled={dutyForms.length <= 1}
                >
                  <X className="w-3.5 h-3.5" />
                </button>
              </div>
            ))}
            <button type="button" onClick={addDutyRow} className="text-xs flex items-center gap-1 text-primary hover:underline">
              <Plus className="w-3 h-3" /> Add duty row
            </button>
          </div>

          <div className="flex gap-2 justify-end pt-2 border-t border-border">
            <button type="button" className="btn-secondary" onClick={cancelEdit} disabled={saving}>Cancel</button>
            <button type="button" className="btn-primary flex items-center gap-1.5" onClick={() => void save()} disabled={saving}>
              <Save className="w-3.5 h-3.5" />
              {saving ? 'Saving…' : 'Save chart'}
            </button>
          </div>
        </div>
      ) : hasChart ? (
        <div className="card-section">
          <p className="text-xs text-muted-foreground mb-3">
            Period:{' '}
            <span className="font-medium text-foreground">
              {fmtIsoDateToDisplay(chart.period_from.slice(0, 10))}
              {' → '}
              {chart.period_to ? fmtIsoDateToDisplay(chart.period_to.slice(0, 10)) : 'Ongoing'}
            </span>
          </p>
          <div className="overflow-x-auto -mx-1">
            <table className="w-full text-sm min-w-[280px]">
              <thead>
                <tr className="border-b border-border text-left">
                  <th className="py-2 px-1 text-[10px] font-medium text-muted-foreground uppercase tracking-wider">Duty</th>
                  <th className="py-2 px-1 text-[10px] font-medium text-muted-foreground uppercase tracking-wider">Supervisor(s)</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((row) => (
                  <tr key={row.id} className="border-b border-border/60 last:border-0">
                    <td className="py-2.5 px-1 font-medium text-foreground align-top">{row.duty_label}</td>
                    <td className="py-2.5 px-1 text-muted-foreground align-top">
                      {formatSupervisorNames(row.supervisor_names)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          {!isResident && (
            <p className="text-[10px] text-muted-foreground mt-3">{dutiesPeriodLabel(chart)} · visible to residents</p>
          )}
        </div>
      ) : (
        <div className="card-section text-center py-6">
          <ClipboardList className="w-8 h-8 text-muted-foreground mx-auto mb-2 opacity-40" />
          <p className="text-sm text-muted-foreground">
            {isResident ? 'No duties chart published yet.' : 'Create a standard duties chart for residents to see.'}
          </p>
        </div>
      )}
    </div>
  );
};

export default CommitteeDutiesChart;
