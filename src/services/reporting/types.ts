import type { AdminPanelPermissions } from '@/lib/adminPermissions';
import type { ExportFormat } from '@/lib/reportExportUtils';

/** Tables the engine is allowed to query. Keep this list explicit for security. */
export const REPORTABLE_TABLES = [
  'visitors',
  'finance_entries',
  'maintenance_payments',
  'guard_shifts',
  'fixed_assets',
  'expenses',
  'donation_payments',
] as const;

export type ReportableTable = (typeof REPORTABLE_TABLES)[number];

export type ReportColumnType = 'string' | 'number' | 'date' | 'datetime' | 'boolean';
export type ReportFilterType = 'text' | 'number' | 'date' | 'date_range' | 'select' | 'boolean';
export type ReportFilterOperator = 'eq' | 'neq' | 'gt' | 'gte' | 'lt' | 'lte' | 'ilike' | 'in';
export type ReportAggregate = 'sum' | 'count' | 'avg' | 'min' | 'max';
export type ReportColumnFormat = 'money' | 'date' | 'datetime';

export type ReportColumnDef = {
  key: string;
  label: string;
  type: ReportColumnType;
  /** DB field or dotted path into a joined relation, e.g. `maintenance_charges.title`. */
  field: string;
  sortable?: boolean;
  searchable?: boolean;
  aggregate?: ReportAggregate;
  format?: ReportColumnFormat;
  defaultVisible?: boolean;
};

export type ReportFilterDef = {
  key: string;
  label: string;
  type: ReportFilterType;
  field: string;
  operator?: ReportFilterOperator;
  options?: { value: string; label: string }[];
  defaultValue?: unknown;
  /** For date_range filters: companion field keys are unused; values are `{ from, to }`. */
};

export type ReportJoinDef = {
  /** PostgREST relation name (FK embedding). Use `!inner` suffix for required joins. */
  relation: string;
  columns?: string[];
};

export type ReportSortDef = {
  field: string;
  direction: 'asc' | 'desc';
};

/**
 * Static metadata for one report. New reports should normally be added here
 * (or saved as user definitions) without new PHP/controller code.
 */
export type ReportDefinition = {
  id: string;
  title: string;
  description?: string;
  /** Admin panel permission flag required to run this report. */
  permission: keyof AdminPanelPermissions;
  baseTable: ReportableTable;
  /** Column used for tenant scoping. Omit when scoped via an inner join. */
  societyColumn?: string;
  /**
   * When the base table has no society_id, scope through an inner join, e.g.
   * `{ relation: 'maintenance_charges', column: 'society_id' }`.
   */
  societyVia?: { relation: string; column: string };
  columns: ReportColumnDef[];
  filters: ReportFilterDef[];
  joins?: ReportJoinDef[];
  defaultSort?: ReportSortDef;
  defaultPageSize?: number;
  defaultGroupBy?: string[];
  /** Hard fetch cap before client-side grouping/search. */
  rowLimit?: number;
  /** Always-applied equality / null checks (no UI control). */
  fixedFilters?: Array<
    | { field: string; op: 'eq' | 'neq'; value: string | number | boolean }
    | { field: string; op: 'not_null' }
  >;
};

export type ReportFilterValues = Record<string, unknown>;

export type ReportRequest = {
  reportId: string;
  societyId: string;
  permissions: AdminPanelPermissions;
  /** Subset of column keys; defaults to columns with defaultVisible !== false. */
  columns?: string[];
  filters?: ReportFilterValues;
  sort?: ReportSortDef;
  search?: string;
  groupBy?: string[];
  page?: number;
  pageSize?: number;
};

export type ReportTotal = {
  key: string;
  label: string;
  value: number;
  aggregate: ReportAggregate;
};

export type ReportResult = {
  reportId: string;
  title: string;
  columns: ReportColumnDef[];
  rows: Record<string, unknown>[];
  totals: ReportTotal[];
  page: number;
  pageSize: number;
  totalRows: number;
  totalPages: number;
  grouped: boolean;
};

export type SavedReportDefinition = {
  id: string;
  society_id: string;
  report_id: string;
  name: string;
  description: string | null;
  columns: string[] | null;
  filters: ReportFilterValues;
  sort: ReportSortDef | null;
  group_by: string[] | null;
  created_by: string | null;
  created_at: string;
  updated_at: string;
};

export type SaveReportInput = {
  societyId: string;
  reportId: string;
  name: string;
  description?: string;
  columns?: string[];
  filters?: ReportFilterValues;
  sort?: ReportSortDef | null;
  groupBy?: string[] | null;
  createdBy?: string;
};

export type ReportExportRequest = ReportRequest & {
  format: ExportFormat;
  societyName?: string;
  filenameBase?: string;
};
