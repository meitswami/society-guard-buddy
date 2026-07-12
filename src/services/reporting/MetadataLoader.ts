import { getBuiltinReportMap, BUILTIN_REPORT_DEFINITIONS } from './metadata/registry';
import { REPORTABLE_TABLES, type ReportDefinition, type ReportableTable } from './types';

const reportableSet = new Set<string>(REPORTABLE_TABLES);

/**
 * Loads and validates report metadata from the built-in registry.
 * Future: can also merge definitions stored in DB without code changes.
 */
export class MetadataLoader {
  private readonly byId: Map<string, ReportDefinition>;

  constructor(definitions: ReportDefinition[] = BUILTIN_REPORT_DEFINITIONS) {
    this.byId = new Map(definitions.map((d) => [d.id, d]));
  }

  list(): ReportDefinition[] {
    return Array.from(this.byId.values());
  }

  get(reportId: string): ReportDefinition | null {
    return this.byId.get(reportId) ?? getBuiltinReportMap().get(reportId) ?? null;
  }

  require(reportId: string): ReportDefinition {
    const def = this.get(reportId);
    if (!def) throw new Error(`Unknown report: ${reportId}`);
    this.validate(def);
    return def;
  }

  validate(def: ReportDefinition): void {
    if (!reportableSet.has(def.baseTable)) {
      throw new Error(`Report "${def.id}" uses non-reportable table: ${def.baseTable}`);
    }
    if (!def.societyColumn && !def.societyVia) {
      throw new Error(`Report "${def.id}" must define societyColumn or societyVia`);
    }
    if (def.columns.length === 0) {
      throw new Error(`Report "${def.id}" has no columns`);
    }
    const keys = new Set<string>();
    for (const col of def.columns) {
      if (keys.has(col.key)) throw new Error(`Report "${def.id}" has duplicate column key: ${col.key}`);
      keys.add(col.key);
    }
  }

  isReportableTable(table: string): table is ReportableTable {
    return reportableSet.has(table);
  }
}

export const metadataLoader = new MetadataLoader();
