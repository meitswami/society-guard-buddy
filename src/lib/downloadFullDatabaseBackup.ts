import { supabase } from '@/integrations/supabase/client';

/** Invokes `backup-export` with no society filter — all tables, all rows (service role on server). */
export async function downloadFullDatabaseBackup(): Promise<void> {
  const { data, error } = await supabase.functions.invoke('backup-export', {
    body: { society_id: null },
  });
  if (error) throw error;
  if (data && typeof data === 'object' && 'error' in data && data.error) {
    throw new Error(String(data.error));
  }

  const json = typeof data === 'string' ? data : JSON.stringify(data, null, 2);
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
