import { metadataLoader, MetadataLoader } from './MetadataLoader';
import { reportRepository, ReportRepository } from './ReportRepository';
import { exportService, ExportService } from './ExportService';
import type {
  ReportAggregate,
  ReportColumnDef,
  ReportDefinition,
  ReportExportRequest,
  ReportRequest,
  ReportResult,
  ReportTotal,
  SaveReportInput,
  SavedReportDefinition,
} from './types';

function resolveColumns(definition: ReportDefinition, requested?: string[]): ReportColumnDef[] {
  const defaults = definition.columns.filter((c) => c.defaultVisible !== false);
  if (!requested?.length) return defaults;
  const byKey = new Map(definition.columns.map((c) => [c.key, c]));
  return requested.map((k) => byKey.get(k)).filter(Boolean) as ReportColumnDef[];
}

function matchesSearch(row: Record<string, unknown>, columns: ReportColumnDef[], search: string): boolean {
  const q = search.trim().toLowerCase();
  if (!q) return true;
  const searchable = columns.filter((c) => c.searchable !== false);
  const haystack = searchable
    .map((c) => (row[c.key] == null ? '' : String(row[c.key])))
    .join(' ')
    .toLowerCase();
  return haystack.includes(q);
}

function compareValues(a: unknown, b: unknown, direction: 'asc' | 'desc'): number {
  const mul = direction === 'asc' ? 1 : -1;
  if (a == null && b == null) return 0;
  if (a == null) return -1 * mul;
  if (b == null) return 1 * mul;
  if (typeof a === 'number' && typeof b === 'number') return (a - b) * mul;
  return String(a).localeCompare(String(b), undefined, { numeric: true, sensitivity: 'base' }) * mul;
}

function aggregateValues(values: number[], aggregate: ReportAggregate): number {
  if (values.length === 0) return 0;
  switch (aggregate) {
    case 'sum':
      return values.reduce((s, n) => s + n, 0);
    case 'count':
      return values.length;
    case 'avg':
      return values.reduce((s, n) => s + n, 0) / values.length;
    case 'min':
      return Math.min(...values);
    case 'max':
      return Math.max(...values);
    default:
      return 0;
  }
}

function computeTotals(rows: Record<string, unknown>[], columns: ReportColumnDef[]): ReportTotal[] {
  const totals: ReportTotal[] = [];
  for (const col of columns) {
    if (!col.aggregate) continue;
    const nums = rows
      .map((r) => Number(r[col.key]))
      .filter((n) => Number.isFinite(n));
    totals.push({
      key: col.key,
      label: col.label,
      value: aggregateValues(nums, col.aggregate),
      aggregate: col.aggregate,
    });
  }
  return totals;
}

function groupRows(
  rows: Record<string, unknown>[],
  columns: ReportColumnDef[],
  groupByKeys: string[],
): Record<string, unknown>[] {
  if (!groupByKeys.length) return rows;
  const groupCols = columns.filter((c) => groupByKeys.includes(c.key));
  const aggCols = columns.filter((c) => c.aggregate);
  const map = new Map<string, Record<string, unknown>[]>();

  for (const row of rows) {
    const key = groupCols.map((c) => String(row[c.key] ?? '')).join('||');
    const list = map.get(key) ?? [];
    list.push(row);
    map.set(key, list);
  }

  const out: Record<string, unknown>[] = [];
  for (const [, group] of map) {
    const first = group[0] ?? {};
    const row: Record<string, unknown> = { id: `grp-${out.length}` };
    for (const col of columns) {
      if (groupByKeys.includes(col.key)) {
        row[col.key] = first[col.key];
      } else if (col.aggregate) {
        const nums = group.map((r) => Number(r[col.key])).filter((n) => Number.isFinite(n));
        row[col.key] = aggregateValues(nums, col.aggregate);
      } else if (col.aggregate === undefined && aggCols.length) {
        row[col.key] = group.length > 1 ? `${group.length} rows` : first[col.key];
      } else {
        row[col.key] = first[col.key];
      }
    }
    out.push(row);
  }
  return out;
}

/**
 * Facade for UI and future AI layers.
 * Callers pass report id + filters; they never write SQL.
 *
 * Example (future AI):
 *   reportService.run({
 *     reportId: 'maintenance_payments',
 *     societyId,
 *     permissions,
 *     filters: { payment_method: 'upi', period: { from: '2026-01-01', to: '2026-03-31' } },
 *   })
 */
