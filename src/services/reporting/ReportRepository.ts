import { supabase } from '@/integrations/supabase/client';
import { dynamicQueryBuilder } from './DynamicQueryBuilder';
import type {
  ReportDefinition,
  ReportFilterValues,
  ReportSortDef,
  SaveReportInput,
  SavedReportDefinition,
} from './types';

type FetchParams = {
  definition: ReportDefinition;
  societyId: string;
  filters?: ReportFilterValues;
  sort?: ReportSortDef;
  columnKeys: string[];
};

/**
 * Data access for the reporting engine: executes metadata-driven queries
 * and persists saved report definitions.
 */
export class ReportRepository {
  async fetchRows(params: FetchParams): Promise<Record<string, unknown>[]> {
    const { definition, societyId, filters, sort, columnKeys } = params;
    const select = dynamicQueryBuilder.buildSelect(definition);
    const limit = definition.rowLimit ?? 2000;

    // Dynamic table name is constrained by MetadataLoader whitelist.
    let query = supabase.from(definition.baseTable).select(select);
    query = dynamicQueryBuilder.applySocietyScope(query, definition, societyId);
    query = dynamicQueryBuilder.applyFilters(query, definition, filters);
    query = dynamicQueryBuilder.applySort(query, definition, sort);
    query = query.limit(limit);

    const { data, error } = await query;
    if (error) throw new Error(error.message);

    return dynamicQueryBuilder.projectRows(
      definition,
      (data ?? []) as unknown as Record<string, unknown>[],
      columnKeys,
    );
  }

  async listSaved(societyId: string, reportId?: string): Promise<SavedReportDefinition[]> {
    let q = supabase
      .from('saved_report_definitions')
      .select('*')
      .eq('society_id', societyId)
      .order('updated_at', { ascending: false });
    if (reportId) q = q.eq('report_id', reportId);
    const { data, error } = await q;
    if (error) throw new Error(error.message);
    return (data ?? []).map(normalizeSaved);
  }

  async save(input: SaveReportInput): Promise<SavedReportDefinition> {
    const payload = {
      society_id: input.societyId,
      report_id: input.reportId,
      name: input.name.trim(),
      description: input.description?.trim() || null,
      columns: input.columns ?? null,
      filters: input.filters ?? {},
      sort: input.sort ?? null,
      group_by: input.groupBy ?? null,
      created_by: input.createdBy ?? null,
      updated_at: new Date().toISOString(),
    };

    const { data, error } = await supabase
      .from('saved_report_definitions')
      .insert(payload)
      .select('*')
      .single();
    if (error) throw new Error(error.message);
    return normalizeSaved(data);
  }

  async update(
    societyId: string,
    id: string,
    patch: Partial<Omit<SaveReportInput, 'societyId' | 'reportId' | 'createdBy'>>,
  ): Promise<SavedReportDefinition> {
    const payload: Record<string, unknown> = { updated_at: new Date().toISOString() };
    if (patch.name != null) payload.name = patch.name.trim();
    if (patch.description !== undefined) payload.description = patch.description?.trim() || null;
    if (patch.columns !== undefined) payload.columns = patch.columns;
    if (patch.filters !== undefined) payload.filters = patch.filters;
    if (patch.sort !== undefined) payload.sort = patch.sort;
    if (patch.groupBy !== undefined) payload.group_by = patch.groupBy;

    const { data, error } = await supabase
      .from('saved_report_definitions')
      .update(payload)
      .eq('id', id)
      .eq('society_id', societyId)
      .select('*')
      .single();
    if (error) throw new Error(error.message);
    return normalizeSaved(data);
  }

  async remove(societyId: string, id: string): Promise<void> {
    const { error } = await supabase
      .from('saved_report_definitions')
      .delete()
      .eq('id', id)
      .eq('society_id', societyId);
    if (error) throw new Error(error.message);
  }
}

function normalizeSaved(row: Record<string, unknown>): SavedReportDefinition {
  return {
    id: String(row.id),
    society_id: String(row.society_id),
    report_id: String(row.report_id),
    name: String(row.name),
    description: (row.description as string | null) ?? null,
    columns: (row.columns as string[] | null) ?? null,
    filters: (row.filters as SavedReportDefinition['filters']) ?? {},
    sort: (row.sort as SavedReportDefinition['sort']) ?? null,
    group_by: (row.group_by as string[] | null) ?? null,
    created_by: (row.created_by as string | null) ?? null,
    created_at: String(row.created_at),
    updated_at: String(row.updated_at),
  };
}

export const reportRepository = new ReportRepository();
