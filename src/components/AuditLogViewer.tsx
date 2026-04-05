import { useState, useEffect } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useLanguage } from '@/i18n/LanguageContext';
import { FileText, Shield, AlertTriangle, Info, Search, Filter } from 'lucide-react';

interface AuditLog {
  id: string;
  created_at: string;
  event_type: string;
  user_type: string;
  user_id: string | null;
  user_name: string | null;
  ip_address: string | null;
  user_agent: string | null;
  device_info: Record<string, unknown>;
  details: Record<string, unknown>;
  severity: string;
}

const severityColors: Record<string, string> = {
  info: 'bg-blue-500/10 text-blue-600',
  warning: 'bg-amber-500/10 text-amber-600',
  critical: 'bg-destructive/10 text-destructive',
};

const eventLabels: Record<string, string> = {
  login_success: '✅ Login Success',
  login_failed: '❌ Login Failed',
  password_change: '🔑 Password Changed',
  password_reset: '🔄 Password Reset',
  logout: '🚪 Logout',
  biometric_register: '👆 Biometric Registered',
  geofence_violation: '📍 Geofence / Location breach',
};

const AuditLogViewer = () => {
  const { t } = useLanguage();
  const [logs, setLogs] = useState<AuditLog[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('all');
  const [search, setSearch] = useState('');
  const [expandedId, setExpandedId] = useState<string | null>(null);

  useEffect(() => { loadLogs(); }, [filter]);

  const loadLogs = async () => {
    setLoading(true);
    let query = supabase.from('audit_logs').select('*').order('created_at', { ascending: false }).limit(200);
    if (filter !== 'all') query = query.eq('event_type', filter);
    const { data } = await query;
    setLogs((data as AuditLog[]) || []);
    setLoading(false);
  };

  const filtered = logs.filter(l => {
    if (!search) return true;
    const s = search.toLowerCase();
    return (l.user_name?.toLowerCase().includes(s) || l.user_id?.toLowerCase().includes(s) || l.ip_address?.includes(s) || l.user_type.includes(s));
  });

  const stats = {
    total: logs.length,
    failed: logs.filter(l => l.event_type === 'login_failed').length,
    resets: logs.filter(l => l.event_type === 'password_reset' || l.event_type === 'password_change').length,
  };

  return (
    <div className="page-container pb-24">
      <div className="flex items-center gap-3 mb-4">
        <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
          <FileText className="w-5 h-5 text-primary" />
        </div>
        <div>
          <h1 className="page-title">{t('audit.title') || 'Security Audit Logs'}</h1>
          <p className="text-xs text-muted-foreground">{stats.total} events · {stats.failed} failed · {stats.resets} resets</p>
        </div>
      </div>

      {/* Stats cards */}
      <div className="grid grid-cols-3 gap-2 mb-4">
        <div className="card-section p-3 text-center">
          <Info className="w-4 h-4 text-blue-500 mx-auto mb-1" />
          <p className="text-lg font-bold">{stats.total}</p>
          <p className="text-[10px] text-muted-foreground">Total Events</p>
        </div>
        <div className="card-section p-3 text-center">
          <AlertTriangle className="w-4 h-4 text-amber-500 mx-auto mb-1" />
          <p className="text-lg font-bold">{stats.failed}</p>
          <p className="text-[10px] text-muted-foreground">Failed Logins</p>
        </div>
        <div className="card-section p-3 text-center">
          <Shield className="w-4 h-4 text-green-500 mx-auto mb-1" />
          <p className="text-lg font-bold">{stats.resets}</p>
          <p className="text-[10px] text-muted-foreground">Pwd Changes</p>
        </div>
      </div>

      {/* Search & Filter */}
      <div className="flex gap-2 mb-4">
        <div className="relative flex-1">
          <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" />
          <input className="input-field pl-9 text-sm" placeholder="Search name, ID, IP..."
            value={search} onChange={e => setSearch(e.target.value)} />
        </div>
        <select className="input-field text-xs w-auto" value={filter} onChange={e => setFilter(e.target.value)}>
          <option value="all">All Events</option>
          <option value="login_success">Login Success</option>
          <option value="login_failed">Login Failed</option>
          <option value="password_change">Password Change</option>
          <option value="password_reset">Password Reset</option>
          <option value="logout">Logout</option>
          <option value="biometric_register">Biometric</option>
          <option value="geofence_violation">Geofence / Location</option>
        </select>
      </div>

      {/* Logs */}
      {loading ? (
        <p className="text-sm text-muted-foreground text-center py-8">Loading...</p>
      ) : filtered.length === 0 ? (
        <p className="text-sm text-muted-foreground text-center py-8">No audit logs found</p>
      ) : (
        <div className="space-y-2">
          {filtered.map(log => (
            <div key={log.id} className="card-section p-3 cursor-pointer" onClick={() => setExpandedId(expandedId === log.id ? null : log.id)}>
              <div className="flex items-start justify-between">
                <div className="flex-1">
                  <div className="flex items-center gap-2 mb-1">
                    <span className={`text-[10px] px-2 py-0.5 rounded-full font-medium ${severityColors[log.severity] || severityColors.info}`}>
                      {log.severity.toUpperCase()}
                    </span>
                    <span className="text-[10px] px-2 py-0.5 rounded-full bg-muted text-muted-foreground font-mono">
                      {log.user_type}
                    </span>
                  </div>
                  <p className="text-sm font-medium">{eventLabels[log.event_type] || log.event_type}</p>
                  <p className="text-xs text-muted-foreground">
                    {log.user_name || log.user_id || 'Unknown'} · {log.ip_address || 'no IP'}
                  </p>
                  <p className="text-[10px] text-muted-foreground mt-1">
                    {new Date(log.created_at).toLocaleString()}
                  </p>
                </div>
              </div>
              {expandedId === log.id && (
                <div className="mt-3 pt-3 border-t border-border space-y-2">
                  <div className="grid grid-cols-2 gap-2 text-xs">
                    <div>
                      <p className="text-muted-foreground">IP Address</p>
                      <p className="font-mono">{log.ip_address || 'N/A'}</p>
                    </div>
                    <div>
                      <p className="text-muted-foreground">User Type</p>
                      <p className="capitalize">{log.user_type}</p>
                    </div>
                  </div>
                  {log.device_info && Object.keys(log.device_info).length > 0 && (
                    <div>
                      <p className="text-xs text-muted-foreground mb-1">Device Info</p>
                      <div className="bg-muted/50 rounded-lg p-2 text-[10px] font-mono break-all">
                        {Object.entries(log.device_info).map(([k, v]) => (
                          <p key={k}><span className="text-muted-foreground">{k}:</span> {String(v)}</p>
                        ))}
                      </div>
                    </div>
                  )}
                  {log.details && Object.keys(log.details).length > 0 && (
                    <div>
                      <p className="text-xs text-muted-foreground mb-1">Details</p>
                      <div className="bg-muted/50 rounded-lg p-2 text-[10px] font-mono break-all">
                        {Object.entries(log.details).map(([k, v]) => (
                          <p key={k}><span className="text-muted-foreground">{k}:</span> {String(v)}</p>
                        ))}
                      </div>
                    </div>
                  )}
                  {log.user_agent && (
                    <div>
                      <p className="text-xs text-muted-foreground mb-1">User Agent</p>
                      <p className="text-[10px] font-mono text-muted-foreground break-all">{log.user_agent}</p>
                    </div>
                  )}
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

export default AuditLogViewer;
