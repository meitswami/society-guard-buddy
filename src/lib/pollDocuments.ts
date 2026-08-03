import { supabase } from '@/integrations/supabase/client';
import { sanitizeStorageFileName, uploadToNotificationMedia } from '@/lib/notificationMediaStorage';

export type PollDocKind = 'circular' | 'letter' | 'personal' | 'society' | 'other';

export type PollDocumentRow = {
  id: string;
  poll_id: string;
  society_id: string | null;
  title: string;
  doc_kind: PollDocKind | string;
  file_url: string;
  file_name: string | null;
  mime_type: string | null;
  sort_order: number;
  created_by: string | null;
  created_at: string;
};

export const POLL_DOC_KIND_LABELS: Record<PollDocKind, string> = {
  circular: 'Circular',
  letter: 'Letter',
  personal: 'Personal letter',
  society: 'Society letter',
  other: 'Other',
};

export async function fetchPollDocuments(pollIds: string[]): Promise<PollDocumentRow[]> {
  if (pollIds.length === 0) return [];
  const { data, error } = await supabase
    .from('poll_documents')
    .select('*')
    .in('poll_id', pollIds)
    .order('sort_order', { ascending: true })
    .order('created_at', { ascending: true });
  if (error) throw error;
  return (data ?? []) as PollDocumentRow[];
}

export async function uploadPollDocument(params: {
  societyId: string;
  pollId: string;
  file: File;
  title: string;
  docKind: PollDocKind;
  createdBy: string;
  sortOrder?: number;
}): Promise<PollDocumentRow | null> {
  const safe = sanitizeStorageFileName(params.file.name).slice(0, 120);
  const path = `poll-documents/${params.societyId}/${params.pollId}/${crypto.randomUUID()}_${safe}`;
  const url = await uploadToNotificationMedia(path, params.file, {
    contentType: params.file.type || undefined,
  });
  if (!url) return null;

  const { data, error } = await supabase
    .from('poll_documents')
    .insert([
      {
        poll_id: params.pollId,
        society_id: params.societyId,
        title: params.title.trim() || params.file.name,
        doc_kind: params.docKind,
        file_url: url,
        file_name: params.file.name,
        mime_type: params.file.type || null,
        sort_order: params.sortOrder ?? 0,
        created_by: params.createdBy,
      },
    ])
    .select()
    .single();

  if (error) {
    console.error(error);
    return null;
  }
  return data as PollDocumentRow;
}

export async function deletePollDocument(doc: PollDocumentRow): Promise<string | null> {
  const { error } = await supabase.from('poll_documents').delete().eq('id', doc.id);
  return error?.message ?? null;
}
