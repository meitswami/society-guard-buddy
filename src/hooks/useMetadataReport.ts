import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import type { AdminPanelPermissions } from '@/lib/adminPermissions';
import type { ExportFormat } from '@/lib/reportExportUtils';
import {
  reportService,
  type ReportDefinition,
  type ReportFilterValues,
  type ReportResult,
  type ReportSortDef,
  type SavedReportDefinition,
} from '@/services/reporting';

type Options = {
  societyId: string | null | undefined;
  permissions: AdminPanelPermissions;
  societyName?: string;
  adminName?: string;
  /** Shared ReportPage period — applied to the primary date_range filter. */
  periodFrom?: string;
  periodTo?: string;
  /** Shared ReportPage search box. */
  searchQuery?: string;
};

function primaryDateRangeKey(definition: ReportDefinition | null): string | null {
  if (!definition) return null;
  const period = definition.filters.find((f) => f.key === 'period' && f.type === 'date_range');
  if (period) return period.key;
  return definition.filters.find((f) => f.type === 'date_range')?.key ?? null;
}

function withSyncedPeriod(
  base: ReportFilterValues,
  definition: ReportDefinition,
  periodFrom?: string,
  periodTo?: string,
): ReportFilterValues {
  const key = primaryDateRangeKey(definition);
  if (!key || (!periodFrom && !periodTo)) return base;
  return {
    ...base,
    [key]: {
      from: periodFrom || undefined,
      to: periodTo || undefined,
    },
  };
}

