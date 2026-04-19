import { useEffect, useState, useCallback } from 'react';
import { supabase } from '@/integrations/supabase/client';
import type { Tables } from '@/integrations/supabase/types';
import { toast } from 'sonner';
import { Headphones, ExternalLink } from 'lucide-react';

interface Props {
  superadmin: { id: string; name: string };
}

type Ticket = Tables<'support_tickets'>;

type MediaItem = { url?: string; kind?: string };

function parseMedia(raw: unknown): MediaItem[] {
  if (!Array.isArray(raw)) return [];
  return raw.filter((x) => x && typeof x === 'object' && 'url' in x) as MediaItem[];
}

const STATUS_OPTIONS = [
  { value: 'pending', label: 'Pending' },
  { value: 'resolved', label: 'Resolved' },
  { value: 'future_update', label: 'Future update' },
] as const;

const SuperadminSupportTickets = ({ superadmin }: Props) => {
  const [tickets, setTickets] = useState<Ticket[]>([]);
  const [loading, setLoading] = useState(true);
  const [replyById, setReplyById] = useState<Record<string, string>>({});
  const [sendingId, setSendingId] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    const { data, error } = await supabase
      .from('support_tickets')
      .select('*')
      .order('ticket_number', { ascending: false });
    setLoading(false);
    if (error) {
      toast.error(error.message);
      return;
    }
    setTickets((data ?? []) as Ticket[]);
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const setStatus = async (id: string, status: string) => {
    const { error } = await supabase.from('support_tickets').update({ status }).eq('id', id);
    if (error) {
      toast.error(error.message);
      return;
    }
    toast.success('Status updated');
    void load();
  };

  const sendReply = async (t: Ticket) => {
    const body = (replyById[t.id] ?? '').trim();
    if (!body) {
      toast.error('Enter a reply message');
      return;
    }
    if (!t.society_id || !t.submitter_resident_id) {
      toast.error('Ticket is missing society or submitter');
      return;
    }
    setSendingId(t.id);
    try {
      const { error: upErr } = await supabase
        .from('support_tickets')
        .update({
          superadmin_reply: body,
          replied_at: new Date().toISOString(),
          replied_by_superadmin_id: superadmin.id,
        })
        .eq('id', t.id);
      if (upErr) {
        toast.error(upErr.message);
        return;
      }

      const title = `Support · Ticket #${t.ticket_number}`;
      const { error: nErr } = await supabase.from('notifications').insert({
        society_id: t.society_id,
        title,
        message: body,
        type: 'support',
        target_type: 'user',
        target_id: t.submitter_resident_id,
        created_by: `Superadmin (${superadmin.name})`,
        media_items: [],
        sound_key: 'digital',
        sound_custom_url: null,
      });
      if (nErr) {
        toast.error(nErr.message);
        return;
      }

      try {
        await supabase.functions.invoke('send-push-notification', {
          body: {
            title,
            message: body.slice(0, 180),
            target_type: 'user',
            target_ids: [t.submitter_resident_id],
            society_id: t.society_id,
            sound_key: 'digital',
            sound_custom_url: '',
          },
        });
      } catch (e) {
        console.warn('Push invoke:', e);
      }

      toast.success('Reply sent (in-app + push to that resident)');
      setReplyById((m) => ({ ...m, [t.id]: '' }));
      void load();
    } finally {
      setSendingId(null);
    }
  };

  return (
    <div>
      <div className="flex items-center gap-2 mb-4">
        <Headphones className="w-5 h-5 text-primary" />
        <h2 className="font-semibold">Support tickets</h2>
        <button type="button" className="text-xs text-primary underline ml-auto" onClick={() => void load()}>
          Refresh
        </button>
      </div>
      <p className="text-xs text-muted-foreground mb-4">
        New resident feedback appears here with ticket numbers #1, #2, … Email alerts go to the configured developer inbox when Resend is set on the Edge Function.
      </p>

      {loading && <p className="text-sm text-muted-foreground">Loading…</p>}
      {!loading && tickets.length === 0 && (
        <p className="text-sm text-muted-foreground text-center py-8">No tickets yet.</p>
      )}

      <div className="space-y-4">
        {tickets.map((t) => {
          const media = parseMedia(t.media_items);
          return (
            <div key={t.id} className="card-section p-4 space-y-3">
              <div className="flex flex-wrap items-start justify-between gap-2">
                <div>
                  <p className="font-semibold text-foreground">#{t.ticket_number}</p>
                  <p className="text-xs text-muted-foreground">
                    {t.society_name ?? '—'} · Flat {t.flat_number} · {t.submitter_name}
                  </p>
                  <p className="text-[10px] text-muted-foreground font-mono mt-0.5">{new Date(t.created_at).toLocaleString()}</p>
                </div>
                <label className="text-xs flex flex-col gap-1">
                  <span className="text-muted-foreground">Status</span>
                  <select
                    className="input-field text-xs py-1.5 min-w-[140px]"
                    value={t.status}
                    onChange={(e) => void setStatus(t.id, e.target.value)}
                  >
                    {STATUS_OPTIONS.map((o) => (
                      <option key={o.value} value={o.value}>
                        {o.label}
                      </option>
                    ))}
                  </select>
                </label>
              </div>

              <div>
                <p className="text-[10px] uppercase tracking-wider text-muted-foreground font-medium mb-1">Message</p>
                <p className="text-sm whitespace-pre-wrap">{t.message}</p>
              </div>

              {t.audio_url && (
                <div>
                  <p className="text-[10px] uppercase text-muted-foreground font-medium mb-1">Voice</p>
                  <audio controls src={t.audio_url} className="w-full max-w-md" />
                </div>
              )}

              {media.length > 0 && (
                <div>
                  <p className="text-[10px] uppercase text-muted-foreground font-medium mb-1">Media</p>
                  <ul className="text-xs space-y-1">
                    {media.map((m, i) => (
                      <li key={i}>
                        <a href={m.url} target="_blank" rel="noreferrer" className="text-primary inline-flex items-center gap-1">
                          {m.kind ?? 'file'} <ExternalLink className="w-3 h-3" />
                        </a>
                      </li>
                    ))}
                  </ul>
                </div>
              )}

              {t.superadmin_reply && (
                <div className="rounded-lg bg-secondary/40 p-3 text-xs">
                  <p className="font-medium text-muted-foreground mb-1">Last reply</p>
                  <p className="whitespace-pre-wrap">{t.superadmin_reply}</p>
                  {t.replied_at && (
                    <p className="text-[10px] text-muted-foreground mt-1">{new Date(t.replied_at).toLocaleString()}</p>
                  )}
                </div>
              )}

              <div className="border-t border-border pt-3 space-y-2">
                <label className="text-xs text-muted-foreground">Reply to resident (push + in-app)</label>
                <textarea
                  className="input-field text-sm min-h-[80px]"
                  placeholder="Your reply…"
                  value={replyById[t.id] ?? ''}
                  onChange={(e) => setReplyById((m) => ({ ...m, [t.id]: e.target.value }))}
                />
                <button
                  type="button"
                  className="btn-primary text-sm"
                  disabled={sendingId === t.id}
                  onClick={() => void sendReply(t)}
                >
                  {sendingId === t.id ? 'Sending…' : 'Send reply'}
                </button>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
};

export default SuperadminSupportTickets;
