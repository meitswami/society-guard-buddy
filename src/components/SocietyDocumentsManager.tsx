import { useCallback, useEffect, useMemo, useState } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useStore } from '@/store/useStore';
import {
  FileText,
  Upload,
  Trash2,
  Eye,
  EyeOff,
  Download,
  FolderOpen,
  Loader2,
  Plus,
} from 'lucide-react';
import { toast } from 'sonner';
import { confirmAction } from '@/lib/swal';
import { fmtDate } from '@/lib/dateFormat';
import ProtectedDocumentViewer from '@/components/ProtectedDocumentViewer';

export type SocietyDocumentCategory =
  | 'bylaws'
  | 'minutes'
  | 'notices'
  | 'reports'
  | 'forms'
  | 'other';

export type SocietyDocumentRow = {
  id: string;
  society_id: string;
  title: string;
  description: string | null;
  category: SocietyDocumentCategory;
  storage_path: string;
  file_name: string;
  mime_type: string | null;
  published: boolean;
  sort_order: number;
  uploaded_by: string | null;
  created_at: string;
  updated_at: string;
};

const CATEGORIES: { id: SocietyDocumentCategory; label: string }[] = [
  { id: 'bylaws', label: 'Bylaws & rules' },
  { id: 'minutes', label: 'Meeting minutes' },
  { id: 'notices', label: 'Notices & circulars' },
  { id: 'reports', label: 'Reports' },
  { id: 'forms', label: 'Forms' },
  { id: 'other', label: 'Other' },
];

const ACCEPTED_TYPES = [
  'application/pdf',
  'image/png',
  'image/jpeg',
  'image/webp',
];

const MAX_FILE_BYTES = 15 * 1024 * 1024;

interface Props {
  isResident?: boolean;
  adminName?: string;
  viewerLabel?: string;
}

async function uploadSocietyDocumentFile(
  societyId: string,
  docId: string,
  file: File,
): Promise<string | null> {
  const safe = file.name.replace(/[^\w.-]/g, '_');
  const path = `${societyId}/${docId}/${safe}`;
  const { error } = await supabase.storage.from('society-documents').upload(path, file, {
    cacheControl: '3600',
    upsert: false,
    contentType: file.type || undefined,
  });
  if (error) {
    toast.error(error.message);
    return null;
  }
  return path;
}

