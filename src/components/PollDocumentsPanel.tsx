import { useRef, useState } from 'react';
import { FileText, Paperclip, Trash2, ExternalLink } from 'lucide-react';
import { toast } from 'sonner';
import { confirmAction } from '@/lib/swal';
import {
  POLL_DOC_KIND_LABELS,
  deletePollDocument,
  uploadPollDocument,
  type PollDocKind,
  type PollDocumentRow,
} from '@/lib/pollDocuments';

type Props = {
  pollId: string;
  societyId: string | null;
  isAdmin: boolean;
  documents: PollDocumentRow[];
  createdBy: string;
  onChanged: () => void;
};

const KIND_OPTIONS = Object.entries(POLL_DOC_KIND_LABELS) as [PollDocKind, string][];

const PollDocumentsPanel = ({ pollId, societyId, isAdmin, documents, createdBy, onChanged }: Props) => {
  const inputRef = useRef<HTMLInputElement>(null);
  const [docKind, setDocKind] = useState<PollDocKind>('circular');
  const [title, setTitle] = useState('');
  const [uploading, setUploading] = useState(false);
  const [open, setOpen] = useState(documents.length > 0);

  const mine = documents.filter((d) => d.poll_id === pollId);

  const onFiles = async (files: FileList | null) => {
    if (!files?.length || !societyId) return;
    setUploading(true);
    let ok = 0;
    for (let i = 0; i < files.length; i++) {
      const file = files[i];
      const row = await uploadPollDocument({
        societyId,
        pollId,
        file,
        title: title.trim() || file.name.replace(/\.[^.]+$/, ''),
        docKind,
        createdBy,
        sortOrder: mine.length + i,
      });
      if (row) ok += 1;
    }
    setUploading(false);
    setTitle('');
    if (inputRef.current) inputRef.current.value = '';
    if (ok) {
      toast.success(`${ok} document(s) added`);
      setOpen(true);
      onChanged();
    } else toast.error('Could not upload document(s)');
  };

  const remove = async (doc: PollDocumentRow) => {
    const ok = await confirmAction('Remove document?', doc.title, 'Remove', 'Cancel');
    if (!ok) return;
    const err = await deletePollDocument(doc);
    if (err) toast.error(err);
    else {
      toast.success('Document removed');
      onChanged();
    }
  };

  return (
    <div className="mt-3 border-t border-border pt-3">
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        className="flex items-center gap-1.5 text-xs font-medium text-foreground"
      >
        <FileText className="w-3.5 h-3.5 text-primary" />
        Documents {mine.length > 0 ? `(${mine.length})` : ''}
        <span className="text-muted-foreground font-normal">{open ? '▾' : '▸'}</span>
      </button>

      {open && (
        <div className="mt-2 space-y-2">
          {mine.length === 0 && (
            <p className="text-[11px] text-muted-foreground">
              {isAdmin
                ? 'Attach circulars, letters, or other documents members can open with this poll.'
                : 'No documents attached.'}
            </p>
          )}
          <ul className="space-y-1.5">
            {mine.map((doc) => (
              <li key={doc.id} className="flex items-start gap-2 text-sm">
                <a
                  href={doc.file_url}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="flex-1 min-w-0 text-primary hover:underline flex items-center gap-1"
                >
                  <ExternalLink className="w-3 h-3 shrink-0" />
                  <span className="truncate">{doc.title}</span>
                  <span className="text-[10px] text-muted-foreground shrink-0">
                    · {POLL_DOC_KIND_LABELS[doc.doc_kind as PollDocKind] ?? doc.doc_kind}
                  </span>
                </a>
                {isAdmin && (
                  <button type="button" onClick={() => void remove(doc)} className="text-destructive shrink-0" aria-label="Remove">
                    <Trash2 className="w-3.5 h-3.5" />
                  </button>
                )}
              </li>
            ))}
          </ul>

          {isAdmin && societyId && (
            <div className="rounded-lg border border-dashed border-border p-2 space-y-2">
              <div className="grid grid-cols-2 gap-2">
                <div>
                  <label className="text-[10px] text-muted-foreground">Type</label>
                  <select
                    className="input-field mt-0.5 text-sm py-1"
                    value={docKind}
                    onChange={(e) => setDocKind(e.target.value as PollDocKind)}
                  >
                    {KIND_OPTIONS.map(([k, label]) => (
                      <option key={k} value={k}>
                        {label}
                      </option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className="text-[10px] text-muted-foreground">Title (optional)</label>
                  <input
                    className="input-field mt-0.5 text-sm py-1"
                    placeholder="e.g. Election circular"
                    value={title}
                    onChange={(e) => setTitle(e.target.value)}
                  />
                </div>
              </div>
              <input
                ref={inputRef}
                type="file"
                multiple
                accept="image/*,.pdf,.doc,.docx,.txt"
                className="hidden"
                onChange={(e) => void onFiles(e.target.files)}
              />
              <button
                type="button"
                disabled={uploading}
                onClick={() => inputRef.current?.click()}
                className="text-xs px-3 py-1.5 rounded-lg border border-primary/40 text-primary hover:bg-primary/10 inline-flex items-center gap-1"
              >
                <Paperclip className="w-3.5 h-3.5" />
                {uploading ? 'Uploading…' : 'Add document(s)'}
              </button>
            </div>
          )}
        </div>
      )}
    </div>
  );
};

export default PollDocumentsPanel;
