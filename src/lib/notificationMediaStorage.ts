import { supabase } from '@/integrations/supabase/client';

const BUCKET = 'notification-media';

export type UploadMediaOptions = {
  upsert?: boolean;
  contentType?: string;
  cacheControl?: string;
  onError?: (message: string) => void;
};

export function sanitizeStorageFileName(name: string): string {
  return name.replace(/[^\w.-]/g, '_');
}

/** Upload a file or blob to the notification-media bucket and return its public URL. */
export async function uploadToNotificationMedia(
  path: string,
  file: File | Blob,
  options?: UploadMediaOptions,
): Promise<string | null> {
  const contentType =
    options?.contentType ?? (file instanceof File ? file.type || undefined : undefined);
  const { error } = await supabase.storage.from(BUCKET).upload(path, file, {
    cacheControl: options?.cacheControl ?? '3600',
    upsert: options?.upsert ?? false,
    contentType,
  });
  if (error) {
    options?.onError?.(error.message);
    return null;
  }
  const { data } = supabase.storage.from(BUCKET).getPublicUrl(path);
  return data.publicUrl;
}

export async function uploadMaintenanceReceipt(file: File): Promise<string | null> {
  const path = `maintenance-receipts/${crypto.randomUUID()}_${sanitizeStorageFileName(file.name)}`;
  return uploadToNotificationMedia(path, file);
}

export async function uploadExpenseBill(groupId: string, file: File, onError?: (m: string) => void): Promise<string | null> {
  const path = `expense-bills/${groupId}/${crypto.randomUUID()}_${sanitizeStorageFileName(file.name)}`;
  return uploadToNotificationMedia(path, file, { onError });
}

export async function uploadContributionReceipt(file: File, onError?: (m: string) => void): Promise<string | null> {
  const path = `event-contributions/${crypto.randomUUID()}_${sanitizeStorageFileName(file.name)}`;
  return uploadToNotificationMedia(path, file, { onError });
}

export async function uploadFinancePeriodReportPdf(
  societyId: string,
  batchId: string,
  blob: Blob,
  onError?: (m: string) => void,
): Promise<string | null> {
  const path = `finance-reports/${societyId}/${batchId}.pdf`;
  return uploadToNotificationMedia(path, blob, {
    contentType: 'application/pdf',
    upsert: true,
    onError,
  });
}

export async function uploadMeetingFile(
  societyId: string,
  meetingId: string,
  kind: 'docs' | 'audio' | 'signatures',
  file: Blob,
  filename: string,
): Promise<string | null> {
  const safe = sanitizeStorageFileName(filename).slice(0, 120);
  const path = `meetings/${societyId}/${meetingId}/${kind}/${crypto.randomUUID()}_${safe}`;
  return uploadToNotificationMedia(path, file, { contentType: file.type || undefined });
}
