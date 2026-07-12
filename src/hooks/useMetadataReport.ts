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
};

export function useMetadataReport({ societyId, permissions, societyName, adminName }: Options) {
  const catalog = useMemo(() => reportService.listCatalog(permissions), [permissions]);
  const [reportId, setReportId] = useState(catalog[0]?.id ?? '');
  const definition = useMemo(
    () => (reportId ? reportService.getDefinition(reportId) : null),
    [reportId],
  );

  const pendingSavedRef = useRef<SavedReportDefinition | null>(null);
  const [selectedColumns, setSelectedColumns] = useState<string[]>([]);
  const [filters, setFilters] = useState<ReportFilterValues>({});
  const [search, setSearch] = useState('');
  const [sort, setSort] = useState<ReportSortDef | undefined>();
  const [groupBy, setGroupBy] = useState<string[]>([]);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(50);
  const [result, setResult] = useState<ReportResult | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState<SavedReportDefinition[]>([]);
  const [saveName, setSaveName] = useState('');

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
      setFilters(pending.filters ?? {});
      setSort(pending.sort ?? definition.defaultSort);
      setGroupBy(pending.group_by ?? definition.defaultGroupBy ?? []);
      setPage(1);
      setPageSize(definition.defaultPageSize ?? 50);
      setSearch('');
      setResult(null);
      setError(null);
      return;
    }

    setSelectedColumns(
      definition.columns.filter((c) => c.defaultVisible !== false).map((c) => c.key),
    );
    const defaults: ReportFilterValues = {};
    for (const f of definition.filters) {
      if (f.defaultValue !== undefined) defaults[f.key] = f.defaultValue;
    }
    setFilters(defaults);
    setSort(definition.defaultSort);
    setGroupBy(definition.defaultGroupBy ?? []);
    setPage(1);
    setPageSize(definition.defaultPageSize ?? 50);
    setSearch('');
    setResult(null);
    setError(null);
  }, [definition]);

  const refreshSaved = useCallback(async () => {
    if (!societyId) {
      setSaved([]);
      return;
    }
    try {
      const rows = await reportService.listSaved(societyId, reportId || undefined);
      setSaved(rows);
    } catch {
      setSaved([]);
    }
  }, [societyId, reportId]);

  useEffect(() => {
    void refreshSaved();
  }, [refreshSaved]);

  const run = useCallback(async () => {
    if (!societyId || !reportId) return;
    setLoading(true);
    setError(null);
    try {
      const next = await reportService.run({
        reportId,
        societyId,
        permissions,
        columns: selectedColumns,
        filters,
        sort,
        search,
        groupBy: groupBy.length ? groupBy : undefined,
        page,
        pageSize,
      });
      setResult(next);
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
    search,
    groupBy,
    page,
    pageSize,
  ]);

  useEffect(() => {
    if (!societyId || !reportId || selectedColumns.length === 0) return;
    void run();
    // Auto-run on report / pagination / sort / columns / grouping; filter Apply via Run.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [societyId, reportId, page, pageSize, sort, selectedColumns, groupBy]);

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
        search,
        groupBy: groupBy.length ? groupBy : undefined,
        format,
        societyName,
        filenameBase: `${reportId}-report`,
      });
    },
    [societyId, reportId, permissions, selectedColumns, filters, sort, search, groupBy, societyName],
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
    setSelectedColumns((prev) =>
      prev.includes(key) ? prev.filter((k) => k !== key) : [...prev, key],
    );
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

  return {
    catalog,
    reportId,
    setReportId,
    definition: definition as ReportDefinition | null,
    selectedColumns,
    toggleColumn,
    filters,
    setFilterValue,
    search,
    setSearch,
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
    run,
    exportReport,
    saved,
    saveName,
    setSaveName,
    saveCurrent,
    loadSaved,
    deleteSaved,
  };
}
