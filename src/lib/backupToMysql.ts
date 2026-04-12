/** Shape returned by `backup-export` Edge Function */
export type BackupPayload = {
  metadata?: Record<string, unknown>;
  data: Record<string, unknown[]>;
};

function safeIdent(name: string): string {
  return '`' + name.replace(/`/g, '``') + '`';
}

function escapeMysqlString(s: string): string {
  return (
    "'" +
    s
      .replace(/\\/g, '\\\\')
      .replace(/'/g, "\\'")
      .replace(/\n/g, '\\n')
      .replace(/\r/g, '\\r')
      .replace(/\t/g, '\\t')
      .replace(/\x1a/g, '\\Z') +
    "'"
  );
}

function sqlLiteral(v: unknown): string {
  if (v === null || v === undefined) return 'NULL';
  if (typeof v === 'boolean') return v ? '1' : '0';
  if (typeof v === 'number') {
    if (!Number.isFinite(v)) return 'NULL';
    return String(v);
  }
  if (typeof v === 'bigint') return escapeMysqlString(v.toString());
  if (typeof v === 'object') return escapeMysqlString(JSON.stringify(v));
  if (typeof v === 'string') return escapeMysqlString(v);
  return escapeMysqlString(String(v));
}

function collectColumns(rows: unknown[]): string[] {
  const keys = new Set<string>();
  for (const row of rows) {
    if (row && typeof row === 'object' && !Array.isArray(row)) {
      for (const k of Object.keys(row as Record<string, unknown>)) keys.add(k);
    }
  }
  return [...keys].sort();
}

/**
 * Builds a MySQL-oriented .sql file: INSERTs only (no CREATE TABLE).
 * Import with `mysql < file.sql` or paste into a client; disable FK checks during import if order matters.
 */
export function backupPayloadToMysqlSql(payload: BackupPayload): string {
  const lines: string[] = [];
  const meta = payload.metadata ?? {};
  const exported =
    typeof meta.exported_at === 'string' ? meta.exported_at : new Date().toISOString();

  lines.push('-- Society Guard Buddy — full data export (MySQL-oriented INSERTs)');
  lines.push(`-- exported_at: ${exported}`);
  lines.push('-- No CREATE TABLE; types must exist or be created separately.');
  lines.push('');
  lines.push('SET NAMES utf8mb4;');
  lines.push('SET FOREIGN_KEY_CHECKS = 0;');
  lines.push('SET @OLD_SQL_MODE = @@SQL_MODE;');
  lines.push("SET SQL_MODE = 'NO_AUTO_VALUE_ON_ZERO';");
  lines.push('');

  const data = payload.data ?? {};
  const tableNames = Object.keys(data).sort();

  for (const table of tableNames) {
    const rows = data[table];
    if (!Array.isArray(rows) || rows.length === 0) {
      lines.push(`-- ${table}: 0 rows`);
      lines.push('');
      continue;
    }

    const cols = collectColumns(rows);
    if (cols.length === 0) continue;

    const colList = cols.map(safeIdent).join(', ');
    lines.push(`-- ${table}: ${rows.length} rows`);

    for (const row of rows) {
      if (!row || typeof row !== 'object' || Array.isArray(row)) continue;
      const rec = row as Record<string, unknown>;
      const vals = cols.map((c) => sqlLiteral(Object.prototype.hasOwnProperty.call(rec, c) ? rec[c] : null));
      lines.push(`INSERT INTO ${safeIdent(table)} (${colList}) VALUES (${vals.join(', ')});`);
    }
    lines.push('');
  }

  lines.push('SET SQL_MODE = @OLD_SQL_MODE;');
  lines.push('SET FOREIGN_KEY_CHECKS = 1;');

  return lines.join('\n');
}
