import { useEffect, useMemo } from 'react';
import { Bookmark, ChevronLeft, ChevronRight, Layers, Trash2 } from 'lucide-react';
import { moneyInr, type ExportFormat } from '@/lib/reportExportUtils';
import type { AdminPanelPermissions } from '@/lib/adminPermissions';
import { FULL_ADMIN_PERMISSIONS } from '@/lib/adminPermissions';
import { useMetadataReport } from '@/hooks/useMetadataReport';
import { toast } from 'sonner';

type Props = {
  societyId: string;
  societyName?: string;
  adminName?: string;
  permissions?: AdminPanelPermissions;
  /** Shared from ReportPage month / custom period. */
  periodFrom: string;
  periodTo: string;
  /** Shared ReportPage search. */
  searchQuery?: string;
  /** Register export handler with parent header Export menu. */
  onExportReady?: (exporter: ((format: ExportFormat) => Promise<void>) | null) => void;
};

function formatCell(format: string | undefined, type: string, value: unknown): string {
  if (value == null || value === '') return '—';
  if (format === 'money' || type === 'number') {
    const n = Number(value);
    if (!Number.isFinite(n)) return String(value);
    return format === 'money' ? moneyInr(n) : n.toLocaleString('en-IN');
  }
  if (format === 'date' && typeof value === 'string') return value.slice(0, 10);
  if (format === 'datetime' && typeof value === 'string') return value.replace('T', ' ').slice(0, 19);
  return String(value);
}

/**
 * Generic metadata-driven report UI.
 * Period + search come from ReportPage so all report tabs stay synchronized.
 */
