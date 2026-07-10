import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useStore } from '@/store/useStore';
import { logAuditEvent } from '@/lib/auditLogger';
import {
  Banknote,
  Building2,
  CheckCircle2,
  Download,
  FileUp,
  Link2,
  Loader2,
  RefreshCw,
  Search,
  Sparkles,
  Upload,
  XCircle,
  AlertTriangle,
} from 'lucide-react';
import { fmtIsoDateToDisplay } from '@/lib/dateFormat';
import { DescriptiveStatSummary } from '@/components/DescriptiveStatCard';
import { toast } from 'sonner';
import {
  HIGH_CONFIDENCE_THRESHOLD,
  bankReconCsvTemplate,
  buildReconcilableTargets,
  computeReconciliationSummary,
  filterTargetsToPeriod,
  parseBankStatementCsv,
  rankCandidatesForLine,
  suggestMatches,
  targetKey,
  type ReconcilableTarget,
  type StatementLineForMatch,
  type SuggestedMatch,
} from '@/lib/bankReconciliation';

type ImportRow = {
  id: string;
  bank_name: string | null;
  account_last4: string | null;
  period_from: string;
  period_to: string;
  file_name: string | null;
  imported_by: string | null;
  created_at: string;
};

type LineRow = {
  id: string;
  import_id: string;
  line_date: string;
  amount: number;
  description: string | null;
  reference: string | null;
};

type MatchRow = {
  id: string;
  statement_line_id: string;
  match_type: string;
  maintenance_payment_id: string | null;
  finance_entry_id: string | null;
  match_confidence: number;
  status: string;
  matched_by: string | null;
  notes: string | null;
};

type LineFilter = 'all' | 'unmatched' | 'suggested' | 'confirmed' | 'exceptions';

interface Props {
  adminName?: string;
}

function lineStatus(
  lineId: string,
  matchByLineId: Map<string, MatchRow>,
  suggestionByLineId: Map<string, SuggestedMatch>,
): string {
  const m = matchByLineId.get(lineId);
  if (m?.status === 'confirmed' || m?.status === 'manual') return 'confirmed';
  if (m?.status === 'rejected') return 'rejected';
  if (m?.status === 'suggested' || suggestionByLineId.has(lineId)) return 'suggested';
  return 'unmatched';
}

