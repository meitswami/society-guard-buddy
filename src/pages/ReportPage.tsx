import { useState, useMemo, useEffect } from 'react';
import { useStore } from '@/store/useStore';
import { supabase } from '@/integrations/supabase/client';
import { BarChart3, Download, Printer, Calendar, Users, Car, Truck, Shield } from 'lucide-react';
import { format } from 'date-fns';

interface ShiftRow {
  id: string;
  guard_id: string;
  guard_name: string;
  login_time: string;
  logout_time: string | null;
}

const ReportPage = () => {
  const { visitors } = useStore();
  const [date, setDate] = useState(format(new Date(), 'yyyy-MM-dd'));
  const [shifts, setShifts] = useState<ShiftRow[]>([]);

  useEffect(() => {
    const loadShifts = async () => {
      const { data } = await supabase
        .from('guard_shifts')
        .select('*')
        .gte('login_time', `${date}T00:00:00`)
        .lte('login_time', `${date}T23:59:59`)
        .order('login_time', { ascending: true });
      if (data) setShifts(data);
    };
    loadShifts();
  }, [date]);

  const dayVisitors = useMemo(() => visitors.filter(v => v.entryTime.startsWith(date)), [visitors, date]);

  const stats = useMemo(() => ({
    totalVisitors: dayVisitors.filter(v => v.category === 'visitor').length,
    totalVehicles: dayVisitors.filter(v => v.vehicleNumber).length,
    totalDeliveries: dayVisitors.filter(v => v.category === 'delivery' || v.category === 'service').length,
    currentlyInside: dayVisitors.filter(v => !v.exitTime).length,
    uniqueFlats: new Set(dayVisitors.map(v => v.flatNumber)).size,
  }), [dayVisitors]);

  const printReport = () => {
    const visitorRows = dayVisitors.map(v => `
      <tr>
        <td style="padding:6px 8px;border-bottom:1px solid #eee;font-size:12px;">${v.name}</td>
        <td style="padding:6px 8px;border-bottom:1px solid #eee;font-size:12px;font-family:monospace;">${v.phone}</td>
        <td style="padding:6px 8px;border-bottom:1px solid #eee;font-size:12px;">${v.flatNumber}</td>
        <td style="padding:6px 8px;border-bottom:1px solid #eee;font-size:12px;">${v.category}</td>
        <td style="padding:6px 8px;border-bottom:1px solid #eee;font-size:12px;">${v.purpose}</td>
        <td style="padding:6px 8px;border-bottom:1px solid #eee;font-size:12px;">${format(new Date(v.entryTime), 'hh:mm a')}</td>
        <td style="padding:6px 8px;border-bottom:1px solid #eee;font-size:12px;">${v.exitTime ? format(new Date(v.exitTime), 'hh:mm a') : 'Inside'}</td>
        <td style="padding:6px 8px;border-bottom:1px solid #eee;font-size:12px;">${v.vehicleNumber || '-'}</td>
        <td style="padding:6px 8px;border-bottom:1px solid #eee;font-size:12px;">${v.guardName}</td>
      </tr>`).join('');

    const shiftRows = shifts.map(s => `
      <tr>
        <td style="padding:6px 8px;border-bottom:1px solid #eee;font-size:12px;font-family:monospace;">${s.guard_id}</td>
        <td style="padding:6px 8px;border-bottom:1px solid #eee;font-size:12px;">${s.guard_name}</td>
        <td style="padding:6px 8px;border-bottom:1px solid #eee;font-size:12px;">${format(new Date(s.login_time), 'hh:mm a')}</td>
        <td style="padding:6px 8px;border-bottom:1px solid #eee;font-size:12px;">${s.logout_time ? format(new Date(s.logout_time), 'hh:mm a') : 'Active'}</td>
      </tr>`).join('');

    const html = `<!DOCTYPE html><html><head><title>Daily Report - ${date}</title><style>
      body{font-family:Arial,sans-serif;padding:20px;color:#333}
      table{width:100%;border-collapse:collapse;margin-bottom:24px}
      th{text-align:left;padding:8px;background:#f5f5f5;border-bottom:2px solid #ddd;font-size:12px}
      h1{font-size:20px}h2{font-size:16px;margin-top:24px;border-bottom:1px solid #ddd;padding-bottom:4px}
      .stats{display:flex;gap:16px;margin:16px 0;flex-wrap:wrap}
      .stat{background:#f8f8f8;padding:12px 16px;border-radius:8px;min-width:100px}
      .stat-val{font-size:24px;font-weight:bold}.stat-label{font-size:11px;color:#888}
    </style></head><body>
      <h1>🏢 Gate Management — Daily Report</h1>
      <p style="color:#888">${format(new Date(date), 'EEEE, dd MMMM yyyy')}</p>
      <div class="stats">
        <div class="stat"><div class="stat-val">${stats.totalVisitors}</div><div class="stat-label">Visitors</div></div>
        <div class="stat"><div class="stat-val">${stats.totalVehicles}</div><div class="stat-label">Vehicles</div></div>
        <div class="stat"><div class="stat-val">${stats.totalDeliveries}</div><div class="stat-label">Deliveries</div></div>
        <div class="stat"><div class="stat-val">${stats.currentlyInside}</div><div class="stat-label">Inside Now</div></div>
        <div class="stat"><div class="stat-val">${stats.uniqueFlats}</div><div class="stat-label">Flats Visited</div></div>
      </div>
      <h2>Visitor Log (${dayVisitors.length} entries)</h2>
      <table><thead><tr><th>Name</th><th>Phone</th><th>Flat</th><th>Category</th><th>Purpose</th><th>In</th><th>Out</th><th>Vehicle</th><th>Guard</th></tr></thead>
      <tbody>${visitorRows || '<tr><td colspan="9" style="text-align:center;padding:20px;color:#999">No entries</td></tr>'}</tbody></table>
      <h2>Guard Shifts (${shifts.length})</h2>
      <table><thead><tr><th>Guard ID</th><th>Name</th><th>Login</th><th>Logout</th></tr></thead>
      <tbody>${shiftRows || '<tr><td colspan="4" style="text-align:center;padding:20px;color:#999">No shifts</td></tr>'}</tbody></table>
      <p style="color:#aaa;font-size:10px;margin-top:32px">Generated: ${format(new Date(), 'dd MMM yyyy, hh:mm a')}</p>
    </body></html>`;

    const win = window.open('', '_blank');
    if (win) {
      win.document.write(html);
      win.document.close();
      setTimeout(() => win.print(), 500);
    }
  };

  const exportCSV = () => {
    const headers = ['Name', 'Phone', 'Flat', 'Category', 'Purpose', 'Entry', 'Exit', 'Vehicle', 'Guard'];
    const rows = dayVisitors.map(v => [
      v.name, v.phone, v.flatNumber, v.category, v.purpose,
      format(new Date(v.entryTime), 'dd/MM/yyyy HH:mm'),
      v.exitTime ? format(new Date(v.exitTime), 'dd/MM/yyyy HH:mm') : 'Inside',
      v.vehicleNumber || '-', v.guardName,
    ]);
    const csv = [headers, ...rows].map(r => r.join(',')).join('\n');
    const blob = new Blob([csv], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `daily-report-${date}.csv`;
    a.click();
  };

  return (
    <div className="page-container">
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
            <BarChart3 className="w-5 h-5 text-primary" />
          </div>
          <div>
            <h1 className="page-title">Daily Report</h1>
            <p className="text-xs text-muted-foreground">Summary & export</p>
          </div>
        </div>
        <div className="flex gap-1.5">
          <button onClick={exportCSV} className="btn-secondary text-xs px-2.5 py-2 flex items-center gap-1">
            <Download className="w-3.5 h-3.5" /> CSV
          </button>
          <button onClick={printReport} className="btn-primary text-xs px-2.5 py-2 flex items-center gap-1">
            <Printer className="w-3.5 h-3.5" /> Print
          </button>
        </div>
      </div>

      {/* Date picker */}
      <div className="flex items-center gap-2 mb-5">
        <Calendar className="w-4 h-4 text-muted-foreground" />
        <input type="date" className="input-field text-sm flex-1" value={date} onChange={e => setDate(e.target.value)} />
      </div>

      {/* Stats */}
      <div className="grid grid-cols-3 gap-2 mb-6">
        <div className="stat-card items-center text-center">
          <Users className="w-4 h-4 text-muted-foreground" />
          <span className="text-xl font-bold font-mono">{stats.totalVisitors}</span>
          <span className="text-[10px] text-muted-foreground">Visitors</span>
        </div>
        <div className="stat-card items-center text-center">
          <Car className="w-4 h-4 text-muted-foreground" />
          <span className="text-xl font-bold font-mono">{stats.totalVehicles}</span>
          <span className="text-[10px] text-muted-foreground">Vehicles</span>
        </div>
        <div className="stat-card items-center text-center">
          <Truck className="w-4 h-4 text-muted-foreground" />
          <span className="text-xl font-bold font-mono">{stats.totalDeliveries}</span>
          <span className="text-[10px] text-muted-foreground">Deliveries</span>
        </div>
      </div>

      {/* Guard Shifts */}
      <div className="mb-6">
        <h2 className="text-sm font-semibold mb-3 flex items-center gap-1.5">
          <Shield className="w-4 h-4 text-primary" /> Guard Shifts
        </h2>
        {shifts.length === 0 ? (
          <p className="text-xs text-muted-foreground text-center py-4">No shifts recorded</p>
        ) : (
          <div className="flex flex-col gap-2">
            {shifts.map(s => (
              <div key={s.id} className="card-section flex items-center gap-3">
                <div className={`w-2 h-2 rounded-full ${s.logout_time ? 'bg-muted-foreground' : 'bg-success animate-pulse'}`} />
                <div className="flex-1">
                  <p className="text-sm font-medium">{s.guard_name} <span className="font-mono text-xs text-muted-foreground">({s.guard_id})</span></p>
                  <p className="text-xs text-muted-foreground">
                    {format(new Date(s.login_time), 'hh:mm a')}
                    {s.logout_time && ` — ${format(new Date(s.logout_time), 'hh:mm a')}`}
                    {!s.logout_time && ' — Active'}
                  </p>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Visitor Summary */}
      <div>
        <h2 className="text-sm font-semibold mb-3">Entries ({dayVisitors.length})</h2>
        {dayVisitors.length === 0 ? (
          <p className="text-xs text-muted-foreground text-center py-4">No entries for this date</p>
        ) : (
          <div className="flex flex-col gap-1.5">
            {dayVisitors.slice(0, 20).map(v => (
              <div key={v.id} className="card-section py-2.5 flex items-center gap-2">
                <div className={`w-1.5 h-1.5 rounded-full ${v.exitTime ? 'bg-muted-foreground' : 'bg-success'}`} />
                <div className="flex-1 min-w-0">
                  <p className="text-xs font-medium truncate">{v.name} · Flat {v.flatNumber}</p>
                  <p className="text-[10px] text-muted-foreground">{v.category} · {format(new Date(v.entryTime), 'hh:mm a')}</p>
                </div>
              </div>
            ))}
            {dayVisitors.length > 20 && (
              <p className="text-xs text-muted-foreground text-center py-2">+{dayVisitors.length - 20} more — use Print/CSV for full list</p>
            )}
          </div>
        )}
      </div>
    </div>
  );
};

export default ReportPage;
