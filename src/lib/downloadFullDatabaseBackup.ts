import { supabase } from '@/integrations/supabase/client';
import { backupPayloadToMysqlSql, type BackupPayload } from '@/lib/backupToMysql';

async function fetchFullBackupPayload(): Promise<BackupPayload> {
  const { data, error } = await supabase.functions.invoke('backup-export', {
    body: { society_id: null },
  });
  if (error) throw error;
  if (data && typeof data === 'object' && 'error' in data && data.error) {
    throw new Error(String(data.error));
  }

  const parsed =
    typeof data === 'string' ? (JSON.parse(data) as unknown) : data;

  if (!parsed || typeof parsed !== 'object' || !('data' in parsed)) {
    throw new Error('Invalid backup response');
  }

  return parsed as BackupPayload;
}

/** Invokes `backup-export` with no society filter — all tables, all rows (service role on server). */
export async function downloadFullDatabaseBackup(): Promise<void> {
  const payload = await fetchFullBackupPayload();
  const json = JSON.stringify(payload, null, 2);
  const ts = new Date().toISOString().replace(/[:.]/g, '-');
  const filename = `full_db_export_${ts}.json`;

  const blob = new Blob([json], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

/** Same data as JSON export, converted to MySQL INSERT statements (.sql). */
export async function downloadFullDatabaseMysql(): Promise<void> {
  const payload = await fetchFullBackupPayload();
  const sql = backupPayloadToMysqlSql(payload);
  const ts = new Date().toISOString().replace(/[:.]/g, '-');
  const filename = `full_db_export_${ts}.mysql`;

  const blob = new Blob([sql], { type: 'text/sql;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}
