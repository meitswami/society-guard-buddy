import { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { Bell, Plus, Send, Users, User, Home, Paperclip, X } from 'lucide-react';
import { toast } from 'sonner';
import {
  NotificationDetailModal,
  parseNotificationMedia,
  NotificationMediaBadges,
  type NotificationMediaItem,
} from '@/components/NotificationDetailModal';
import { FlatMultiSelect } from '@/components/FlatMultiSelect';
import { flatOptionsWithPrimaryLabel } from '@/lib/flatMultiSelectOptions';
import type { Tables } from '@/integrations/supabase/types';
import { isFcmWebPushConfigured, registerFcmWebUser } from '@/lib/fcmWeb';
import { isSupported as isFcmSupported } from 'firebase/messaging';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';

interface ResidentRef {
  id: string;
  name: string;
  flatNumber: string;
}

interface Props {
  adminName?: string;
  adminId?: string;
  isResident?: boolean;
  flatNumber?: string;
  resident?: ResidentRef;
  /** When set, FCM sends only to tokens registered for this society */
  societyId?: string | null;
  /** Bumps when a new notification row is inserted (dashboard-level Realtime). Refreshes list even when this tab is closed. */
  feedRevision?: number;
}

type TargetMode = 'all' | 'flat' | 'user';
type HealthStep = { label: string; ok: boolean; detail: string };

const MAX_ATTACHMENTS = 8;
const MAX_IMAGE_BYTES = 12 * 1024 * 1024;
const MAX_VIDEO_BYTES = 50 * 1024 * 1024;

function fileMediaKind(file: File): 'image' | 'video' | null {
  if (file.type.startsWith('image/')) return 'image';
  if (file.type.startsWith('video/')) return 'video';
  return null;
}

async function uploadNotificationMedia(files: File[]): Promise<NotificationMediaItem[]> {
  const items: NotificationMediaItem[] = [];
  for (const file of files) {
    const kind = fileMediaKind(file);
    if (!kind) continue;
    if (kind === 'image' && file.size > MAX_IMAGE_BYTES) {
      toast.error(`Image too large (max ${MAX_IMAGE_BYTES / 1024 / 1024}MB): ${file.name}`);
      continue;
    }
    if (kind === 'video' && file.size > MAX_VIDEO_BYTES) {
      toast.error(`Video too large (max ${MAX_VIDEO_BYTES / 1024 / 1024}MB): ${file.name}`);
      continue;
    }
    const safe = file.name.replace(/[^\w.-]/g, '_');
    const path = `${crypto.randomUUID()}/${Date.now()}_${safe}`;
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

const NotificationCenter = ({
  adminName = 'Admin',
  adminId,
  isResident = false,
  flatNumber = '',
  resident,
  societyId = null,
  feedRevision = 0,
}: Props) => {
  const [notifications, setNotifications] = useState<Tables<'notifications'>[]>([]);
  const [showForm, setShowForm] = useState(false);
  const [nf, setNf] = useState({ title: '', message: '', type: 'general' });
  const [targetMode, setTargetMode] = useState<TargetMode>('all');
  const [selectedFlats, setSelectedFlats] = useState<string[]>([]);
  const [selectedResidents, setSelectedResidents] = useState<{ id: string; name: string; flatNumber: string }[]>([]);
  const [flats, setFlats] = useState<{ id: string; flat_number: string; owner_name: string | null }[]>([]);
  const [primaryByFlatId, setPrimaryByFlatId] = useState<Map<string, string>>(new Map());
  const [residents, setResidents] = useState<{ id: string; name: string; flat_number: string; flat_id: string }[]>([]);
  const [sending, setSending] = useState(false);
  const [pendingFiles, setPendingFiles] = useState<File[]>([]);
  const [detailOpen, setDetailOpen] = useState(false);
  const [activeNotification, setActiveNotification] = useState<Tables<'notifications'> | null>(null);
  const [checkingPushHealth, setCheckingPushHealth] = useState(false);
  const [healthOpen, setHealthOpen] = useState(false);
  const [healthSteps, setHealthSteps] = useState<HealthStep[]>([]);
  const [healthSummary, setHealthSummary] = useState('');

  const loadNotifications = useCallback(async () => {
    let query = supabase.from('notifications').select('*').order('created_at', { ascending: false }).limit(100);
    if (isResident) {
      query = query.or(`target_type.eq.all,target_id.eq.${flatNumber}`);
    }
    const { data } = await query;
    if (data) setNotifications(data as Tables<'notifications'>[]);
  }, [isResident, flatNumber]);

  useEffect(() => {
    loadNotifications();
    void (async () => {
      const [fRes, rRes, mRes] = await Promise.all([
        supabase.from('flats').select('id, flat_number, owner_name').order('flat_number'),
        supabase.from('resident_users').select('id, name, flat_number, flat_id').order('name'),
        supabase.from('members').select('flat_id, name').eq('is_primary', true),
      ]);
      if (fRes.data) setFlats(fRes.data);
      if (rRes.data) setResidents(rRes.data);
      const map = new Map<string, string>();
      for (const row of mRes.data ?? []) {
        if (row.flat_id && row.name?.trim()) map.set(row.flat_id, row.name.trim());
      }
      setPrimaryByFlatId(map);
    })();
  }, [loadNotifications]);

  useEffect(() => {
    if (feedRevision > 0) {
      void loadNotifications();
    }
  }, [feedRevision, loadNotifications]);

  const markRead = async (id: string) => {
    await supabase.from('notifications').update({ is_read: true }).eq('id', id);
    loadNotifications();
  };

  const openNotification = (n: Tables<'notifications'>) => {
    setActiveNotification(n);
    setDetailOpen(true);
    if (!n.is_read) void markRead(n.id);
  };

  const markAllRead = async () => {
    const ids = notifications.filter(n => !n.is_read).map(n => n.id);
    if (ids.length === 0) return;
    for (const id of ids) {
      await supabase.from('notifications').update({ is_read: true }).eq('id', id);
    }
    toast.success('All marked as read');
    loadNotifications();
  };

  const sendNotification = async () => {
    if (!nf.title || !nf.message) return;
    if (targetMode === 'flat' && selectedFlats.length === 0) {
      toast.error('Select at least one flat');
      return;
    }
    if (targetMode === 'user' && selectedResidents.length === 0) {
      toast.error('Select at least one resident');
      return;
    }
    setSending(true);

    let mediaItems: NotificationMediaItem[] = [];
    if (pendingFiles.length > 0) {
      try {
        mediaItems = await uploadNotificationMedia(pendingFiles);
      } catch {
        toast.error('Media upload failed');
        setSending(false);
        return;
      }
    }

    let targetType = 'all';
    let targetId: string | null = null;
    let targetFlatNumbers: string[] = [];
    let targetUserIds: string[] = [];

    if (targetMode === 'flat' && selectedFlats.length > 0) {
      targetType = 'flat';
      targetFlatNumbers = selectedFlats;
      targetId = selectedFlats.join(',');
    } else if (targetMode === 'user' && selectedResidents.length > 0) {
      targetType = 'user';
      targetUserIds = selectedResidents.map(r => r.id);
      targetId = selectedResidents.map(r => r.name).join(',');
    }

    const rowBase = {
      title: nf.title,
      message: nf.message,
      type: nf.type,
      created_by: adminName,
      media_items: mediaItems,
    };

    if (targetMode === 'flat') {
      for (const flat of selectedFlats) {
        await supabase.from('notifications').insert([
          {
            ...rowBase,
            target_type: 'flat',
            target_id: flat,
          },
        ]);
      }
    } else {
      await supabase.from('notifications').insert([
        {
          ...rowBase,
          target_type: targetType,
          target_id: targetId,
        },
      ]);
    }

    try {
      await supabase.functions.invoke('send-push-notification', {
        body: {
          title: nf.title,
          message: nf.message,
          target_type: targetMode,
          target_flat_numbers: targetFlatNumbers,
          target_ids: targetUserIds,
          media_items: mediaItems,
          society_id: societyId,
        },
      });
    } catch (e) {
      console.warn('Push notification failed (may not be configured):', e);
    }

    setNf({ title: '', message: '', type: 'general' });
    setShowForm(false);
    setSelectedFlats([]);
    setSelectedResidents([]);
    setTargetMode('all');
    setPendingFiles([]);
    setSending(false);
    toast.success('Notification sent with push alert!');
    loadNotifications();
  };

  const runPushHealthCheck = async () => {
    if (isResident) return;
    if (!adminId) {
      toast.error('Admin ID missing for health check');
      return;
    }
    setCheckingPushHealth(true);
    setHealthOpen(true);
    setHealthSteps([]);
    setHealthSummary('');
    const issues: string[] = [];
    const ok: string[] = [];
    let token: string | null = null;
    const steps: HealthStep[] = [];
    const step = (label: string, pass: boolean, detail: string) => {
      steps.push({ label, ok: pass, detail });
      setHealthSteps([...steps]);
    };

    try {
      if (!isFcmWebPushConfigured()) {
        issues.push('Env config: missing Firebase or VAPID key in frontend env');
        step('Environment', false, 'Missing Firebase or VAPID key in frontend env');
      } else {
        ok.push('Env config: Firebase + VAPID key present');
        step('Environment', true, 'Firebase + VAPID key found');
      }

      if (!(await isFcmSupported())) {
        issues.push('Browser support: Firebase messaging unsupported in this browser/context');
        step('Browser support', false, 'Firebase messaging unsupported in this browser/context');
      } else {
        ok.push('Browser support: supported');
        step('Browser support', true, 'Firebase messaging is supported');
      }

      if (typeof Notification !== 'undefined') {
        if (Notification.permission === 'denied') {
          issues.push('Permission: blocked in browser settings');
          step('Notification permission', false, 'Blocked in browser settings');
        } else if (Notification.permission === 'default') {
          issues.push('Permission: not granted yet (prompt not accepted)');
          step('Notification permission', false, 'Not granted yet (prompt not accepted)');
        } else {
          ok.push('Permission: granted');
          step('Notification permission', true, 'Granted');
        }
      }

      await registerFcmWebUser({
        userType: 'admin',
        userId: adminId,
        userName: adminName,
        societyId: societyId ?? null,
      });
      step('Token registration', true, 'Registration attempt completed');

      const tokenQuery = supabase
        .from('fcm_web_tokens')
        .select('token, updated_at')
        .eq('user_type', 'admin')
        .eq('app_user_id', adminId)
        .order('updated_at', { ascending: false })
        .limit(1);
      const { data: tokenRows, error: tokenErr } = societyId
        ? await tokenQuery.eq('society_id', societyId)
        : await tokenQuery;

      if (tokenErr) {
        issues.push(`Token DB: query failed (${tokenErr.message})`);
        step('Token in database', false, tokenErr.message);
      } else if (!tokenRows?.length) {
        issues.push('Token DB: no FCM token found for this admin/device');
        step('Token in database', false, 'No FCM token found for this admin/device');
      } else {
        token = tokenRows[0].token;
        ok.push('Token DB: token present');
        step('Token in database', true, 'Token found');
      }

      if (token) {
        const { data: pushData, error: pushErr } = await supabase.functions.invoke('send-push-notification', {
          body: {
            title: 'Push Health Check',
            message: `Test push from ${adminName} (${new Date().toLocaleTimeString()})`,
            target_tokens: [token],
            target_type: 'user',
            society_id: societyId,
          },
        });
        if (pushErr) {
          issues.push(`Edge function: invoke failed (${pushErr.message})`);
          step('Edge function invoke', false, pushErr.message);
        } else if ((pushData as any)?.error) {
          issues.push(`Edge secret/config: ${(pushData as any).error}`);
          step('Edge secret/config', false, (pushData as any).error);
        } else if ((pushData as any)?.channel === 'fcm' && Number((pushData as any)?.sent ?? 0) > 0) {
          ok.push('Delivery: accepted by FCM for this device token');
          step('Push delivery', true, 'Accepted by FCM for this device token');
        } else {
          issues.push(`Delivery: not confirmed (${JSON.stringify(pushData)})`);
          step('Push delivery', false, `Not confirmed: ${JSON.stringify(pushData)}`);
        }
      }

      if (issues.length === 0) {
        setHealthSummary('All checks passed. Push pipeline looks healthy.');
        toast.success(`Push Health Check OK\n${ok.join(' | ')}`);
      } else {
        setHealthSummary('Some checks failed. See details below.');
        toast.error(`Push Health Check failed\n${issues.join(' | ')}`);
      }
    } catch (e: any) {
      setHealthSummary('Health check crashed unexpectedly.');
      step('Unexpected error', false, e?.message || String(e));
      toast.error(`Push Health Check crashed: ${e?.message || String(e)}`);
    } finally {
      setCheckingPushHealth(false);
    }
  };

  const copyHealthReport = async () => {
    const lines = [
      `Push Health Check Report`,
      `Time: ${new Date().toISOString()}`,
      `Admin: ${adminName}${adminId ? ` (${adminId})` : ''}`,
      `Society: ${societyId ?? 'N/A'}`,
      '',
      `Summary: ${healthSummary || 'N/A'}`,
      '',
      ...healthSteps.map((s, i) => `${i + 1}. ${s.ok ? 'PASS' : 'FAIL'} - ${s.label}: ${s.detail}`),
    ];
    const report = lines.join('\n');
    try {
      await navigator.clipboard.writeText(report);
      toast.success('Push health report copied');
    } catch {
      toast.error('Could not copy report');
    }
  };

  const toggleResident = (r: (typeof residents)[0]) => {
    setSelectedResidents(prev =>
      prev.find(p => p.id === r.id) ? prev.filter(p => p.id !== r.id) : [...prev, r]
    );
  };

  const onPickFiles = (list: FileList | null) => {
    if (!list?.length) return;
    const next: File[] = [...pendingFiles];
    for (let i = 0; i < list.length; i++) {
      const f = list.item(i);
      if (!f) continue;
      if (!fileMediaKind(f)) {
        toast.error(`${f.name}: use an image or video file`);
        continue;
      }
      if (next.length >= MAX_ATTACHMENTS) {
        toast.error(`Maximum ${MAX_ATTACHMENTS} attachments`);
        break;
      }
      next.push(f);
    }
    setPendingFiles(next);
  };

  const typeIcons: Record<string, string> = {
    general: '📢',
    payment_reminder: '💰',
    event: '🎉',
    event_reminder: '🔔',
    poll: '📊',
    alert: '⚠️',
  };
  const unreadCount = notifications.filter(n => !n.is_read).length;

  return (
    <div className="page-container pb-24">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-amber-500/10 flex items-center justify-center relative">
            <Bell className="w-5 h-5 text-amber-500" />
            {unreadCount > 0 && (
              <span className="absolute -top-1 -right-1 w-5 h-5 bg-destructive text-destructive-foreground text-[10px] rounded-full flex items-center justify-center">
                {unreadCount}
              </span>
            )}
          </div>
          <div>
            <h1 className="page-title">Notifications</h1>
            <p className="text-xs text-muted-foreground">{unreadCount} unread • Push enabled</p>
          </div>
        </div>
        {unreadCount > 0 && (
          <button type="button" onClick={markAllRead} className="text-xs text-primary underline">
            Mark all read
          </button>
        )}
      </div>

      {!isResident && (
        <>
          <button
            type="button"
            onClick={() => setShowForm(!showForm)}
            className="btn-primary w-full mb-4 flex items-center justify-center gap-2"
          >
            <Plus className="w-4 h-4" /> Send Push Notification
          </button>
          <button
            type="button"
            onClick={() => void runPushHealthCheck()}
            disabled={checkingPushHealth}
            className="w-full mb-4 py-2 rounded-lg border border-border text-xs font-medium"
          >
            {checkingPushHealth ? 'Running Push Health Check…' : 'Push Health Check'}
          </button>
          {showForm && (
            <div className="card-section p-4 mb-4 flex flex-col gap-3">
              <input
                className="input-field"
                placeholder="Title"
                value={nf.title}
                onChange={e => setNf({ ...nf, title: e.target.value })}
              />
              <textarea
                className="input-field"
                placeholder="Message"
                value={nf.message}
                onChange={e => setNf({ ...nf, message: e.target.value })}
              />
              <select className="input-field" value={nf.type} onChange={e => setNf({ ...nf, type: e.target.value })}>
                <option value="general">📢 General</option>
                <option value="alert">⚠️ Alert</option>
                <option value="event">🎉 Event</option>
                <option value="payment_reminder">💰 Payment Reminder</option>
              </select>

              <div>
                <p className="text-xs font-medium text-muted-foreground mb-1">Attachments (optional)</p>
                <p className="text-[10px] text-muted-foreground mb-2">
                  Up to {MAX_ATTACHMENTS} images or videos. Residents open the alert to view in full screen and discuss below
                  it.
                </p>
                <div className="flex flex-wrap items-center gap-2">
                  <label className="inline-flex cursor-pointer items-center gap-2 rounded-lg border border-border bg-muted/40 px-3 py-2 text-xs font-medium hover:bg-muted">
                    <Paperclip className="h-4 w-4" />
                    Add photos / videos
                    <input
                      type="file"
                      accept="image/*,video/mp4,video/webm,video/quicktime"
                      multiple
                      className="hidden"
                      onChange={e => {
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
                      {f.name.slice(0, 18)}
                      {f.name.length > 18 ? '…' : ''}
                      <button
                        type="button"
                        className="rounded p-0.5 hover:bg-primary/20"
                        onClick={() => setPendingFiles(prev => prev.filter((_, j) => j !== i))}
                        aria-label="Remove"
                      >
                        <X className="h-3 w-3" />
                      </button>
                    </span>
                  ))}
                </div>
              </div>

              <div>
                <p className="text-xs font-medium text-muted-foreground mb-2">Send To:</p>
                <div className="flex gap-2">
                  {[
                    { mode: 'all' as TargetMode, label: 'All Residents', icon: Users },
                    { mode: 'flat' as TargetMode, label: 'Select Flats', icon: Home },
                    { mode: 'user' as TargetMode, label: 'Select Persons', icon: User },
                  ].map(t => (
                    <button
                      key={t.mode}
                      type="button"
                      onClick={() => setTargetMode(t.mode)}
                      className={`flex-1 p-2 rounded-lg border text-xs flex flex-col items-center gap-1 transition-colors ${
                        targetMode === t.mode
                          ? 'bg-primary/10 border-primary text-primary'
                          : 'border-border text-muted-foreground'
                      }`}
                    >
                      <t.icon className="w-4 h-4" />
                      {t.label}
                    </button>
                  ))}
                </div>
              </div>

              {targetMode === 'flat' && (
                <FlatMultiSelect
                  compact
                  flats={flatOptionsWithPrimaryLabel(flats, primaryByFlatId)}
                  selected={selectedFlats}
                  onChange={setSelectedFlats}
                  label="Select flats"
                />
              )}

              {targetMode === 'user' && (
                <div>
                  <p className="text-xs text-muted-foreground mb-1">
                    Select residents ({selectedResidents.length} selected):
                  </p>
                  <div className="max-h-40 overflow-y-auto space-y-1">
                    {residents.map(r => (
                      <button
                        key={r.id}
                        type="button"
                        onClick={() => toggleResident(r)}
                        className={`w-full text-left text-xs p-2 rounded border flex justify-between ${
                          selectedResidents.find(s => s.id === r.id)
                            ? 'bg-primary/10 border-primary'
                            : 'bg-card border-border'
                        }`}
                      >
                        <span>{r.name}</span>
                        <span className="text-muted-foreground">Flat {r.flat_number}</span>
                      </button>
                    ))}
                  </div>
                </div>
              )}

              <button
                type="button"
                onClick={() => void sendNotification()}
                disabled={sending}
                className="btn-primary flex items-center justify-center gap-2"
              >
                <Send className="w-4 h-4" />
                {sending ? 'Sending...' : 'Send Push + In-App'}
              </button>
            </div>
          )}
        </>
      )}

      <div className="space-y-2">
        {notifications.length === 0 && (
          <p className="text-sm text-muted-foreground text-center py-8">No notifications</p>
        )}
        {notifications.map(n => {
          const mediaCount = parseNotificationMedia(n.media_items).length;
          return (
            <button
              key={n.id}
              type="button"
              onClick={() => openNotification(n)}
              className={`card-section w-full p-3 text-left transition-colors ${
                !n.is_read ? 'border-primary/30 bg-primary/5' : 'hover:bg-muted/40'
              }`}
            >
              <div className="flex gap-2">
                <span className="text-lg">{typeIcons[n.type] || '📢'}</span>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-semibold">{n.title}</p>
                  <p className="text-xs text-muted-foreground line-clamp-2">{n.message}</p>
                  <div className="mt-1 flex flex-wrap items-center gap-2">
                    <p className="text-[10px] text-muted-foreground">{new Date(n.created_at).toLocaleString()}</p>
                    {n.target_type !== 'all' && (
                      <span className="text-[10px] bg-primary/10 text-primary px-1.5 rounded">
                        → {n.target_type === 'flat' ? `Flat ${n.target_id}` : n.target_id}
                      </span>
                    )}
                    <NotificationMediaBadges count={mediaCount} />
                  </div>
                  <p className="mt-1 text-[10px] text-primary/80">Tap to view · discuss in thread</p>
                </div>
                {!n.is_read && <span className="w-2 h-2 rounded-full bg-primary mt-2 shrink-0" aria-hidden />}
              </div>
            </button>
          );
        })}
      </div>

      <NotificationDetailModal
        open={detailOpen}
        onOpenChange={open => {
          setDetailOpen(open);
          if (!open) setActiveNotification(null);
        }}
        notification={activeNotification}
        isResident={isResident}
        resident={resident}
        adminName={adminName}
      />

      <Dialog open={healthOpen} onOpenChange={setHealthOpen}>
        <DialogContent className="max-w-lg">
          <DialogHeader>
            <DialogTitle>Push Health Check</DialogTitle>
            <DialogDescription>{healthSummary || 'Running diagnostics...'}</DialogDescription>
          </DialogHeader>
          <div className="flex justify-end">
            <button
              type="button"
              onClick={() => void copyHealthReport()}
              disabled={healthSteps.length === 0}
              className="text-xs px-2.5 py-1.5 rounded-lg border border-border disabled:opacity-50"
            >
              Copy report
            </button>
          </div>
          <div className="space-y-2 max-h-[60vh] overflow-y-auto">
            {healthSteps.length === 0 && (
              <p className="text-sm text-muted-foreground">Checking environment, permission, token, and delivery path...</p>
            )}
            {healthSteps.map((s, i) => (
              <div key={`${s.label}-${i}`} className="rounded-lg border border-border p-2.5">
                <p className="text-sm font-medium">
                  {s.ok ? '✅' : '❌'} {s.label}
                </p>
                <p className="text-xs text-muted-foreground mt-0.5 break-words">{s.detail}</p>
              </div>
            ))}
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
};

export default NotificationCenter;
