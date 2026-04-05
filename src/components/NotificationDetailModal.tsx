import { useState, useEffect, useCallback, useRef } from 'react';
import { supabase } from '@/integrations/supabase/client';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { ChevronLeft, ChevronRight, Send, Film } from 'lucide-react';
import { toast } from 'sonner';
import type { Tables, TablesInsert } from '@/integrations/supabase/types';

export type NotificationMediaItem = { url: string; kind: 'image' | 'video' };

export function parseNotificationMedia(raw: unknown): NotificationMediaItem[] {
  if (!raw || !Array.isArray(raw)) return [];
  return raw
    .filter(
      (x): x is NotificationMediaItem =>
        typeof x === 'object' &&
        x !== null &&
        'url' in x &&
        typeof (x as { url: unknown }).url === 'string' &&
        ((x as { kind?: string }).kind === 'image' || (x as { kind?: string }).kind === 'video')
    )
    .map(x => ({ url: (x as NotificationMediaItem).url, kind: (x as NotificationMediaItem).kind }));
}

type CommentRow = Tables<'notification_comments'>;

type NotifRow = Tables<'notifications'>;

interface ResidentRef {
  id: string;
  name: string;
  flatNumber: string;
}

interface Props {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  notification: NotifRow | null;
  isResident: boolean;
  resident?: ResidentRef;
  adminName?: string;
}