export default function SocietyDocumentsManager({ isResident, adminName, viewerLabel }: Props) {
  const societyId = useStore((s) => s.societyId);
  const [docs, setDocs] = useState<SocietyDocumentRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [categoryFilter, setCategoryFilter] = useState<SocietyDocumentCategory | 'all'>('all');
  const [uploading, setUploading] = useState(false);
  const [showUpload, setShowUpload] = useState(false);
  const [newTitle, setNewTitle] = useState('');
  const [newDescription, setNewDescription] = useState('');
  const [newCategory, setNewCategory] = useState<SocietyDocumentCategory>('other');
  const [viewerDoc, setViewerDoc] = useState<SocietyDocumentRow | null>(null);
  const [viewerUrl, setViewerUrl] = useState<string | null>(null);
  const [openingId, setOpeningId] = useState<string | null>(null);

  const loadDocs = useCallback(async () => {
    if (!societyId) return;
    setLoading(true);
    let q = supabase
      .from('society_documents')
      .select('*')
      .eq('society_id', societyId)
      .order('sort_order', { ascending: true })
      .order('created_at', { ascending: false });
    if (isResident) q = q.eq('published', true);
    const { data, error } = await q;
    if (error) toast.error(error.message);
    else setDocs((data ?? []) as SocietyDocumentRow[]);
    setLoading(false);
  }, [societyId, isResident]);

  useEffect(() => {
    void loadDocs();
  }, [loadDocs]);

  const filtered = useMemo(() => {
    if (categoryFilter === 'all') return docs;
    return docs.filter((d) => d.category === categoryFilter);
  }, [docs, categoryFilter]);

  const grouped = useMemo(() => {
    const map = new Map<SocietyDocumentCategory, SocietyDocumentRow[]>();
    for (const cat of CATEGORIES) map.set(cat.id, []);
    for (const doc of filtered) {
      const list = map.get(doc.category) ?? [];
      list.push(doc);
      map.set(doc.category, list);
    }
    return CATEGORIES.map((c) => ({ ...c, items: map.get(c.id) ?? [] })).filter((g) => g.items.length > 0);
  }, [filtered]);

  const openViewer = async (doc: SocietyDocumentRow, protectedView: boolean) => {
    setOpeningId(doc.id);
    const ttl = protectedView ? 300 : 3600;
    const { data, error } = await supabase.storage
      .from('society-documents')
      .createSignedUrl(doc.storage_path, ttl);
    setOpeningId(null);
    if (error || !data?.signedUrl) {
      toast.error(error?.message ?? 'Could not open document');
      return;
    }
    if (protectedView) {
      setViewerUrl(data.signedUrl);
      setViewerDoc(doc);
    } else {
      window.open(data.signedUrl, '_blank', 'noopener,noreferrer');
    }
  };

  const closeViewer = () => {
    setViewerDoc(null);
    setViewerUrl(null);
  };

  const handleUpload = async (file: File | null) => {
    if (!societyId || !file) return;
    if (!newTitle.trim()) {
      toast.error('Enter a document title');
      return;
    }
    if (!ACCEPTED_TYPES.includes(file.type)) {
      toast.error('Only PDF and image files (PNG, JPEG, WebP) are allowed');
      return;
    }
    if (file.size > MAX_FILE_BYTES) {
      toast.error('File must be 15 MB or smaller');
      return;
    }

    setUploading(true);
    const docId = crypto.randomUUID();
    const path = await uploadSocietyDocumentFile(societyId, docId, file);
    if (!path) {
      setUploading(false);
      return;
    }

    const { error } = await supabase.from('society_documents').insert([
      {
        id: docId,
        society_id: societyId,
        title: newTitle.trim(),
        description: newDescription.trim() || null,
        category: newCategory,
        storage_path: path,
        file_name: file.name,
        mime_type: file.type || null,
        published: false,
        sort_order: docs.length,
        uploaded_by: adminName ?? null,
      },
    ]);

    setUploading(false);
    if (error) {
      toast.error(error.message);
      await supabase.storage.from('society-documents').remove([path]);
      return;
    }

    toast.success('Document uploaded');
    setNewTitle('');
    setNewDescription('');
    setNewCategory('other');
    setShowUpload(false);
    void loadDocs();
  };

  const togglePublished = async (doc: SocietyDocumentRow) => {
    const { error } = await supabase
      .from('society_documents')
      .update({ published: !doc.published })
      .eq('id', doc.id);
    if (error) toast.error(error.message);
    else {
      toast.success(doc.published ? 'Hidden from members' : 'Published for members');
      void loadDocs();
    }
  };

  const deleteDoc = async (doc: SocietyDocumentRow) => {
    const ok = await confirmAction(
      'Delete document?',
      `"${doc.title}" will be removed permanently.`,
      'Delete',
      'Cancel',
    );
    if (!ok) return;
    const { error: storageErr } = await supabase.storage.from('society-documents').remove([doc.storage_path]);
    if (storageErr) toast.error(storageErr.message);
    const { error } = await supabase.from('society_documents').delete().eq('id', doc.id);
    if (error) toast.error(error.message);
    else {
      toast.success('Document deleted');
      void loadDocs();
    }
  };

  if (!societyId) {
    return (
      <div className="page-container text-sm text-muted-foreground">Society not loaded.</div>
    );
  }

  return (
    <div className="page-container pb-24">
      <div className="flex items-start justify-between gap-3 mb-4">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
            <FolderOpen className="w-5 h-5 text-primary" />
          </div>
          <div>
            <h2 className="font-semibold">Society documents</h2>
            <p className="text-xs text-muted-foreground">
              {isResident
                ? 'Official society records — view only in this app'
                : 'Upload bylaws, minutes, notices, and other society files for members'}
            </p>
          </div>
        </div>
        {!isResident && (
          <button type="button" className="btn-primary text-sm shrink-0" onClick={() => setShowUpload((v) => !v)}>
            <Plus className="w-4 h-4 mr-1 inline" />
            {showUpload ? 'Close' : 'Add'}
          </button>
        )}
      </div>

      {!isResident && showUpload && (
        <div className="card-section p-4 mb-4 space-y-3">
          <p className="text-xs font-medium text-muted-foreground uppercase tracking-wider">New document</p>
          <input
            className="input-field w-full"
            placeholder="Title *"
            value={newTitle}
            onChange={(e) => setNewTitle(e.target.value)}
          />
          <textarea
            className="input-field w-full min-h-[72px]"
            placeholder="Description (optional)"
            value={newDescription}
            onChange={(e) => setNewDescription(e.target.value)}
          />
          <select
            className="input-field w-full"
            value={newCategory}
            onChange={(e) => setNewCategory(e.target.value as SocietyDocumentCategory)}
          >
            {CATEGORIES.map((c) => (
              <option key={c.id} value={c.id}>{c.label}</option>
            ))}
          </select>
          <label className="flex flex-col items-center justify-center gap-2 border-2 border-dashed border-border rounded-xl p-6 cursor-pointer hover:bg-muted/50 transition-colors">
            <Upload className="w-6 h-6 text-muted-foreground" />
            <span className="text-sm text-muted-foreground">PDF or image (max 15 MB)</span>
            <input
              type="file"
              className="hidden"
              accept=".pdf,image/png,image/jpeg,image/webp"
              disabled={uploading}
              onChange={(e) => {
                const f = e.target.files?.[0] ?? null;
                void handleUpload(f);
                e.target.value = '';
              }}
            />
          </label>
          {uploading && (
            <p className="text-xs text-muted-foreground flex items-center gap-2">
              <Loader2 className="w-3 h-3 animate-spin" /> Uploading…
            </p>
          )}
        </div>
      )}

      <div className="flex gap-2 overflow-x-auto pb-2 mb-3 scrollbar-none">
        <button
          type="button"
          className={`shrink-0 px-3 py-1.5 rounded-full text-xs font-medium border ${categoryFilter === 'all' ? 'bg-primary text-primary-foreground border-primary' : 'border-border bg-card'}`}
          onClick={() => setCategoryFilter('all')}
        >
          All
        </button>
        {CATEGORIES.map((c) => (
          <button
            key={c.id}
            type="button"
            className={`shrink-0 px-3 py-1.5 rounded-full text-xs font-medium border ${categoryFilter === c.id ? 'bg-primary text-primary-foreground border-primary' : 'border-border bg-card'}`}
            onClick={() => setCategoryFilter(c.id)}
          >
            {c.label}
          </button>
        ))}
      </div>

      {loading ? (
        <div className="flex items-center justify-center py-16 text-muted-foreground text-sm">
          <Loader2 className="w-5 h-5 animate-spin mr-2" /> Loading documents…
        </div>
      ) : filtered.length === 0 ? (
        <div className="card-section p-8 text-center text-sm text-muted-foreground">
          <FileText className="w-10 h-10 mx-auto mb-3 opacity-40" />
          {isResident ? 'No documents published yet.' : 'No documents yet. Upload the first one above.'}
        </div>
      ) : (
        <div className="space-y-5">
          {grouped.map((group) => (
            <section key={group.id}>
              <h3 className="text-xs font-semibold text-muted-foreground uppercase tracking-wider mb-2">
                {group.label}
              </h3>
              <div className="space-y-2">
                {group.items.map((doc) => (
                  <div key={doc.id} className="card-section p-3 flex items-start gap-3">
                    <div className="w-9 h-9 rounded-lg bg-muted flex items-center justify-center shrink-0">
                      <FileText className="w-4 h-4 text-primary" />
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="font-medium text-sm truncate">{doc.title}</p>
                      {doc.description && (
                        <p className="text-xs text-muted-foreground line-clamp-2 mt-0.5">{doc.description}</p>
                      )}
                      <p className="text-[10px] text-muted-foreground mt-1">
                        {fmtDate(doc.created_at)}
                        {!isResident && (
                          <span className={`ml-2 ${doc.published ? 'text-emerald-600' : 'text-amber-600'}`}>
                            {doc.published ? '· Published' : '· Draft'}
                          </span>
                        )}
                      </p>
                    </div>
                    <div className="flex flex-col gap-1 shrink-0">
                      <button
                        type="button"
                        className="p-2 rounded-lg bg-primary/10 text-primary"
                        title={isResident ? 'View' : 'Preview'}
                        disabled={openingId === doc.id}
                        onClick={() => void openViewer(doc, isResident ?? false)}
                      >
                        {openingId === doc.id ? (
                          <Loader2 className="w-4 h-4 animate-spin" />
                        ) : (
                          <Eye className="w-4 h-4" />
                        )}
                      </button>
                      {!isResident && (
                        <>
                          <button
                            type="button"
                            className="p-2 rounded-lg bg-muted"
                            title="Download"
                            onClick={() => void openViewer(doc, false)}
                          >
                            <Download className="w-4 h-4" />
                          </button>
                          <button
                            type="button"
                            className="p-2 rounded-lg bg-muted"
                            title={doc.published ? 'Unpublish' : 'Publish for members'}
                            onClick={() => void togglePublished(doc)}
                          >
                            {doc.published ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                          </button>
                          <button
                            type="button"
                            className="p-2 rounded-lg bg-destructive/10 text-destructive"
                            title="Delete"
                            onClick={() => void deleteDoc(doc)}
                          >
                            <Trash2 className="w-4 h-4" />
                          </button>
                        </>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            </section>
          ))}
        </div>
      )}

      {viewerDoc && viewerUrl && (
        <ProtectedDocumentViewer
          title={viewerDoc.title}
          signedUrl={viewerUrl}
          mimeType={viewerDoc.mime_type}
          watermark={viewerLabel ?? 'Society document'}
          onClose={closeViewer}
        />
      )}
    </div>
  );
}
