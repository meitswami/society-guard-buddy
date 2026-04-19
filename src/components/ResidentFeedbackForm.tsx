import { useState, useRef, useCallback } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { toast } from 'sonner';
import { Mic, Square, Send, Paperclip, X, MessageSquarePlus } from 'lucide-react';

type MediaItem = { url: string; kind: 'image' | 'video' };

interface Props {
  resident: { id: string; name: string; flatNumber: string };
  societyId: string | null;
}

const MAX_ATTACHMENTS = 6;
const MAX_IMAGE_BYTES = 12 * 1024 * 1024;
const MAX_VIDEO_BYTES = 50 * 1024 * 1024;
const MAX_AUDIO_BYTES = 15 * 1024 * 1024;

function fileMediaKind(file: File): 'image' | 'video' | null {
  if (file.type.startsWith('image/')) return 'image';
  if (file.type.startsWith('video/')) return 'video';
  return null;
}

async function uploadFiles(files: File[], subfolder: string): Promise<MediaItem[]> {
  const items: MediaItem[] = [];
  for (const file of files) {
    const kind = fileMediaKind(file);
    if (!kind) continue;
    if (kind === 'image' && file.size > MAX_IMAGE_BYTES) {
      toast.error(`Image too large (max 12MB): ${file.name}`);
      continue;
    }
    if (kind === 'video' && file.size > MAX_VIDEO_BYTES) {
      toast.error(`Video too large (max 50MB): ${file.name}`);
      continue;
    }
    const safe = file.name.replace(/[^\w.-]/g, '_');
    const path = `feedback/${subfolder}/${crypto.randomUUID()}_${Date.now()}_${safe}`;
    const { error } = await supabase.storage.from('notification-media').upload(path, file, {
      cacheControl: '3600',
      upsert: false,
    });
    if (error) {
      toast.error(`Upload failed: ${file.name}`);
      continue;
    }
    const { data: pub } = supabase.storage.from('notification-media').getPublicUrl(path);
    items.push({ url: pub.publicUrl, kind });
  }
  return items;
}

async function uploadAudioBlob(blob: Blob, subfolder: string): Promise<string | null> {
  if (blob.size > MAX_AUDIO_BYTES) {
    toast.error('Recording is too long or too large (max 15MB)');
    return null;
  }
  const ext = blob.type.includes('mp4') ? 'm4a' : 'webm';
  const path = `feedback/${subfolder}/voice_${Date.now()}.${ext}`;
  const { error } = await supabase.storage.from('notification-media').upload(path, blob, {
    cacheControl: '3600',
    upsert: false,
    contentType: blob.type || 'audio/webm',
  });
  if (error) {
    toast.error(error.message);
    return null;
  }
  const { data: pub } = supabase.storage.from('notification-media').getPublicUrl(path);
  return pub.publicUrl;
}