const NotificationDetailModal = ({
  open,
  onOpenChange,
  notification,
  isResident,
  resident,
  adminName = 'Admin',
}: Props) => {
  const [mediaIndex, setMediaIndex] = useState(0);
  const [comments, setComments] = useState<CommentRow[]>([]);
  const [draft, setDraft] = useState('');
  const [sending, setSending] = useState(false);
  const scrollRef = useRef<HTMLDivElement>(null);

  const media = notification ? parseNotificationMedia(notification.media_items) : [];
  const nid = notification?.id;

  const loadComments = useCallback(async () => {
    if (!nid) return;
    const { data, error } = await supabase
      .from('notification_comments')
      .select('*')
      .eq('notification_id', nid)
      .order('created_at', { ascending: true });
    if (error) return;
    if (data) setComments(data);
  }, [nid]);

  useEffect(() => {
    if (!open || !nid) return;
    setMediaIndex(0);
    void loadComments();

    const ch = supabase
      .channel(`notif-comments-${nid}`)
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'notification_comments', filter: `notification_id=eq.${nid}` },
        () => {
          void loadComments();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(ch);
    };
  }, [open, nid, loadComments]);

  useEffect(() => {
    if (!open) setDraft('');
  }, [open]);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (!open || media.length === 0) return;
      if (e.key === 'ArrowLeft') {
        e.preventDefault();
        setMediaIndex(i => (i - 1 + media.length) % media.length);
      }
      if (e.key === 'ArrowRight') {
        e.preventDefault();
        setMediaIndex(i => (i + 1) % media.length);
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [open, media.length]);

  const sendComment = async () => {
    const text = draft.trim();
    if (!text || !nid) return;
    if (isResident && !resident) {
      toast.error('Not signed in as resident');
      return;
    }
    setSending(true);
    const row: TablesInsert<'notification_comments'> = isResident
      ? {
          notification_id: nid,
          author_role: 'resident',
          author_resident_id: resident!.id,
          author_name: resident!.name,
          author_flat_number: resident!.flatNumber,
          body: text,
        }
      : {
          notification_id: nid,
          author_role: 'admin',
          author_resident_id: null,
          author_name: adminName,
          author_flat_number: null,
          body: text,
        };
    const { error } = await supabase.from('notification_comments').insert(row);
    setSending(false);
    if (error) {
      toast.error('Could not send message');
      return;
    }
    setDraft('');
    void loadComments();
    setTimeout(() => scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight, behavior: 'smooth' }), 100);
  };

  if (!notification) return null;

  const current = media[mediaIndex];

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="flex max-h-[92vh] w-[calc(100vw-1rem)] max-w-3xl flex-col gap-0 overflow-hidden p-0 sm:max-w-3xl">
        <DialogHeader className="border-b border-border px-4 py-3 text-left">
          <DialogTitle className="pr-8 text-base leading-snug">{notification.title}</DialogTitle>
          <p className="text-xs text-muted-foreground">{new Date(notification.created_at).toLocaleString()}</p>
        </DialogHeader>

        <div className="flex min-h-0 flex-1 flex-col">
          <div className="shrink-0 border-b border-border px-4 py-2">
            <p className="text-sm text-muted-foreground whitespace-pre-wrap">{notification.message}</p>
          </div>

          {media.length > 0 && (
            <div className="relative shrink-0 border-b border-border bg-black">
              <div className="relative flex aspect-video max-h-[38vh] w-full items-center justify-center">
                {current?.kind === 'image' && (
                  <img src={current.url} alt="" className="max-h-[38vh] w-full object-contain" />
                )}
                {current?.kind === 'video' && (
                  <video
                    key={current.url}
                    src={current.url}
                    className="max-h-[38vh] w-full object-contain"
                    controls
                    playsInline
                  />
                )}
              </div>
              {media.length > 1 && (
                <>
                  <Button
                    type="button"
                    variant="secondary"
                    size="icon"
                    className="absolute left-2 top-1/2 h-9 w-9 -translate-y-1/2 rounded-full bg-background/90 shadow"
                    onClick={() => setMediaIndex(i => (i - 1 + media.length) % media.length)}
                    aria-label="Previous"
                  >
                    <ChevronLeft className="h-5 w-5" />
                  </Button>
                  <Button
                    type="button"
                    variant="secondary"
                    size="icon"
                    className="absolute right-2 top-1/2 h-9 w-9 -translate-y-1/2 rounded-full bg-background/90 shadow"
                    onClick={() => setMediaIndex(i => (i + 1) % media.length)}
                    aria-label="Next"
                  >
                    <ChevronRight className="h-5 w-5" />
                  </Button>
                  <div className="absolute bottom-2 left-1/2 -translate-x-1/2 rounded-full bg-background/80 px-3 py-1 text-xs text-foreground">
                    {mediaIndex + 1} / {media.length}
                  </div>
                </>
              )}
            </div>
          )}

          <div className="flex min-h-0 flex-1 flex-col">
            <p className="shrink-0 border-b border-border bg-muted/40 px-4 py-2 text-xs font-medium text-muted-foreground">
              Discussion · stay on this thread instead of WhatsApp
            </p>
            <div
              ref={scrollRef}
              className="min-h-[140px] max-h-[220px] flex-1 overflow-y-auto px-4"
            >
              <div className="space-y-3 py-3 pr-2">
                {comments.length === 0 && (
                  <p className="text-center text-xs text-muted-foreground">No messages yet. Start the conversation.</p>
                )}
                {comments.map(c => (
                  <div
                    key={c.id}
                    className={`flex flex-col rounded-xl px-3 py-2 text-sm ${
                      c.author_role === 'admin' ? 'ml-4 bg-primary/10' : 'mr-4 bg-muted'
                    }`}
                  >
                    <div className="mb-0.5 flex flex-wrap items-baseline gap-2">
                      <span className="font-semibold text-foreground">{c.author_name}</span>
                      {c.author_flat_number && (
                        <span className="text-[10px] text-muted-foreground">Flat {c.author_flat_number}</span>
                      )}
                      {c.author_role === 'admin' && (
                        <span className="text-[10px] font-medium text-primary">Admin</span>
                      )}
                    </div>
                    <p className="whitespace-pre-wrap text-foreground/90">{c.body}</p>
                    <span className="mt-1 text-[10px] text-muted-foreground">
                      {new Date(c.created_at).toLocaleString()}
                    </span>
                  </div>
                ))}
              </div>
            </div>

            <div className="shrink-0 border-t border-border p-3">
              <div className="flex gap-2">
                <textarea
                  className="input-field min-h-[44px] flex-1 resize-none py-2.5 text-sm"
                  placeholder={isResident ? 'Message as your flat…' : 'Reply as admin…'}
                  rows={2}
                  value={draft}
                  onChange={e => setDraft(e.target.value)}
                  onKeyDown={e => {
                    if (e.key === 'Enter' && !e.shiftKey) {
                      e.preventDefault();
                      void sendComment();
                    }
                  }}
                />
                <Button
                  type="button"
                  className="shrink-0 self-end"
                  size="icon"
                  disabled={sending || !draft.trim()}
                  onClick={() => void sendComment()}
                  aria-label="Send"
                >
                  <Send className="h-4 w-4" />
                </Button>
              </div>
            </div>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
};

export { NotificationDetailModal };
export function NotificationMediaBadges({ count }: { count: number }) {
  if (count <= 0) return null;
  return (
    <span className="inline-flex items-center gap-1 rounded border border-primary/30 bg-primary/5 px-1.5 py-0.5 text-[10px] text-primary">
      <Film className="h-3 w-3" />
      {count} attachment{count === 1 ? '' : 's'}
    </span>
  );
}