export class ReportService {
  constructor(
    private readonly loader: MetadataLoader = metadataLoader,
    private readonly repo: ReportRepository = reportRepository,
    private readonly exporter: ExportService = exportService,
  ) {}

  listCatalog(permissions: ReportRequest['permissions']): ReportDefinition[] {
    return this.loader.list().filter((d) => !!permissions[d.permission]);
  }

  getDefinition(reportId: string): ReportDefinition {
    return this.loader.require(reportId);
  }

  async run(request: ReportRequest): Promise<ReportResult> {
    const definition = this.loader.require(request.reportId);
    if (!request.permissions[definition.permission]) {
      throw new Error(`Permission denied for report: ${definition.id}`);
    }
    if (!request.societyId) {
      throw new Error('societyId is required');
    }

    const columns = resolveColumns(definition, request.columns);
    const columnKeys = columns.map((c) => c.key);

    let rows = await this.repo.fetchRows({
      definition,
      societyId: request.societyId,
      filters: request.filters,
      sort: request.sort,
      columnKeys,
    });

    if (request.search?.trim()) {
      rows = rows.filter((r) => matchesSearch(r, columns, request.search!));
    }

    const groupBy = request.groupBy?.length ? request.groupBy : definition.defaultGroupBy;
    const grouped = Boolean(groupBy?.length);
    if (grouped && groupBy) {
      rows = groupRows(rows, columns, groupBy);
    }

    // Client-side sort for nested fields or post-group results
    const sort = request.sort ?? definition.defaultSort;
    if (sort) {
      const sortKey =
        columns.find((c) => c.key === sort.field || c.field === sort.field)?.key ?? sort.field;
      rows = [...rows].sort((a, b) => compareValues(a[sortKey], b[sortKey], sort.direction));
    }

    const totals = computeTotals(rows, columns);
    const pageSize = Math.max(1, request.pageSize ?? definition.defaultPageSize ?? 50);
    const page = Math.max(1, request.page ?? 1);
    const totalRows = rows.length;
    const totalPages = Math.max(1, Math.ceil(totalRows / pageSize));
    const start = (page - 1) * pageSize;
    const pageRows = rows.slice(start, start + pageSize);

    return {
      reportId: definition.id,
      title: definition.title,
      columns,
      rows: pageRows,
      totals,
      page,
      pageSize,
      totalRows,
      totalPages,
      grouped,
    };
  }

  async export(request: ReportExportRequest): Promise<ReportResult> {
    // Export full result set (capped by definition.rowLimit), not just current page.
    const result = await this.run({
      ...request,
      page: 1,
      pageSize: request.pageSize ?? 100_000,
    });
    const { resolveLetterheadReportContext } = await import('@/lib/letterheadReportEngine');
    const ctx = await resolveLetterheadReportContext(request.societyId, request.pdfMode);
    if (ctx?.warning && request.format === 'pdf') {
      console.warn('[report-export]', ctx.warning);
    }
    this.exporter.export(result, request.format, {
      societyName: request.societyName ?? ctx?.letterhead?.name,
      filenameBase: request.filenameBase ?? `${result.reportId}-report`,
      letterhead: ctx?.letterhead ?? null,
      pdfMode: ctx?.mode ?? request.pdfMode ?? 'letterhead',
    });
    return result;
  }

  listSaved(societyId: string, reportId?: string): Promise<SavedReportDefinition[]> {
    return this.repo.listSaved(societyId, reportId);
  }

  saveDefinition(input: SaveReportInput): Promise<SavedReportDefinition> {
    this.loader.require(input.reportId);
    if (!input.name.trim()) throw new Error('Saved report name is required');
    return this.repo.save(input);
  }

  updateSaved(
    societyId: string,
    id: string,
    patch: Partial<Omit<SaveReportInput, 'societyId' | 'reportId' | 'createdBy'>>,
  ): Promise<SavedReportDefinition> {
    return this.repo.update(societyId, id, patch);
  }

  deleteSaved(societyId: string, id: string): Promise<void> {
    return this.repo.remove(societyId, id);
  }
}

export const reportService = new ReportService();