const BankReconciliation = ({ adminName = 'Admin' }: Props) => {
  const societyId = useStore((s) => s.societyId);
  const fileRef = useRef<HTMLInputElement>(null);
  const [imports, setImports] = useState<ImportRow[]>([]);
  const [selectedImportId, setSelectedImportId] = useState<string | null>(null);
  const [lines, setLines] = useState<LineRow[]>([]);
  const [matches, setMatches] = useState<MatchRow[]>([]);
  const [pendingSuggestions, setPendingSuggestions] = useState<SuggestedMatch[]>([]);
  const [reconcilableTargets, setReconcilableTargets] = useState<ReconcilableTarget[]>([]);
  const [targetLabels, setTargetLabels] = useState<Map<string, string>>(new Map());
  const [loading, setLoading] = useState(false);
  const [importing, setImporting] = useState(false);
  const [runningMatch, setRunningMatch] = useState(false);
  const [busyMatchId, setBusyMatchId] = useState<string | null>(null);
  const [bankName, setBankName] = useState('');
  const [accountLast4, setAccountLast4] = useState('');
  const [lineFilter, setLineFilter] = useState<LineFilter>('all');
  const [manualPickLineId, setManualPickLineId] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState('');

  const loadImports = useCallback(async () => {
    if (!societyId) {
      setImports([]);
      return;
    }
    const { data } = await supabase
      .from('bank_statement_imports')
      .select('*')
      .eq('society_id', societyId)
      .order('created_at', { ascending: false });
    setImports((data as ImportRow[]) ?? []);
  }, [societyId]);

  const fetchReconcilableData = useCallback(
    async (periodFrom: string, periodTo: string) => {
      if (!societyId) return { targets: [] as ReconcilableTarget[], labels: new Map<string, string>() };

      const { data: confirmed } = await supabase
        .from('bank_reconciliation_matches')
        .select('maintenance_payment_id, finance_entry_id')
        .eq('society_id', societyId)
        .in('status', ['confirmed', 'manual']);

      const matchedPaymentIds = new Set(
        (confirmed ?? []).map((m) => m.maintenance_payment_id).filter(Boolean) as string[],
      );
      const matchedEntryIds = new Set(
        (confirmed ?? []).map((m) => m.finance_entry_id).filter(Boolean) as string[],
      );

      const { data: charges } = await supabase
        .from('maintenance_charges')
        .select('id, title')
        .eq('society_id', societyId);
      const chargeIds = (charges ?? []).map((c) => c.id);
      const chargeTitleById = new Map((charges ?? []).map((c) => [c.id, c.title]));

      const { data: payments } = chargeIds.length
        ? await supabase
            .from('maintenance_payments')
            .select(
              'id, flat_number, amount, payment_method, payment_status, due_date, payment_date, created_at, transaction_id, charge_id',
            )
            .in('charge_id', chargeIds)
        : { data: [] };

      const { data: ledger } = await supabase
        .from('finance_entries')
        .select(
          'id, total_amount, payment_method, payment_status, transaction_date, entry_month, created_at, transaction_id, title, destination',
        )
        .eq('society_id', societyId);

      const paymentRows = (payments ?? []).map((p) => ({
        ...p,
        charge_title: chargeTitleById.get(String(p.charge_id)) ?? '',
      }));

      const allTargets = buildReconcilableTargets(
        paymentRows as Parameters<typeof buildReconcilableTargets>[0],
        (ledger ?? []) as Parameters<typeof buildReconcilableTargets>[1],
        matchedPaymentIds,
        matchedEntryIds,
      );

      const targets = filterTargetsToPeriod(allTargets, periodFrom, periodTo);
      const labels = new Map(targets.map((t) => [targetKey(t), t.label]));
      return { targets, labels };
    },
    [societyId],
  );

  const persistMatch = useCallback(
    async (
      suggestion: SuggestedMatch,
      status: 'suggested' | 'confirmed' | 'rejected' | 'manual',
    ) => {
      if (!societyId) return;
      const payload = {
        statement_line_id: suggestion.statement_line_id,
        society_id: societyId,
        match_type: suggestion.match_type,
        maintenance_payment_id: suggestion.maintenance_payment_id ?? null,
        finance_entry_id: suggestion.finance_entry_id ?? null,
        match_confidence: suggestion.match_confidence,
        status,
        matched_by: status === 'confirmed' || status === 'manual' ? adminName : null,
        matched_at: status === 'confirmed' || status === 'manual' ? new Date().toISOString() : null,
      };

      const { data: existing } = await supabase
        .from('bank_reconciliation_matches')
        .select('id')
        .eq('statement_line_id', suggestion.statement_line_id)
        .maybeSingle();

      if (existing?.id) {
        const { error } = await supabase
          .from('bank_reconciliation_matches')
          .update(payload)
          .eq('id', existing.id);
        if (error) throw error;
        return existing.id;
      }

      const { data, error } = await supabase
        .from('bank_reconciliation_matches')
        .insert(payload)
        .select('id')
        .single();
      if (error) throw error;
      return data?.id;
    },
    [societyId, adminName],
  );

  const runMatchAndPersist = useCallback(
    async (
      importId: string,
      lineRows: LineRow[],
      periodFrom: string,
      periodTo: string,
      existingMatches: MatchRow[],
    ) => {
      const { targets } = await fetchReconcilableData(periodFrom, periodTo);
      const matchedLineIds = new Set(existingMatches.map((m) => m.statement_line_id));
      const usedTargetKeys = new Set<string>();
      for (const m of existingMatches) {
        if (m.status === 'confirmed' || m.status === 'manual') {
          if (m.maintenance_payment_id) usedTargetKeys.add(`maintenance_payment:${m.maintenance_payment_id}`);
          if (m.finance_entry_id) usedTargetKeys.add(`finance_entry:${m.finance_entry_id}`);
        }
      }

      const unmatchedLines = lineRows.filter((l) => !matchedLineIds.has(l.id));
      const lineInputs: StatementLineForMatch[] = unmatchedLines.map((l) => ({
        id: l.id,
        line_date: l.line_date,
        amount: Number(l.amount),
        description: l.description,
        reference: l.reference,
      }));

      const suggestions = suggestMatches(lineInputs, targets).filter(
        (s) => !usedTargetKeys.has(targetKey(s.target)),
      );

      for (const s of suggestions) {
        await persistMatch(s, 'suggested');
        usedTargetKeys.add(targetKey(s.target));
      }

      return suggestions.length;
    },
    [fetchReconcilableData, persistMatch],
  );

  const loadImportDetail = useCallback(
    async (importId: string, periodOverride?: { from: string; to: string }) => {
      if (!societyId) return;
      setLoading(true);
      try {
        let periodFrom = periodOverride?.from ?? '';
        let periodTo = periodOverride?.to ?? '';
        if (!periodFrom || !periodTo) {
          const imp = imports.find((i) => i.id === importId);
          periodFrom = imp?.period_from ?? '';
          periodTo = imp?.period_to ?? '';
        }
        if (!periodFrom || !periodTo) {
          const { data: impRow } = await supabase
            .from('bank_statement_imports')
            .select('period_from, period_to')
            .eq('id', importId)
            .single();
          periodFrom = impRow?.period_from ?? '';
          periodTo = impRow?.period_to ?? '';
        }

        const { data: lineData } = await supabase
          .from('bank_statement_lines')
          .select('id, import_id, line_date, amount, description, reference')
          .eq('import_id', importId)
          .order('line_date');

        const lineRows = (lineData as LineRow[]) ?? [];
        const lineIds = lineRows.map((l) => l.id);

        const { data: matchData } = lineIds.length
          ? await supabase
              .from('bank_reconciliation_matches')
              .select('*')
              .in('statement_line_id', lineIds)
          : { data: [] };

        const importMatches = (matchData as MatchRow[]) ?? [];
        setLines(lineRows);
        setMatches(importMatches);

        const { targets, labels } = await fetchReconcilableData(periodFrom, periodTo);
        setReconcilableTargets(targets);
        setTargetLabels(labels);

        const matchedLineIds = new Set(importMatches.map((m) => m.statement_line_id));
        const unmatchedLines = lineRows.filter((l) => !matchedLineIds.has(l.id));

        const usedTargetKeys = new Set<string>();
        for (const m of importMatches) {
          if (m.maintenance_payment_id) usedTargetKeys.add(`maintenance_payment:${m.maintenance_payment_id}`);
          if (m.finance_entry_id) usedTargetKeys.add(`finance_entry:${m.finance_entry_id}`);
        }

        const dbSuggested = importMatches.filter((m) => m.status === 'suggested');
        const hydratedFromDb: SuggestedMatch[] = dbSuggested
          .map((m) => {
            const line = lineRows.find((l) => l.id === m.statement_line_id);
            if (!line) return null;
            const target =
              m.maintenance_payment_id
                ? targets.find((t) => t.kind === 'maintenance_payment' && t.id === m.maintenance_payment_id)
                : targets.find((t) => t.kind === 'finance_entry' && t.id === m.finance_entry_id);
            if (!target) {
              const fallbackLabel =
                labels.get(
                  m.maintenance_payment_id
                    ? `maintenance_payment:${m.maintenance_payment_id}`
                    : `finance_entry:${m.finance_entry_id}`,
                ) ?? 'Linked record';
              return {
                statement_line_id: m.statement_line_id,
                match_type: m.match_type as 'maintenance_payment' | 'finance_entry',
                maintenance_payment_id: m.maintenance_payment_id ?? undefined,
                finance_entry_id: m.finance_entry_id ?? undefined,
                match_confidence: Number(m.match_confidence),
                target: {
                  kind: m.match_type === 'maintenance_payment' ? 'maintenance_payment' : 'finance_entry',
                  id: m.maintenance_payment_id ?? m.finance_entry_id ?? '',
                  amount: Number(line.amount),
                  date: line.line_date,
                  payment_method: 'bank',
                  transaction_id: null,
                  flat_number: '',
                  title: null,
                  destination: '',
                  label: fallbackLabel,
                } as ReconcilableTarget,
                reasons: ['Saved suggestion'],
              } satisfies SuggestedMatch;
            }
            return {
              statement_line_id: m.statement_line_id,
              match_type: m.match_type as 'maintenance_payment' | 'finance_entry',
              maintenance_payment_id: m.maintenance_payment_id ?? undefined,
              finance_entry_id: m.finance_entry_id ?? undefined,
              match_confidence: Number(m.match_confidence),
              target,
              reasons: ['Saved suggestion'],
            };
          })
          .filter(Boolean) as SuggestedMatch[];

        const linesNeedingCompute = unmatchedLines.filter(
          (l) => !dbSuggested.some((m) => m.statement_line_id === l.id),
        );

        const computed =
          linesNeedingCompute.length > 0
            ? suggestMatches(
                linesNeedingCompute.map((l) => ({
                  id: l.id,
                  line_date: l.line_date,
                  amount: Number(l.amount),
                  description: l.description,
                  reference: l.reference,
                })),
                targets.filter((t) => !usedTargetKeys.has(targetKey(t))),
              )
            : [];

        setPendingSuggestions([...hydratedFromDb, ...computed]);
      } finally {
        setLoading(false);
      }
    },
    [societyId, imports, fetchReconcilableData],
  );

  useEffect(() => {
    void loadImports();
  }, [loadImports]);

  useEffect(() => {
    if (selectedImportId) void loadImportDetail(selectedImportId);
    else {
      setLines([]);
      setMatches([]);
      setPendingSuggestions([]);
      setReconcilableTargets([]);
      setManualPickLineId(null);
    }
  }, [selectedImportId, loadImportDetail]);

  const summary = useMemo(() => {
    const map = new Map(matches.map((m) => [m.statement_line_id, { status: m.status }]));
    for (const s of pendingSuggestions) {
      if (!map.has(s.statement_line_id)) {
        map.set(s.statement_line_id, { status: 'suggested' });
      }
    }
    return computeReconciliationSummary(
      lines.map((l) => ({ id: l.id, amount: Number(l.amount) })),
      map,
    );
  }, [lines, matches, pendingSuggestions]);

  const suggestionByLineId = useMemo(() => {
    const map = new Map<string, SuggestedMatch>();
    for (const s of pendingSuggestions) map.set(s.statement_line_id, s);
    return map;
  }, [pendingSuggestions]);

  const matchByLineId = useMemo(() => {
    const map = new Map<string, MatchRow>();
    for (const m of matches) map.set(m.statement_line_id, m);
    return map;
  }, [matches]);

  const usedTargetKeys = useMemo(() => {
    const keys = new Set<string>();
    for (const m of matches) {
      if (m.status === 'confirmed' || m.status === 'manual' || m.status === 'suggested') {
        if (m.maintenance_payment_id) keys.add(`maintenance_payment:${m.maintenance_payment_id}`);
        if (m.finance_entry_id) keys.add(`finance_entry:${m.finance_entry_id}`);
      }
    }
    return keys;
  }, [matches]);

  const filteredLines = useMemo(() => {
    const q = searchQuery.trim().toLowerCase();
    return lines.filter((line) => {
      const status = lineStatus(line.id, matchByLineId, suggestionByLineId);
      if (lineFilter === 'unmatched' && status !== 'unmatched') return false;
      if (lineFilter === 'suggested' && status !== 'suggested') return false;
      if (lineFilter === 'confirmed' && status !== 'confirmed') return false;
      if (lineFilter === 'exceptions' && status === 'confirmed') return false;
      if (q) {
        const hay = `${line.description ?? ''} ${line.reference ?? ''} ${line.amount}`.toLowerCase();
        if (!hay.includes(q)) return false;
      }
      return true;
    });
  }, [lines, lineFilter, searchQuery, matchByLineId, suggestionByLineId]);

  const handleDownloadTemplate = () => {
    const blob = new Blob([bankReconCsvTemplate()], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'bank-statement-template.csv';
    a.click();
    URL.revokeObjectURL(url);
  };

  const handleFileSelect = async (file: File | null) => {
    if (!file || !societyId) return;
    setImporting(true);
    try {
      const text = await file.text();
      const parsed = parseBankStatementCsv(text);
      if (parsed.length === 0) {
        toast.error('No valid rows found in CSV');
        return;
      }

      const dates = parsed.map((r) => r.line_date).sort();
      const periodFrom = dates[0];
      const periodTo = dates[dates.length - 1];

      const { data: imp, error: impErr } = await supabase
        .from('bank_statement_imports')
        .insert({
          society_id: societyId,
          bank_name: bankName.trim() || null,
          account_last4: accountLast4.trim() || null,
          period_from: periodFrom,
          period_to: periodTo,
          file_name: file.name,
          imported_by: adminName,
        })
        .select('id')
        .single();

      if (impErr || !imp) throw impErr ?? new Error('Import failed');

      const linePayload = parsed.map((row) => ({
        import_id: imp.id,
        society_id: societyId,
        line_date: row.line_date,
        amount: row.amount,
        description: row.description || null,
        reference: row.reference || null,
        raw_row: row.raw_row,
      }));

      const { data: insertedLines, error: lineErr } = await supabase
        .from('bank_statement_lines')
        .insert(linePayload)
        .select('id, import_id, line_date, amount, description, reference');
      if (lineErr) throw lineErr;

      const lineRows = (insertedLines as LineRow[]) ?? [];
      const matchCount = await runMatchAndPersist(imp.id, lineRows, periodFrom, periodTo, []);

      await logAuditEvent({
        event_type: 'bank_recon_import',
        user_type: 'admin',
        user_name: adminName,
        details: {
          import_id: imp.id,
          line_count: parsed.length,
          suggestions_persisted: matchCount,
          file_name: file.name,
        },
        severity: 'info',
      });

      toast.success(`Imported ${parsed.length} lines · ${matchCount} auto-matched`);
      await loadImports();
      setSelectedImportId(imp.id);
      await loadImportDetail(imp.id, { from: periodFrom, to: periodTo });
    } catch (err) {
      toast.error(err instanceof Error ? err.message : 'Import failed');
    } finally {
      setImporting(false);
      if (fileRef.current) fileRef.current.value = '';
    }
  };

  const confirmMatch = async (suggestion: SuggestedMatch, asManual = false) => {
    setBusyMatchId(suggestion.statement_line_id);
    try {
      await persistMatch(suggestion, asManual ? 'manual' : 'confirmed');
      await logAuditEvent({
        event_type: asManual ? 'bank_recon_manual' : 'bank_recon_confirm',
        user_type: 'admin',
        user_name: adminName,
        details: {
          statement_line_id: suggestion.statement_line_id,
          match_type: suggestion.match_type,
          target_id: suggestion.maintenance_payment_id ?? suggestion.finance_entry_id,
          confidence: suggestion.match_confidence,
        },
        severity: 'info',
      });
      toast.success(asManual ? 'Manual link saved' : 'Match confirmed');
      setManualPickLineId(null);
      if (selectedImportId) await loadImportDetail(selectedImportId);
    } catch (err) {
      toast.error(err instanceof Error ? err.message : 'Could not confirm match');
    } finally {
      setBusyMatchId(null);
    }
  };

  const rejectMatch = async (suggestion: SuggestedMatch) => {
    setBusyMatchId(suggestion.statement_line_id);
    try {
      await persistMatch(suggestion, 'rejected');
      await logAuditEvent({
        event_type: 'bank_recon_reject',
        user_type: 'admin',
        user_name: adminName,
        details: { statement_line_id: suggestion.statement_line_id },
        severity: 'info',
      });
      if (selectedImportId) await loadImportDetail(selectedImportId);
    } catch (err) {
      toast.error(err instanceof Error ? err.message : 'Could not reject match');
    } finally {
      setBusyMatchId(null);
    }
  };

  const bulkConfirmHighConfidence = async () => {
    const high = pendingSuggestions.filter((s) => s.match_confidence >= HIGH_CONFIDENCE_THRESHOLD);
    if (high.length === 0) {
      toast.info('No high-confidence suggestions to confirm');
      return;
    }
    setRunningMatch(true);
    try {
      for (const s of high) {
        await persistMatch(s, 'confirmed');
      }
      await logAuditEvent({
        event_type: 'bank_recon_bulk_confirm',
        user_type: 'admin',
        user_name: adminName,
        details: { count: high.length },
        severity: 'info',
      });
      toast.success(`Confirmed ${high.length} high-confidence matches`);
      if (selectedImportId) await loadImportDetail(selectedImportId);
    } catch (err) {
      toast.error(err instanceof Error ? err.message : 'Bulk confirm failed');
    } finally {
      setRunningMatch(false);
    }
  };

  const rerunAutoMatch = async () => {
    if (!selectedImportId || !selectedImport) return;
    setRunningMatch(true);
    try {
      const count = await runMatchAndPersist(
        selectedImportId,
        lines,
        selectedImport.period_from,
        selectedImport.period_to,
        matches.filter((m) => m.status === 'confirmed' || m.status === 'manual'),
      );
      toast.success(count > 0 ? `Generated ${count} new suggestions` : 'No new matches found');
      await loadImportDetail(selectedImportId);
    } catch (err) {
      toast.error(err instanceof Error ? err.message : 'Auto-match failed');
    } finally {
      setRunningMatch(false);
    }
  };

  const exportExceptions = () => {
    const rows = lines.filter((l) => {
      const status = lineStatus(l.id, matchByLineId, suggestionByLineId);
      return status !== 'confirmed';
    });
    const header = 'date,amount,description,reference,status\n';
    const body = rows
      .map((l) => {
        const status = lineStatus(l.id, matchByLineId, suggestionByLineId);
        const esc = (s: string) => `"${s.replace(/"/g, '""')}"`;
        return [l.line_date, l.amount, esc(l.description ?? ''), esc(l.reference ?? ''), status].join(',');
      })
      .join('\n');
    const blob = new Blob([header + body], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'bank-recon-exceptions.csv';
    a.click();
    URL.revokeObjectURL(url);
  };

  const selectedImport = imports.find((i) => i.id === selectedImportId);

  const filterChips: { id: LineFilter; label: string; count?: number }[] = [
    { id: 'all', label: 'All', count: lines.length },
    {
      id: 'exceptions',
      label: 'Exceptions',
      count: lines.filter((l) => lineStatus(l.id, matchByLineId, suggestionByLineId) !== 'confirmed').length,
    },
    {
      id: 'suggested',
      label: 'Suggested',
      count: lines.filter((l) => lineStatus(l.id, matchByLineId, suggestionByLineId) === 'suggested').length,
    },
    {
      id: 'unmatched',
      label: 'Unmatched',
      count: lines.filter((l) => lineStatus(l.id, matchByLineId, suggestionByLineId) === 'unmatched').length,
    },
    {
      id: 'confirmed',
      label: 'Confirmed',
      count: lines.filter((l) => lineStatus(l.id, matchByLineId, suggestionByLineId) === 'confirmed').length,
    },
  ];

  return (
    <div className="card-section p-4">
      <div className="flex items-start justify-between gap-3 mb-4">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center shrink-0">
            <Building2 className="w-5 h-5 text-primary" />
          </div>
          <div>
            <h2 className="text-sm font-semibold">Bank Reconciliation</h2>
            <p className="text-[11px] text-muted-foreground leading-snug">
              Import bank CSV and match credits/debits to maintenance receipts and ledger entries.
            </p>
          </div>
        </div>
        <button
          type="button"
          onClick={handleDownloadTemplate}
          className="text-[10px] flex items-center gap-1 px-2 py-1 rounded-md border border-border hover:bg-muted/50"
        >
          <Download className="w-3 h-3" />
          Template
        </button>
      </div>

      <div className="rounded-lg border border-border bg-muted/20 p-3 mb-4">
        <p className="text-[11px] font-medium mb-2">Import statement</p>
        <div className="grid grid-cols-2 gap-2 mb-2">
          <input
            className="input-field text-xs"
            placeholder="Bank name (optional)"
            value={bankName}
            onChange={(e) => setBankName(e.target.value)}
          />
          <input
            className="input-field text-xs"
            placeholder="Account last 4 digits"
            value={accountLast4}
            onChange={(e) => setAccountLast4(e.target.value.replace(/\D/g, '').slice(0, 4))}
            maxLength={4}
          />
        </div>
        <div className="flex flex-wrap gap-2">
          <input
            ref={fileRef}
            type="file"
            accept=".csv,text/csv"
            className="hidden"
            onChange={(e) => void handleFileSelect(e.target.files?.[0] ?? null)}
          />
          <button
            type="button"
            disabled={importing || !societyId}
            onClick={() => fileRef.current?.click()}
            className="btn-primary text-xs flex items-center gap-1.5"
          >
            {importing ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <Upload className="w-3.5 h-3.5" />}
            Upload CSV
          </button>
        </div>
      </div>

      {imports.length > 0 && (
        <div className="mb-4">
          <p className="text-[11px] font-medium text-muted-foreground mb-2">Past imports</p>
          <div className="flex flex-wrap gap-1.5">
            {imports.map((imp) => (
              <button
                key={imp.id}
                type="button"
                onClick={() => {
                  setSelectedImportId(imp.id);
                  setLineFilter('all');
                  setSearchQuery('');
                }}
                className={`text-[10px] px-2.5 py-1 rounded-full border transition-colors ${
                  selectedImportId === imp.id
                    ? 'bg-primary text-primary-foreground border-primary'
                    : 'border-border hover:bg-muted/50'
                }`}
              >
                {fmtIsoDateToDisplay(imp.period_from)} – {fmtIsoDateToDisplay(imp.period_to)}
                {imp.bank_name ? ` · ${imp.bank_name}` : ''}
              </button>
            ))}
          </div>
        </div>
      )}

      {selectedImport && (
        <>
          <div className="flex items-center justify-between mb-3">
            <p className="text-xs text-muted-foreground">
              {selectedImport.file_name ?? 'Import'} · {lines.length} lines
            </p>
            <button
              type="button"
              onClick={() => void loadImportDetail(selectedImport.id)}
              className="text-[10px] flex items-center gap-1 text-muted-foreground hover:text-foreground"
            >
              <RefreshCw className="w-3 h-3" />
              Refresh
            </button>
          </div>

          {loading ? (
            <p className="text-xs text-muted-foreground text-center py-6 flex items-center justify-center gap-2">
              <Loader2 className="w-4 h-4 animate-spin" />
              Loading…
            </p>
          ) : (
            <>
              <DescriptiveStatSummary
                className="mb-4"
                items={[
                  {
                    label: 'Credits',
                    value: `₹${summary.statementCredits.toLocaleString('en-IN')}`,
                    sublabel: `Matched ₹${summary.matchedCredits.toLocaleString('en-IN')}`,
                  },
                  {
                    label: 'Debits',
                    value: `₹${summary.statementDebits.toLocaleString('en-IN')}`,
                    sublabel: `Matched ₹${summary.matchedDebits.toLocaleString('en-IN')}`,
                  },
                  {
                    label: 'Lines',
                    value: String(summary.lineCount),
                    sublabel: `${summary.matchedCount} confirmed · ${summary.suggestedCount} suggested`,
                  },
                  {
                    label: 'Exceptions',
                    value: String(summary.exceptionCount),
                    sublabel: 'Unmatched or pending',
                  },
                ]}
              />

              <div className="flex flex-wrap gap-2 mb-3">
                <button
                  type="button"
                  disabled={runningMatch || pendingSuggestions.length === 0}
                  onClick={() => void bulkConfirmHighConfidence()}
                  className="text-xs px-3 py-1.5 rounded-md bg-green-600/90 text-white hover:bg-green-600 disabled:opacity-50 flex items-center gap-1"
                >
                  {runningMatch ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <CheckCircle2 className="w-3.5 h-3.5" />}
                  Confirm high-confidence ({pendingSuggestions.filter((s) => s.match_confidence >= HIGH_CONFIDENCE_THRESHOLD).length})
                </button>
                <button
                  type="button"
                  disabled={runningMatch}
                  onClick={() => void rerunAutoMatch()}
                  className="text-xs px-3 py-1.5 rounded-md border border-border hover:bg-muted/50 flex items-center gap-1"
                >
                  <Sparkles className="w-3.5 h-3.5" />
                  Re-run auto-match
                </button>
                <button
                  type="button"
                  onClick={exportExceptions}
                  className="text-xs px-3 py-1.5 rounded-md border border-border hover:bg-muted/50 flex items-center gap-1"
                >
                  <FileUp className="w-3.5 h-3.5" />
                  Export exceptions
                </button>
              </div>

              <div className="flex flex-col gap-2 sm:flex-row sm:items-center mb-3">
                <div className="flex flex-wrap gap-1">
                  {filterChips.map((chip) => (
                    <button
                      key={chip.id}
                      type="button"
                      onClick={() => setLineFilter(chip.id)}
                      className={`text-[10px] px-2 py-0.5 rounded-full border ${
                        lineFilter === chip.id
                          ? 'bg-primary/15 border-primary text-primary'
                          : 'border-border text-muted-foreground hover:bg-muted/50'
                      }`}
                    >
                      {chip.label}
                      {chip.count !== undefined ? ` (${chip.count})` : ''}
                    </button>
                  ))}
                </div>
                <div className="relative flex-1 sm:max-w-[200px]">
                  <Search className="w-3 h-3 absolute left-2 top-1/2 -translate-y-1/2 text-muted-foreground" />
                  <input
                    className="input-field text-[10px] pl-7 py-1"
                    placeholder="Search narration…"
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                  />
                </div>
              </div>

              <div className="space-y-2 max-h-[480px] overflow-y-auto">
                {filteredLines.length === 0 ? (
                  <p className="text-xs text-muted-foreground text-center py-4">No lines match this filter.</p>
                ) : (
                  filteredLines.map((line) => {
                    const match = matchByLineId.get(line.id);
                    const suggestion = suggestionByLineId.get(line.id);
                    const isCredit = Number(line.amount) > 0;
                    const busy = busyMatchId === line.id;
                    const isConfirmed = match?.status === 'confirmed' || match?.status === 'manual';
                    const isRejected = match?.status === 'rejected';
                    const status = lineStatus(line.id, matchByLineId, suggestionByLineId);
                    const confirmedLabel =
                      isConfirmed && match
                        ? targetLabels.get(
                            match.maintenance_payment_id
                              ? `maintenance_payment:${match.maintenance_payment_id}`
                              : `finance_entry:${match.finance_entry_id}`,
                          ) ?? suggestion?.target.label
                        : null;

                    const manualCandidates =
                      manualPickLineId === line.id
                        ? rankCandidatesForLine(
                            {
                              id: line.id,
                              line_date: line.line_date,
                              amount: Number(line.amount),
                              description: line.description,
                              reference: line.reference,
                            },
                            reconcilableTargets,
                            usedTargetKeys,
                          )
                        : [];

                    return (
                      <div
                        key={line.id}
                        className={`rounded-lg border p-3 text-xs ${
                          isConfirmed
                            ? 'border-green-500/30 bg-green-500/5'
                            : isRejected
                              ? 'border-muted bg-muted/20 opacity-60'
                              : suggestion
                                ? 'border-amber-500/30 bg-amber-500/5'
                                : 'border-border'
                        }`}
                      >
                        <div className="flex items-start justify-between gap-2">
                          <div className="flex-1 min-w-0">
                            <div className="flex items-center gap-2 mb-1 flex-wrap">
                              <Banknote
                                className={`w-3.5 h-3.5 shrink-0 ${isCredit ? 'text-green-600' : 'text-red-500'}`}
                              />
                              <span className="font-medium">
                                {isCredit ? '+' : '−'}₹{Math.abs(Number(line.amount)).toLocaleString('en-IN')}
                              </span>
                              <span className="text-muted-foreground">{fmtIsoDateToDisplay(line.line_date)}</span>
                              {isConfirmed && (
                                <span className="text-[10px] px-1.5 py-0.5 rounded bg-green-500/15 text-green-700">
                                  {match?.status === 'manual' ? 'Manual' : 'Confirmed'}
                                </span>
                              )}
                              {suggestion && !isConfirmed && !isRejected && (
                                <span className="text-[10px] px-1.5 py-0.5 rounded bg-amber-500/15 text-amber-700">
                                  {Math.round(suggestion.match_confidence * 100)}% match
                                </span>
                              )}
                              {status === 'unmatched' && (
                                <span className="text-[10px] px-1.5 py-0.5 rounded bg-muted text-muted-foreground flex items-center gap-0.5">
                                  <AlertTriangle className="w-3 h-3" />
                                  Unmatched
                                </span>
                              )}
                            </div>
                            <p className="text-muted-foreground truncate">{line.description || '—'}</p>
                            {line.reference && (
                              <p className="text-[10px] text-muted-foreground font-mono mt-0.5">{line.reference}</p>
                            )}
                            {isConfirmed && confirmedLabel && (
                              <p className="text-[11px] mt-1.5 text-green-700">→ {confirmedLabel}</p>
                            )}
                            {suggestion && !isConfirmed && (
                              <p className="text-[11px] mt-1.5 text-foreground">
                                → {suggestion.target.label}
                                <span className="text-muted-foreground ml-1">({suggestion.reasons.join(', ')})</span>
                              </p>
                            )}
                          </div>
                          <div className="flex gap-1 shrink-0">
                            {suggestion && !isConfirmed && !isRejected && (
                              <>
                                <button
                                  type="button"
                                  disabled={busy}
                                  onClick={() => void confirmMatch(suggestion)}
                                  className="p-1.5 rounded-md bg-green-600/10 text-green-700 hover:bg-green-600/20"
                                  title="Confirm match"
                                >
                                  {busy ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <CheckCircle2 className="w-3.5 h-3.5" />}
                                </button>
                                <button
                                  type="button"
                                  disabled={busy}
                                  onClick={() => void rejectMatch(suggestion)}
                                  className="p-1.5 rounded-md bg-destructive/10 text-destructive hover:bg-destructive/20"
                                  title="Reject suggestion"
                                >
                                  <XCircle className="w-3.5 h-3.5" />
                                </button>
                              </>
                            )}
                            {!isConfirmed && (
                              <button
                                type="button"
                                onClick={() =>
                                  setManualPickLineId(manualPickLineId === line.id ? null : line.id)
                                }
                                className="p-1.5 rounded-md border border-border hover:bg-muted/50"
                                title="Link manually"
                              >
                                <Link2 className="w-3.5 h-3.5" />
                              </button>
                            )}
                          </div>
                        </div>

                        {manualPickLineId === line.id && (
                          <div className="mt-3 pt-3 border-t border-border">
                            <p className="text-[10px] font-medium text-muted-foreground mb-2">
                              Pick a ledger record (same amount, bank channel)
                            </p>
                            {manualCandidates.length === 0 ? (
                              <p className="text-[10px] text-muted-foreground">No matching candidates in this period.</p>
                            ) : (
                              <div className="space-y-1">
                                {manualCandidates.map((c) => (
                                  <button
                                    key={targetKey(c.target)}
                                    type="button"
                                    disabled={busy}
                                    onClick={() => void confirmMatch(c, true)}
                                    className="w-full text-left text-[10px] px-2 py-1.5 rounded-md border border-border hover:bg-muted/40 flex justify-between gap-2"
                                  >
                                    <span className="truncate">{c.target.label}</span>
                                    <span className="text-muted-foreground shrink-0">
                                      {Math.round(c.match_confidence * 100)}%
                                    </span>
                                  </button>
                                ))}
                              </div>
                            )}
                          </div>
                        )}
                      </div>
                    );
                  })
                )}
              </div>
            </>
          )}
        </>
      )}

      {imports.length === 0 && !importing && (
        <p className="text-xs text-muted-foreground text-center py-4">
          No bank statements imported yet. Upload a CSV to start reconciling.
        </p>
      )}
    </div>
  );
};

export default BankReconciliation;