export default function MetadataReportEngine({
  societyId,
  societyName,
  adminName = 'Admin',
  permissions = FULL_ADMIN_PERMISSIONS,
  periodFrom,
  periodTo,
  searchQuery = '',
  onExportReady,
}: Props) {
  const engine = useMetadataReport({
    societyId,
    permissions,
    societyName,
    adminName,
    periodFrom,
    periodTo,
    searchQuery,
  });

  useEffect(() => {
    onExportReady?.(engine.exportReport);
    return () => onExportReady?.(null);
  }, [onExportReady, engine.exportReport]);

  const extraFilters = useMemo(
    () =>
      (engine.definition?.filters ?? []).filter(
        (f) => f.type !== 'date_range' || f.key !== engine.syncedDateRangeKey,
      ),
    [engine.definition, engine.syncedDateRangeKey],
  );

  const onSave = async () => {
    try {
      await engine.saveCurrent();
      toast.success('Report definition saved');
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Save failed');
    }
  };

  if (!engine.catalog.length) {
    return (
      <div className="rounded-lg border border-border bg-card/40 p-3 text-sm text-muted-foreground">
        No reports available for your role.
      </div>
    );
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-end gap-2">
        <label className="flex flex-col gap-1 min-w-[200px] flex-1">
          <span className="text-[11px] font-medium text-muted-foreground">Report</span>
          <select
            className="input-field text-sm"
            value={engine.reportId}
            onChange={(e) => engine.setReportId(e.target.value)}
          >
            {engine.catalog.map((r) => (
              <option key={r.id} value={r.id}>
                {r.title}
              </option>
            ))}
          </select>
        </label>
        {engine.loading && (
          <span className="text-[11px] text-muted-foreground pb-2">Updating…</span>
        )}
      </div>

      {engine.definition?.description && (
        <p className="text-xs text-muted-foreground">
          {engine.definition.description}
          {' · '}
          Period synced with report month above
        </p>
      )}

      {/* Non-period filters only — dates/search come from ReportPage */}
      {extraFilters.length > 0 && (
        <div className="rounded-lg border border-border bg-card/40 p-3 space-y-3">
          <p className="text-[11px] font-medium text-foreground">Filters</p>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
            {extraFilters.map((f) => {
              if (f.type === 'date_range') {
                const val = (engine.filters[f.key] as { from?: string; to?: string } | undefined) ?? {};
                return (
                  <label key={f.key} className="flex flex-col gap-1">
                    <span className="text-[11px] text-muted-foreground">{f.label}</span>
                    <div className="flex gap-2">
                      <input
                        type="date"
                        className="input-field text-xs flex-1"
                        value={val.from ?? ''}
                        onChange={(e) =>
                          engine.setFilterValue(f.key, { ...val, from: e.target.value })
                        }
                      />
                      <input
                        type="date"
                        className="input-field text-xs flex-1"
                        value={val.to ?? ''}
                        onChange={(e) =>
                          engine.setFilterValue(f.key, { ...val, to: e.target.value })
                        }
                      />
                    </div>
                  </label>
                );
              }
              return (
                <label key={f.key} className="flex flex-col gap-1">
                  <span className="text-[11px] text-muted-foreground">{f.label}</span>
                  {f.type === 'select' ? (
                    <select
                      className="input-field text-xs"
                      value={String(engine.filters[f.key] ?? '')}
                      onChange={(e) => engine.setFilterValue(f.key, e.target.value || undefined)}
                    >
                      <option value="">All</option>
                      {f.options?.map((o) => (
                        <option key={o.value} value={o.value}>
                          {o.label}
                        </option>
                      ))}
                    </select>
                  ) : f.type === 'boolean' ? (
                    <select
                      className="input-field text-xs"
                      value={
                        engine.filters[f.key] === true
                          ? 'true'
                          : engine.filters[f.key] === false
                            ? 'false'
                            : ''
                      }
                      onChange={(e) => {
                        const v = e.target.value;
                        engine.setFilterValue(f.key, v === '' ? undefined : v === 'true');
                      }}
                    >
                      <option value="">All</option>
                      <option value="true">Yes</option>
                      <option value="false">No</option>
                    </select>
                  ) : (
                    <input
                      className="input-field text-xs"
                      type={f.type === 'number' ? 'number' : 'text'}
                      value={String(engine.filters[f.key] ?? '')}
                      onChange={(e) => engine.setFilterValue(f.key, e.target.value || undefined)}
                    />
                  )}
                </label>
              );
            })}
          </div>
        </div>
      )}

      {engine.definition && (
        <div className="rounded-lg border border-border bg-card/40 p-3 space-y-3">
          <div className="flex flex-wrap items-center gap-3">
            <label className="flex flex-col gap-1 min-w-[160px]">
              <span className="text-[11px] text-muted-foreground">Columns</span>
              <select
                className="input-field text-xs"
                value=""
                onChange={(e) => {
                  const key = e.target.value;
                  if (key) engine.toggleColumn(key);
                }}
              >
                <option value="">Toggle column…</option>
                {engine.definition.columns.map((c) => (
                  <option key={c.key} value={c.key}>
                    {engine.selectedColumns.includes(c.key) ? '✓ ' : ''}
                    {c.label}
                  </option>
                ))}
              </select>
            </label>
            <label className="flex flex-col gap-1 min-w-[160px]">
              <span className="text-[11px] text-muted-foreground flex items-center gap-1">
                <Layers className="w-3 h-3" /> Group by
              </span>
              <select
                className="input-field text-xs"
                value={engine.groupBy[0] ?? ''}
                onChange={(e) => engine.setGroupBy(e.target.value ? [e.target.value] : [])}
              >
                <option value="">None</option>
                {engine.definition.columns.map((c) => (
                  <option key={c.key} value={c.key}>
                    {c.label}
                  </option>
                ))}
              </select>
            </label>
          </div>
          <p className="text-[10px] text-muted-foreground">
            Showing: {engine.selectedColumns.map((k) => engine.definition?.columns.find((c) => c.key === k)?.label ?? k).join(', ')}
          </p>
        </div>
      )}

      <div className="rounded-lg border border-border bg-card/40 p-3 space-y-2">
        <p className="text-[11px] font-medium text-foreground flex items-center gap-1">
          <Bookmark className="w-3.5 h-3.5" /> Saved views
        </p>
        <div className="flex flex-wrap gap-2">
          <input
            className="input-field text-xs flex-1 min-w-[160px]"
            placeholder="Name this view…"
            value={engine.saveName}
            onChange={(e) => engine.setSaveName(e.target.value)}
          />
          <button
            type="button"
            className="btn-secondary text-xs px-3 py-2"
            disabled={!engine.saveName.trim()}
            onClick={() => void onSave()}
          >
            Save
          </button>
        </div>
        {engine.saved.length > 0 && (
          <ul className="space-y-1">
            {engine.saved.map((s) => (
              <li
                key={s.id}
                className="flex items-center justify-between gap-2 text-xs rounded-md px-2 py-1.5 bg-secondary/50"
              >
                <button
                  type="button"
                  className="text-left flex-1 hover:underline"
                  onClick={() => engine.loadSaved(s)}
                >
                  {s.name}
                </button>
                <button
                  type="button"
                  className="text-muted-foreground hover:text-destructive"
                  aria-label="Delete saved report"
                  onClick={() => void engine.deleteSaved(s.id)}
                >
                  <Trash2 className="w-3.5 h-3.5" />
                </button>
              </li>
            ))}
          </ul>
        )}
      </div>

      {engine.error && (
        <p className="text-xs text-destructive border border-destructive/30 rounded-lg px-3 py-2">
          {engine.error}
        </p>
      )}

      {engine.result && (
        <div className="space-y-2">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <p className="text-xs text-muted-foreground">
              {engine.result.totalRows} row{engine.result.totalRows === 1 ? '' : 's'}
              {engine.result.grouped ? ' (grouped)' : ''}
              {engine.result.totals.length > 0 && (
                <>
                  {' · '}
                  {engine.result.totals.map((t) => `${t.label} ${moneyInr(t.value)}`).join(' · ')}
                </>
              )}
            </p>
            <div className="flex items-center gap-1">
              <button
                type="button"
                className="btn-secondary text-xs px-2 py-1"
                disabled={engine.page <= 1}
                onClick={() => engine.setPage((p) => Math.max(1, p - 1))}
              >
                <ChevronLeft className="w-3.5 h-3.5" />
              </button>
              <span className="text-[11px] text-muted-foreground px-1">
                {engine.result.page} / {engine.result.totalPages}
              </span>
              <button
                type="button"
                className="btn-secondary text-xs px-2 py-1"
                disabled={engine.page >= engine.result.totalPages}
                onClick={() => engine.setPage((p) => p + 1)}
              >
                <ChevronRight className="w-3.5 h-3.5" />
              </button>
            </div>
          </div>

          <div className="overflow-x-auto border border-border rounded-xl">
            <table className="w-full text-xs">
              <thead>
                <tr className="text-left text-muted-foreground border-b border-border bg-secondary/40">
                  {engine.result.columns.map((c) => (
                    <th key={c.key} className="py-2 px-2 font-medium whitespace-nowrap">
                      {c.sortable !== false ? (
                        <button
                          type="button"
                          className="hover:text-foreground"
                          onClick={() => {
                            const dir =
                              engine.sort?.field === c.field || engine.sort?.field === c.key
                                ? engine.sort.direction === 'asc'
                                  ? 'desc'
                                  : 'asc'
                                : 'asc';
                            engine.setSort({ field: c.field, direction: dir });
                          }}
                        >
                          {c.label}
                        </button>
                      ) : (
                        c.label
                      )}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {engine.result.rows.length === 0 ? (
                  <tr>
                    <td
                      className="py-6 px-2 text-center text-muted-foreground"
                      colSpan={engine.result.columns.length}
                    >
                      No rows match the current filters.
                    </td>
                  </tr>
                ) : (
                  engine.result.rows.map((row, idx) => (
                    <tr
                      key={String(row.id ?? idx)}
                      className="border-b border-border/60 last:border-0"
                    >
                      {engine.result!.columns.map((c) => (
                        <td
                          key={c.key}
                          className={`py-2 px-2 whitespace-nowrap ${
                            c.type === 'number' || c.format === 'money' ? 'text-right tabular-nums' : ''
                          }`}
                        >
                          {formatCell(c.format, c.type, row[c.key])}
                        </td>
                      ))}
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}
