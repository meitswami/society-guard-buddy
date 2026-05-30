import { useState } from 'react';
import { Siren, Send, AlertTriangle, Paperclip, X } from 'lucide-react';
import { toast } from 'sonner';
import PhotoCapture from '@/components/PhotoCapture';
import { sendEmergencyAlert } from '@/lib/emergencyAlert';
import { confirmAction } from '@/lib/swal';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';

export type EmergencySenderRole = 'guard' | 'resident';

interface Props {
  societyId: string;
  senderName: string;
  senderRole: EmergencySenderRole;
  senderFlatNumber?: string;
  /** Compact mode for embedding above notification inbox */
  compact?: boolean;
}

const EmergencyAlertPanel = ({
  societyId,
  senderName,
  senderRole,
  senderFlatNumber,
  compact = false,
}: Props) => {
  const [open, setOpen] = useState(!compact);
  const [title, setTitle] = useState('🚨 EMERGENCY ALERT');
  const [message, setMessage] = useState('');
  const [photos, setPhotos] = useState<string[]>([]);
  const [pendingFiles, setPendingFiles] = useState<File[]>([]);
  const [sending, setSending] = useState(false);

  const onPickFiles = (list: FileList | null) => {
    if (!list?.length) return;
    const next = [...pendingFiles];
    for (let i = 0; i < list.length; i++) {
      const f = list.item(i);
      if (!f || !f.type.startsWith('image/')) continue;
      if (next.length + photos.length >= 4) break;
      next.push(f);
    }
    setPendingFiles(next);
  };

  const handleSend = async () => {
    if (!message.trim()) {
      toast.error('Describe the emergency so residents know what is happening');
      return;
    }

    const confirmed = await confirmAction(
      'Send emergency alert to ALL residents?',
      'This broadcasts to every resident portal, sends push alerts, and messages saved WhatsApp numbers. Use only for genuine emergencies.',
      'Yes, send now',
      'Cancel',
    );
    if (!confirmed) return;

    setSending(true);
    try {
      const result = await sendEmergencyAlert({
        societyId,
        title: title.trim() || '🚨 EMERGENCY ALERT',
        message: message.trim(),
        senderRole,
        senderName,
        senderFlatNumber,
        files: pendingFiles,
        photoDataUrls: photos,
      });

      if (!result.success) {
        toast.error(result.error ?? 'Failed to send emergency alert');
        return;
      }

      const waPart = result.whatsapp_configured
        ? ` · WhatsApp: ${result.whatsapp_sent ?? 0}/${result.whatsapp_recipients ?? 0}`
        : ' · WhatsApp: configure WHATSAPP_* secrets to enable';
      toast.success(`Emergency alert sent · Push: ${result.push_sent ?? 0}${waPart}`);

      setMessage('');
      setPhotos([]);
      setPendingFiles([]);
      setTitle('🚨 EMERGENCY ALERT');
      if (compact) setOpen(false);
    } finally {
      setSending(false);
    }
  };

  const formBody = (
    <div className="flex flex-col gap-3">
      <div className="rounded-lg border border-destructive/40 bg-destructive/5 p-3">
        <p className="text-xs text-destructive font-medium flex items-center gap-1.5">
          <AlertTriangle className="h-4 w-4 shrink-0" />
          Society-wide broadcast — all resident portals, push alerts, and saved WhatsApp numbers
        </p>
      </div>
      <input
        className="input-field"
        placeholder="Alert title"
        value={title}
        onChange={(e) => setTitle(e.target.value)}
      />
      <textarea
        className="input-field min-h-[88px]"
        placeholder="What happened? Where? What should residents do?"
        value={message}
        onChange={(e) => setMessage(e.target.value)}
      />
      <div>
        <p className="text-xs font-medium text-muted-foreground mb-2">Photo evidence (optional, up to 4)</p>
        <PhotoCapture photos={photos} onChange={setPhotos} maxPhotos={4} label="Take photo" />
        <div className="mt-2 flex flex-wrap items-center gap-2">
          <label className="inline-flex cursor-pointer items-center gap-2 rounded-lg border border-border bg-muted/40 px-3 py-2 text-xs font-medium hover:bg-muted">
            <Paperclip className="h-4 w-4" />
            Add image file
            <input
              type="file"
              accept="image/*"
              multiple
              className="hidden"
              onChange={(e) => {
                onPickFiles(e.target.files);
                e.target.value = '';
              }}
            />
          </label>
          {pendingFiles.map((f, i) => (
            <span
              key={`${f.name}-${i}`}
              className="inline-flex items-center gap-1 rounded-full bg-primary/10 px-2 py-1 text-[10px] text-primary"
            >
              {f.name.slice(0, 16)}
              <button
                type="button"
                className="rounded p-0.5 hover:bg-primary/20"
                onClick={() => setPendingFiles((prev) => prev.filter((_, j) => j !== i))}
                aria-label="Remove"
              >
                <X className="h-3 w-3" />
              </button>
            </span>
          ))}
        </div>
      </div>
      <button
        type="button"
        onClick={() => void handleSend()}
        disabled={sending}
        className="w-full py-3 rounded-xl bg-destructive text-destructive-foreground font-semibold flex items-center justify-center gap-2 hover:opacity-90 disabled:opacity-60"
      >
        <Send className="h-4 w-4" />
        {sending ? 'Sending to all residents…' : 'Send emergency alert now'}
      </button>
    </div>
  );

  if (compact) {
    return (
      <>
        <button
          type="button"
          onClick={() => setOpen(true)}
          className="w-full mb-4 py-3 rounded-xl bg-destructive/10 border-2 border-destructive/50 text-destructive font-semibold flex items-center justify-center gap-2 hover:bg-destructive/15 transition-colors"
        >
          <Siren className="h-5 w-5 animate-pulse" />
          Emergency or Alert — notify everyone
        </button>
        <Dialog open={open} onOpenChange={setOpen}>
          <DialogContent className="max-w-md max-h-[90vh] overflow-y-auto">
            <DialogHeader>
              <DialogTitle className="flex items-center gap-2 text-destructive">
                <Siren className="h-5 w-5" />
                Emergency / Alert mode
              </DialogTitle>
              <DialogDescription>
                Send a picture and message to all resident portals and saved WhatsApp numbers at once.
              </DialogDescription>
            </DialogHeader>
            {formBody}
          </DialogContent>
        </Dialog>
      </>
    );
  }

  return (
    <div className="page-container pb-24">
      <div className="flex items-center gap-3 mb-4">
        <div className="w-12 h-12 rounded-xl bg-destructive/10 flex items-center justify-center">
          <Siren className="w-6 h-6 text-destructive animate-pulse" />
        </div>
        <div>
          <h1 className="page-title text-destructive">Emergency / Alert</h1>
          <p className="text-xs text-muted-foreground">Notify all residents immediately</p>
        </div>
      </div>
      <div className="card-section p-4">{formBody}</div>
    </div>
  );
};

export default EmergencyAlertPanel;