export function useMetadataReport({
  societyId,
  permissions,
  societyName,
  adminName,
  periodFrom,
  periodTo,
  searchQuery = '',
}: Options) {
  const catalog = useMemo(() => reportService.listCatalog(permissions), [permissions]);
  const [reportId, setReportId] = useState(catalog[0]?.id ?? '');
  const definition = useMemo(
    () => (reportId ? reportService.getDefinition(reportId) : null),
    [reportId],
  );

  const pendingSavedRef = useRef<SavedReportDefinition | null>(null);
  const [selectedColumns, setSelectedColumns] = useState<string[]>([]);
  const [filters, setFilters] = useState<ReportFilterValues>({});
  const [sort, setSort] = useState<ReportSortDef | undefined>();
  const [groupBy, setGroupBy] = useState<string[]>([]);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(50);
  const [result, setResult] = useState<ReportResult | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState<SavedReportDefinition[]>([]);
  const [saveName, setSaveName] = useState('');

  // Reset controls when report changes (then re-apply shared period).
  useEffect(() => {
    if (!definition) return;

    const pending = pendingSavedRef.current;
    if (pending && pending.report_id === definition.id) {
      pendingSavedRef.current = null;
      setSelectedColumns(
        pending.columns?.length
          ? pending.columns
          : definition.columns.filter((c) => c.defaultVisible !== false).map((c) => c.key),
      );
      setFilters(withSyncedPeriod(pending.filters ?? {}, definition, periodFrom, periodTo));
      setSort(pending.sort ?? definition.defaultSort);
      setGroupBy(pending.group_by ?? definition.defaultGroupBy ?? []);
      setPage(1);
      setPageSize(definition.defaultPageSize ?? 50);
      setResult(null);
      setError(null);
      return;
    }

    const defaults: ReportFilterValues = {};
    for (const f of definition.filters) {
      if (f.defaultValue !== undefined) defaults[f.key] = f.defaultValue;
    }
    setSelectedColumns(
      definition.columns.filter((c) => c.defaultVisible !== false).map((c) => c.key),
    );
    setFilters(withSyncedPeriod(defaults, definition, periodFrom, periodTo));
    setSort(definition.defaultSort);
    setGroupBy(definition.defaultGroupBy ?? []);
    setPage(1);
    setPageSize(definition.defaultPageSize ?? 50);
    setResult(null);
    setError(null);
    // periodFrom/To applied here on report switch; dedicated effect keeps them synced afterward.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [definition]);

  // Keep primary date range in lockstep with ReportPage month/custom period.
  useEffect(() => {
    if (!definition) return;
    const key = primaryDateRangeKey(definition);
    if (!key) return;
    setFilters((prev) => {
      const cur = prev[key] as { from?: string; to?: string } | undefined;
      if (cur?.from === periodFrom && cur?.to === periodTo) return prev;
      return {
        ...prev,
        [key]: { from: periodFrom || undefined, to: periodTo || undefined },
      };
    });
    setPage(1);
  }, [definition, periodFrom, periodTo]);

  const refreshSaved = useCallback(async () => {
    if (!societyId) {
      setSaved([]);
      return;
    }
    try {
      setSaved(await reportService.listSaved(societyId, reportId || undefined));
    } catch {
      setSaved([]);
    }
  }, [societyId, reportId]);

  useEffect(() => {
    void refreshSaved();
  }, [refreshSaved]);

  const [debouncedSearch, setDebouncedSearch] = useState(searchQuery);
  useEffect(() => {
    const t = window.setTimeout(() => setDebouncedSearch(searchQuery), 250);
    return () => window.clearTimeout(t);
  }, [searchQuery]);

  const run = useCallback(async () => {
    if (!societyId || !reportId || selectedColumns.length === 0) return;
    setLoading(true);
    setError(null);
    try {
      setResult(
        await reportService.run({
          reportId,
          societyId,
          permissions,
          columns: selectedColumns,
          filters,
          sort,
          search: debouncedSearch,
          groupBy: groupBy.length ? groupBy : undefined,
          page,
          pageSize,
        }),
      );
    } catch (e) {
      setResult(null);
      setError(e instanceof Error ? e.message : 'Failed to run report');
    } finally {
      setLoading(false);
    }
  }, [
    societyId,
    reportId,
    permissions,
    selectedColumns,
    filters,
    sort,
    debouncedSearch,
    groupBy,
    page,
    pageSize,
  ]);

  // Auto-run whenever shared or local controls change — no manual Run button.
  useEffect(() => {
    void run();
  }, [run]);

  const exportReport = useCallback(
    async (format: ExportFormat) => {
      if (!societyId || !reportId) return;
      await reportService.export({
        reportId,
        societyId,
        permissions,
        columns: selectedColumns,
        filters,
        sort,
        search: debouncedSearch,
        groupBy: groupBy.length ? groupBy : undefined,
        format,
        societyName,
        filenameBase: `${reportId}-report`,
      });
    },
    [
      societyId,
      reportId,
      permissions,
      selectedColumns,
      filters,
      sort,
      debouncedSearch,
      groupBy,
      societyName,
    ],
  );

  const saveCurrent = useCallback(async () => {
    if (!societyId || !reportId || !saveName.trim()) return;
    await reportService.saveDefinition({
      societyId,
      reportId,
      name: saveName.trim(),
      columns: selectedColumns,
      filters,
      sort: sort ?? null,
      groupBy: groupBy.length ? groupBy : null,
      createdBy: adminName,
    });
    setSaveName('');
    await refreshSaved();
  }, [
    societyId,
    reportId,
    saveName,
    selectedColumns,
    filters,
    sort,
    groupBy,
    adminName,
    refreshSaved,
  ]);

  const loadSaved = useCallback((item: SavedReportDefinition) => {
    pendingSavedRef.current = item;
    setReportId(item.report_id);
  }, []);

  const deleteSaved = useCallback(
    async (id: string) => {
      if (!societyId) return;
      await reportService.deleteSaved(societyId, id);
      await refreshSaved();
    },
    [societyId, refreshSaved],
  );

  const toggleColumn = useCallback((key: string) => {
    setSelectedColumns((prev) => {
      if (prev.includes(key)) {
        // Keep at least one column visible.
        if (prev.length <= 1) return prev;
        return prev.filter((k) => k !== key);
      }
      return [...prev, key];
    });
    setPage(1);
  }, []);

  const setFilterValue = useCallback((key: string, value: unknown) => {
    setFilters((prev) => {
      const next = { ...prev };
      if (
        value == null ||
        value === '' ||
        (typeof value === 'object' &&
          value !== null &&
          !Object.values(value as Record<string, unknown>).some(Boolean))
      ) {
        delete next[key];
      } else {
        next[key] = value;
      }
      return next;
    });
    setPage(1);
  }, []);

  const syncedDateRangeKey = primaryDateRangeKey(definition);

  return {
    catalog,
    reportId,
    setReportId,
    definition: definition as ReportDefinition | null,
    selectedColumns,
    toggleColumn,
    filters,
    setFilterValue,
    syncedDateRangeKey,
    sort,
    setSort,
    groupBy,
    setGroupBy,
    page,
    setPage,
    pageSize,
    setPageSize,
    result,
    loading,
    error,
    exportReport,
    saved,
    saveName,
    setSaveName,
    saveCurrent,
    loadSaved,
    deleteSaved,
  };
}
