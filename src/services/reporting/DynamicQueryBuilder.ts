import type { SupabaseClient } from '@supabase/supabase-js';
import type {
  ReportDefinition,
  ReportFilterDef,
  ReportFilterOperator,
  ReportFilterValues,
  ReportSortDef,
} from './types';

const ALLOWED_OPERATORS = new Set<ReportFilterOperator>([
  'eq',
  'neq',
  'gt',
  'gte',
  'lt',
  'lte',
  'ilike',
  'in',
]);

type QueryBuilder = ReturnType<SupabaseClient['from']>;

function isBlank(value: unknown): boolean {
  return value == null || value === '' || (Array.isArray(value) && value.length === 0);
}

function getNestedValue(row: Record<string, unknown>, path: string): unknown {
  if (!path.includes('.')) return row[path];
  const parts = path.split('.');
  let cur: unknown = row;
  for (const part of parts) {
    if (cur == null || typeof cur !== 'object') return undefined;
    cur = (cur as Record<string, unknown>)[part];
  }
  return cur;
}

/**
 * Translates report metadata + runtime filters into a Supabase query.
 * Never accepts raw SQL — only whitelisted fields/operators from metadata.
 */
export class DynamicQueryBuilder {
  buildSelect(definition: ReportDefinition): string {
    const joinParts = (definition.joins ?? []).map((join) => {
      const cols = join.columns?.length ? join.columns.join(',') : '*';
      // relation may already include !inner
      const relName = join.relation.replace(/!inner$/, '');
      const modifier = join.relation.endsWith('!inner') ? '!inner' : '';
      return `${relName}${modifier}(${cols})`;
    });

    const baseFields = new Set<string>();
    for (const col of definition.columns) {
      if (!col.field.includes('.')) baseFields.add(col.field);
    }
    // Always include id when present for stable keys
    baseFields.add('id');

    const parts = [Array.from(baseFields).join(','), ...joinParts].filter(Boolean);
    return parts.join(',');
  }

  applySocietyScope(query: QueryBuilder, definition: ReportDefinition, societyId: string): QueryBuilder {
    if (definition.societyColumn) {
      return query.eq(definition.societyColumn, societyId) as QueryBuilder;
    }
    if (definition.societyVia) {
      const path = `${definition.societyVia.relation}.${definition.societyVia.column}`;
      return query.eq(path, societyId) as QueryBuilder;
    }
    throw new Error(`Report "${definition.id}" has no society scope`);
  }

  applyFilters(
    query: QueryBuilder,
    definition: ReportDefinition,
    filters: ReportFilterValues = {},
  ): QueryBuilder {
    let q = query;
    for (const filterDef of definition.filters) {
      const raw = filters[filterDef.key] ?? filterDef.defaultValue;
      if (isBlank(raw)) continue;
      q = this.applyOneFilter(q, filterDef, raw);
    }

    for (const fixed of definition.fixedFilters ?? []) {
      if (fixed.op === 'not_null') {
        q = q.not(fixed.field, 'is', null).neq(fixed.field, '') as QueryBuilder;
      } else if (fixed.op === 'eq') {
        q = q.eq(fixed.field, fixed.value) as QueryBuilder;
      } else if (fixed.op === 'neq') {
        q = q.neq(fixed.field, fixed.value) as QueryBuilder;
      }
    }

    return q;
  }

  private applyOneFilter(query: QueryBuilder, filterDef: ReportFilterDef, raw: unknown): QueryBuilder {
    if (filterDef.type === 'date_range') {
      const range = raw as { from?: string; to?: string };
      let q = query;
      if (range?.from) q = q.gte(filterDef.field, this.dateBound(range.from, 'start')) as QueryBuilder;
      if (range?.to) q = q.lte(filterDef.field, this.dateBound(range.to, 'end')) as QueryBuilder;
      return q;
    }

    const op: ReportFilterOperator = filterDef.operator ?? 'eq';
    if (!ALLOWED_OPERATORS.has(op)) {
      throw new Error(`Operator not allowed: ${op}`);
    }

    switch (op) {
      case 'eq':
        return query.eq(filterDef.field, raw as string | number | boolean) as QueryBuilder;
      case 'neq':
        return query.neq(filterDef.field, raw as string | number | boolean) as QueryBuilder;
      case 'gt':
        return query.gt(filterDef.field, raw as string | number) as QueryBuilder;
      case 'gte':
        return query.gte(filterDef.field, raw as string | number) as QueryBuilder;
      case 'lt':
        return query.lt(filterDef.field, raw as string | number) as QueryBuilder;
      case 'lte':
        return query.lte(filterDef.field, raw as string | number) as QueryBuilder;
      case 'ilike':
        return query.ilike(filterDef.field, `%${String(raw)}%`) as QueryBuilder;
      case 'in': {
        const values = Array.isArray(raw) ? raw : String(raw).split(',').map((s) => s.trim());
        return query.in(filterDef.field, values) as QueryBuilder;
      }
      default:
        return query;
    }
  }

  applySort(query: QueryBuilder, definition: ReportDefinition, sort?: ReportSortDef): QueryBuilder {
    const effective = sort ?? definition.defaultSort;
    if (!effective) return query;
    const allowed = definition.columns.some((c) => c.field === effective.field || c.key === effective.field);
    if (!allowed) return query;
    const field =
      definition.columns.find((c) => c.key === effective.field)?.field ?? effective.field;
    if (field.includes('.')) {
      // Nested sort is not reliably supported via PostgREST; skip and sort client-side later.
      return query;
    }
    return query.order(field, { ascending: effective.direction === 'asc' }) as QueryBuilder;
  }

  /** Map raw DB rows to column-keyed row objects using metadata field paths. */
  projectRows(
    definition: ReportDefinition,
    rawRows: Record<string, unknown>[],
    columnKeys: string[],
  ): Record<string, unknown>[] {
    const cols = definition.columns.filter((c) => columnKeys.includes(c.key));
    return rawRows.map((raw) => {
      const out: Record<string, unknown> = { id: raw.id };
      for (const col of cols) {
        out[col.key] = getNestedValue(raw, col.field);
      }
      return out;
    });
  }

  private dateBound(value: string, edge: 'start' | 'end'): string {
    // If caller passed a full ISO timestamp, keep it; otherwise expand date-only bounds.
    if (value.includes('T')) return value;
    return edge === 'start' ? `${value}T00:00:00` : `${value}T23:59:59.999`;
  }
}

export const dynamicQueryBuilder = new DynamicQueryBuilder();