const ResidentFeedbackForm = ({ resident, societyId }: Props) => {
  const [message, setMessage] = useState('');
  const [pendingFiles, setPendingFiles] = useState<File[]>([]);
  const [submitting, setSubmitting] = useState(false);
  const [recording, setRecording] = useState(false);
  const [recordedBlob, setRecordedBlob] = useState<Blob | null>(null);
  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const chunksRef = useRef<BlobPart[]>([]);

  const stopRecording = useCallback(() => {
    const mr = mediaRecorderRef.current;
    if (mr && mr.state !== 'inactive') {
      mr.stop();
    }
    mediaRecorderRef.current = null;
    setRecording(false);
  }, []);

  const startRecording = async () => {
    if (!navigator.mediaDevices?.getUserMedia) {
      toast.error('Microphone is not supported in this browser');
      return;
    }
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      chunksRef.current = [];
      const preferred = MediaRecorder.isTypeSupported('audio/webm') ? 'audio/webm' : undefined;
      const mr = preferred ? new MediaRecorder(stream, { mimeType: preferred }) : new MediaRecorder(stream);
      mediaRecorderRef.current = mr;
      mr.ondataavailable = (e) => {
        if (e.data.size) chunksRef.current.push(e.data);
      };
      mr.onstop = () => {
        stream.getTracks().forEach((t) => t.stop());
        const blob = new Blob(chunksRef.current, { type: mr.mimeType || 'audio/webm' });
        setRecordedBlob(blob);
        chunksRef.current = [];
      };
      mr.start();
      setRecording(true);
    } catch {
      toast.error('Could not access microphone');
    }
  };

  const onPickFiles = (list: FileList | null) => {
    if (!list?.length) return;
    const next: File[] = [...pendingFiles];
    for (let i = 0; i < list.length; i++) {
      const f = list.item(i);
      if (!f) continue;
      if (!fileMediaKind(f)) {
        toast.error(`${f.name}: use an image or video`);
        continue;
      }
      if (next.length >= MAX_ATTACHMENTS) {
        toast.error(`Maximum ${MAX_ATTACHMENTS} files`);
        break;
      }
      next.push(f);
    }
    setPendingFiles(next);
  };

  const submit = async () => {
    const text = message.trim();
    if (!societyId) {
      toast.error('Society is not loaded. Try again in a moment.');
      return;
    }
    if (!text && pendingFiles.length === 0 && !recordedBlob) {
      toast.error('Add a message, voice note, or at least one image/video');
      return;
    }

    setSubmitting(true);
    const sub = resident.id;
    try {
      const { data: soc, error: socErr } = await supabase.from('societies').select('name').eq('id', societyId).maybeSingle();
      if (socErr) {
        toast.error(socErr.message);
        setSubmitting(false);
        return;
      }
      const societyName = soc?.name?.trim() ?? '';

      let mediaItems: MediaItem[] = [];
      if (pendingFiles.length > 0) {
        mediaItems = await uploadFiles(pendingFiles, sub);
      }

      let audioUrl: string | null = null;
      if (recordedBlob) {
        audioUrl = await uploadAudioBlob(recordedBlob, sub);
        if (!audioUrl && !text && mediaItems.length === 0) {
          setSubmitting(false);
          return;
        }
      }

      const { data: inserted, error: insErr } = await supabase
        .from('support_tickets')
        .insert({
          society_id: societyId,
          society_name: societyName,
          submitter_kind: 'resident',
          submitter_resident_id: resident.id,
          submitter_name: resident.name,
          flat_number: resident.flatNumber,
          message: text || '(voice / attachments only)',
          media_items: mediaItems,
          audio_url: audioUrl,
        })
        .select('id')
        .single();

      if (insErr || !inserted?.id) {
        toast.error(insErr?.message ?? 'Could not submit feedback');
        setSubmitting(false);
        return;
      }

      try {
        await supabase.functions.invoke('send-feedback-alert', { body: { ticket_id: inserted.id } });
      } catch (e) {
        console.warn('Feedback email invoke:', e);
      }

      toast.success('Thanks! Your feedback was sent to support.');
      setMessage('');
      setPendingFiles([]);
      setRecordedBlob(null);
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="page-container pb-24 flex flex-col gap-4">
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
          <MessageSquarePlus className="w-5 h-5 text-primary" />
        </div>
        <div>
          <h1 className="page-title">Feedback</h1>
          <p className="text-xs text-muted-foreground">
            Report bugs or ideas. Include details — the developer gets your flat, name, and society automatically.
          </p>
        </div>
      </div>

      <div className="card-section p-4 flex flex-col gap-3">
        <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider">Message (optional if you send voice or media)</label>
        <textarea
          className="input-field min-h-[120px]"
          placeholder="Describe what happened or what you would like…"
          value={message}
          onChange={(e) => setMessage(e.target.value)}
        />

        <div className="flex flex-wrap gap-2 items-center">
          {!recording ? (
            <button
              type="button"
              className="inline-flex items-center gap-2 px-3 py-2 rounded-lg border border-border text-sm font-medium"
              onClick={() => void startRecording()}
              disabled={submitting}
            >
              <Mic className="w-4 h-4" /> Record voice
            </button>
          ) : (
            <button
              type="button"
              className="inline-flex items-center gap-2 px-3 py-2 rounded-lg bg-destructive/15 text-destructive text-sm font-medium"
              onClick={stopRecording}
            >
              <Square className="w-4 h-4" /> Stop
            </button>
          )}
          {recordedBlob && !recording && (
            <span className="text-xs text-muted-foreground">
              Voice note ready ({Math.round(recordedBlob.size / 1024)} KB)
              <button type="button" className="ml-2 text-destructive underline" onClick={() => setRecordedBlob(null)}>
                Remove
              </button>
            </span>
          )}
        </div>

        <div>
          <label className="btn-secondary inline-flex items-center justify-center gap-2 cursor-pointer text-sm py-2 px-3 w-fit">
            <Paperclip className="w-4 h-4" /> Photos / videos
            <input
              type="file"
              accept="image/*,video/*"
              multiple
              className="hidden"
              onChange={(e) => {
                onPickFiles(e.target.files);
                e.target.value = '';
              }}
            />
          </label>
          {pendingFiles.length > 0 && (
            <ul className="mt-2 space-y-1 text-xs text-muted-foreground">
              {pendingFiles.map((f, i) => (
                <li key={`${f.name}-${i}`} className="flex items-center justify-between gap-2">
                  <span className="truncate">{f.name}</span>
                  <button type="button" className="text-destructive shrink-0 p-1" onClick={() => setPendingFiles(pendingFiles.filter((_, j) => j !== i))}>
                    <X className="w-3.5 h-3.5" />
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>

        <button type="button" className="btn-primary w-full flex items-center justify-center gap-2" disabled={submitting} onClick={() => void submit()}>
          <Send className="w-4 h-4" />
          {submitting ? 'Sending…' : 'Send feedback'}
        </button>
      </div>
    </div>
  );
};

export default ResidentFeedbackForm;
