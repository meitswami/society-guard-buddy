import { useState, useEffect } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { Bell, Plus, Check, Send, Users, User, Home } from 'lucide-react';
import { toast } from 'sonner';

interface Props { adminName?: string; isResident?: boolean; flatNumber?: string; }

type TargetMode = 'all' | 'flat' | 'user';

const NotificationCenter = ({ adminName = 'Admin', isResident = false, flatNumber = '' }: Props) => {
  const [notifications, setNotifications] = useState<any[]>([]);
  const [showForm, setShowForm] = useState(false);
  const [nf, setNf] = useState({ title: '', message: '', type: 'general' });
  const [targetMode, setTargetMode] = useState<TargetMode>('all');
  const [selectedFlats, setSelectedFlats] = useState<string[]>([]);
  const [selectedResidents, setSelectedResidents] = useState<{id: string; name: string; flatNumber: string}[]>([]);
  const [flats, setFlats] = useState<any[]>([]);
  const [residents, setResidents] = useState<any[]>([]);
  const [sending, setSending] = useState(false);

  useEffect(() => { loadNotifications(); loadFlatsAndResidents(); }, []);

  useEffect(() => {
    const channel = supabase.channel('notifications-rt')
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'notifications' }, () => loadNotifications())
      .subscribe();
    return () => { supabase.removeChannel(channel); };
  }, []);

  const loadFlatsAndResidents = async () => {
    const [fRes, rRes] = await Promise.all([
      supabase.from('flats').select('id, flat_number, owner_name').order('flat_number'),
      supabase.from('resident_users').select('id, name, flat_number, flat_id').order('name'),
    ]);
    if (fRes.data) setFlats(fRes.data);
    if (rRes.data) setResidents(rRes.data);
  };

  const loadNotifications = async () => {
    let query = supabase.from('notifications').select('*').order('created_at', { ascending: false }).limit(100);
    if (isResident) {
      query = query.or(`target_type.eq.all,target_id.eq.${flatNumber}`);
    }
    const { data } = await query;
    if (data) setNotifications(data);
  };

  const sendNotification = async () => {
    if (!nf.title || !nf.message) return;
    setSending(true);

    // Determine target
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

    // Save to DB (one per target for flat targeting, or one for all)
    if (targetMode === 'flat') {
      for (const flat of selectedFlats) {
        await supabase.from('notifications').insert([{
          title: nf.title, message: nf.message, type: nf.type,
          target_type: 'flat', target_id: flat, created_by: adminName,
        }]);
      }
    } else {
      await supabase.from('notifications').insert([{
        title: nf.title, message: nf.message, type: nf.type,
        target_type: targetType, target_id: targetId, created_by: adminName,
      }]);
    }

    // Send push via OneSignal edge function
    try {
      await supabase.functions.invoke('send-push-notification', {
        body: {
          title: nf.title,
          message: nf.message,
          target_type: targetMode,
          target_flat_numbers: targetFlatNumbers,
          target_ids: targetUserIds,
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
    setSending(false);
    toast.success('Notification sent with push alert!');
    loadNotifications();
  };

  const markRead = async (id: string) => {
    await supabase.from('notifications').update({ is_read: true }).eq('id', id);
    loadNotifications();
  };

  const markAllRead = async () => {
    const ids = notifications.filter(n => !n.is_read).map(n => n.id);
    if (ids.length === 0) return;
    for (const id of ids) {
      await supabase.from('notifications').update({ is_read: true }).eq('id', id);
    }
    toast.success('All marked as read'); loadNotifications();
  };

  const toggleFlat = (flat: string) => {
    setSelectedFlats(prev => prev.includes(flat) ? prev.filter(f => f !== flat) : [...prev, flat]);
  };

  const toggleResident = (r: any) => {
    setSelectedResidents(prev =>
      prev.find(p => p.id === r.id) ? prev.filter(p => p.id !== r.id) : [...prev, r]
    );
  };

  const typeIcons: Record<string, string> = {
    general: '📢', payment_reminder: '💰', event: '🎉', event_reminder: '🔔', poll: '📊', alert: '⚠️',
  };
  const unreadCount = notifications.filter(n => !n.is_read).length;

  return (
    <div className="page-container pb-24">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-amber-500/10 flex items-center justify-center relative">
            <Bell className="w-5 h-5 text-amber-500" />
            {unreadCount > 0 && (
              <span className="absolute -top-1 -right-1 w-5 h-5 bg-destructive text-destructive-foreground text-[10px] rounded-full flex items-center justify-center">{unreadCount}</span>
            )}
          </div>
          <div>
            <h1 className="page-title">Notifications</h1>
            <p className="text-xs text-muted-foreground">{unreadCount} unread • Push enabled</p>
          </div>
        </div>
        {unreadCount > 0 && (
          <button onClick={markAllRead} className="text-xs text-primary underline">Mark all read</button>
        )}
      </div>

      {!isResident && (
        <>
          <button onClick={() => setShowForm(!showForm)} className="btn-primary w-full mb-4 flex items-center justify-center gap-2">
            <Plus className="w-4 h-4" /> Send Push Notification
          </button>
          {showForm && (
            <div className="card-section p-4 mb-4 flex flex-col gap-3">
              <input className="input-field" placeholder="Title" value={nf.title} onChange={e => setNf({...nf, title: e.target.value})} />
              <textarea className="input-field" placeholder="Message" value={nf.message} onChange={e => setNf({...nf, message: e.target.value})} />
              <select className="input-field" value={nf.type} onChange={e => setNf({...nf, type: e.target.value})}>
                <option value="general">📢 General</option>
                <option value="alert">⚠️ Alert</option>
                <option value="event">🎉 Event</option>
                <option value="payment_reminder">💰 Payment Reminder</option>
              </select>

              {/* Target Selection */}
              <div>
                <p className="text-xs font-medium text-muted-foreground mb-2">Send To:</p>
                <div className="flex gap-2">
                  {[
                    { mode: 'all' as TargetMode, label: 'All Residents', icon: Users },
                    { mode: 'flat' as TargetMode, label: 'Select Flats', icon: Home },
                    { mode: 'user' as TargetMode, label: 'Select Persons', icon: User },
                  ].map(t => (
                    <button key={t.mode} onClick={() => setTargetMode(t.mode)}
                      className={`flex-1 p-2 rounded-lg border text-xs flex flex-col items-center gap-1 transition-colors ${
                        targetMode === t.mode ? 'bg-primary/10 border-primary text-primary' : 'border-border text-muted-foreground'
                      }`}>
                      <t.icon className="w-4 h-4" />
                      {t.label}
                    </button>
                  ))}
                </div>
              </div>

              {/* Flat picker */}
              {targetMode === 'flat' && (
                <div>
                  <p className="text-xs text-muted-foreground mb-1">Select flats ({selectedFlats.length} selected):</p>
                  <div className="max-h-32 overflow-y-auto grid grid-cols-4 gap-1">
                    {flats.map(f => (
                      <button key={f.id} onClick={() => toggleFlat(f.flat_number)}
                        className={`text-xs p-1.5 rounded border ${
                          selectedFlats.includes(f.flat_number)
                            ? 'bg-primary text-primary-foreground border-primary'
                            : 'bg-card border-border'
                        }`}>
                        {f.flat_number}
                      </button>
                    ))}
                  </div>
                </div>
              )}

              {/* Resident picker */}
              {targetMode === 'user' && (
                <div>
                  <p className="text-xs text-muted-foreground mb-1">Select residents ({selectedResidents.length} selected):</p>
                  <div className="max-h-40 overflow-y-auto space-y-1">
                    {residents.map(r => (
                      <button key={r.id} onClick={() => toggleResident(r)}
                        className={`w-full text-left text-xs p-2 rounded border flex justify-between ${
                          selectedResidents.find(s => s.id === r.id)
                            ? 'bg-primary/10 border-primary'
                            : 'bg-card border-border'
                        }`}>
                        <span>{r.name}</span>
                        <span className="text-muted-foreground">Flat {r.flat_number}</span>
                      </button>
                    ))}
                  </div>
                </div>
              )}

              <button onClick={sendNotification} disabled={sending}
                className="btn-primary flex items-center justify-center gap-2">
                <Send className="w-4 h-4" />
                {sending ? 'Sending...' : 'Send Push + In-App'}
              </button>
            </div>
          )}
        </>
      )}

      <div className="space-y-2">
        {notifications.length === 0 && <p className="text-sm text-muted-foreground text-center py-8">No notifications</p>}
        {notifications.map(n => (
          <div key={n.id} className={`card-section p-3 ${!n.is_read ? 'border-primary/30 bg-primary/5' : ''}`}
            onClick={() => !n.is_read && markRead(n.id)}>
            <div className="flex gap-2">
              <span className="text-lg">{typeIcons[n.type] || '📢'}</span>
              <div className="flex-1">
                <p className="text-sm font-semibold">{n.title}</p>
                <p className="text-xs text-muted-foreground">{n.message}</p>
                <div className="flex gap-2 mt-1">
                  <p className="text-[10px] text-muted-foreground">{new Date(n.created_at).toLocaleString()}</p>
                  {n.target_type !== 'all' && (
                    <span className="text-[10px] bg-primary/10 text-primary px-1.5 rounded">
                      → {n.target_type === 'flat' ? `Flat ${n.target_id}` : n.target_id}
                    </span>
                  )}
                </div>
              </div>
              {!n.is_read && <span className="w-2 h-2 rounded-full bg-primary mt-2 shrink-0" />}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};

export default NotificationCenter;
