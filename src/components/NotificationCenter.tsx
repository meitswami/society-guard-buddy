import { useState, useEffect } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { Bell, Plus, Check, Trash2 } from 'lucide-react';
import { toast } from 'sonner';

interface Props { adminName?: string; isResident?: boolean; flatNumber?: string; }

const NotificationCenter = ({ adminName = 'Admin', isResident = false, flatNumber = '' }: Props) => {
  const [notifications, setNotifications] = useState<any[]>([]);
  const [showForm, setShowForm] = useState(false);
  const [nf, setNf] = useState({ title: '', message: '', type: 'general' });

  useEffect(() => { loadNotifications(); }, []);

  // Realtime
  useEffect(() => {
    const channel = supabase.channel('notifications-rt')
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'notifications' }, () => loadNotifications())
      .subscribe();
    return () => { supabase.removeChannel(channel); };
  }, []);

  const loadNotifications = async () => {
    let query = supabase.from('notifications').select('*').order('created_at', { ascending: false }).limit(100);
    if (isResident) {
      // Show notifications targeted to all or to this flat
      query = query.or(`target_type.eq.all,target_id.eq.${flatNumber}`);
    }
    const { data } = await query;
    if (data) setNotifications(data);
  };

  const sendNotification = async () => {
    if (!nf.title || !nf.message) return;
    await supabase.from('notifications').insert([{
      title: nf.title, message: nf.message, type: nf.type, target_type: 'all', created_by: adminName,
    }]);
    setNf({ title: '', message: '', type: 'general' }); setShowForm(false);
    toast.success('Notification sent'); loadNotifications();
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
            <p className="text-xs text-muted-foreground">{unreadCount} unread</p>
          </div>
        </div>
        {unreadCount > 0 && (
          <button onClick={markAllRead} className="text-xs text-primary underline">Mark all read</button>
        )}
      </div>

      {!isResident && (
        <>
          <button onClick={() => setShowForm(!showForm)} className="btn-primary w-full mb-4 flex items-center justify-center gap-2">
            <Plus className="w-4 h-4" /> Send Notification
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
              <button onClick={sendNotification} className="btn-primary">Send</button>
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
                <p className="text-[10px] text-muted-foreground mt-1">{new Date(n.created_at).toLocaleString()}</p>
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
