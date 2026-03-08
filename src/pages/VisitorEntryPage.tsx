import { useState, useMemo } from 'react';
import { useStore } from '@/store/useStore';
import type { Visitor } from '@/types';
import { UserPlus, Camera, ShieldAlert, Search } from 'lucide-react';
import { format } from 'date-fns';
import PhotoCapture from '@/components/PhotoCapture';

const DOC_TYPES = [
  { value: 'aadhaar', label: 'Aadhaar' },
  { value: 'driving_license', label: 'Driving License' },
  { value: 'passport', label: 'Passport' },
  { value: 'other', label: 'Other' },
] as const;

const PURPOSES = ['Visit', 'Delivery', 'Meeting', 'Maintenance', 'Guest', 'Other'];

const VisitorEntryPage = () => {
  const { addVisitor, visitors, currentGuard, isBlacklisted } = useStore();
  const [success, setSuccess] = useState(false);
  const [blacklistAlert, setBlacklistAlert] = useState(false);
  const [repeatAlert, setRepeatAlert] = useState<string | null>(null);
  const [hasVehicle, setHasVehicle] = useState(false);

  const [form, setForm] = useState({
    name: '',
    phone: '',
    documentType: 'aadhaar' as Visitor['documentType'],
    documentNumber: '',
    flatNumber: '',
    purpose: 'Visit',
    vehicleNumber: '',
  });

  const update = (field: string, value: string) => {
    setForm(f => ({ ...f, [field]: value }));

    if (field === 'phone' && value.length >= 10) {
      // Check blacklist
      if (isBlacklisted(value)) {
        setBlacklistAlert(true);
      } else {
        setBlacklistAlert(false);
      }

      // Check repeat visitor
      const today = format(new Date(), 'yyyy-MM-dd');
      const todayVisits = visitors.filter(v => v.phone === value && v.entryTime.startsWith(today));
      if (todayVisits.length > 0) {
        setRepeatAlert(`This visitor has already entered ${todayVisits.length}x today`);
      } else {
        setRepeatAlert(null);
      }

      // Auto-fill from previous visits
      const prev = visitors.find(v => v.phone === value);
      if (prev) {
        setForm(f => ({
          ...f,
          name: f.name || prev.name,
          documentType: prev.documentType,
          documentNumber: f.documentNumber || prev.documentNumber,
          flatNumber: f.flatNumber || prev.flatNumber,
        }));
      }
    }
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!form.name || !form.phone || !form.flatNumber) return;

    const visitor: Visitor = {
      id: `V${Date.now()}`,
      name: form.name,
      phone: form.phone,
      documentType: form.documentType,
      documentNumber: form.documentNumber,
      visitorPhotos: [],
      flatNumber: form.flatNumber,
      purpose: form.purpose,
      entryTime: new Date().toISOString(),
      guardId: currentGuard?.id || '',
      guardName: currentGuard?.name || '',
      category: 'visitor',
      vehicleNumber: hasVehicle ? form.vehicleNumber : undefined,
      vehicleEntryTime: hasVehicle && form.vehicleNumber ? new Date().toISOString() : undefined,
    };

    addVisitor(visitor);
    setSuccess(true);
    setForm({ name: '', phone: '', documentType: 'aadhaar', documentNumber: '', flatNumber: '', purpose: 'Visit', vehicleNumber: '' });
    setHasVehicle(false);
    setBlacklistAlert(false);
    setRepeatAlert(null);
    setTimeout(() => setSuccess(false), 2000);
  };

  // Phone-based suggestions
  const suggestions = useMemo(() => {
    if (form.phone.length < 4) return [];
    const seen = new Set<string>();
    return visitors
      .filter(v => v.phone.includes(form.phone) && !seen.has(v.phone) && (seen.add(v.phone), true))
      .slice(0, 3);
  }, [form.phone, visitors]);

  return (
    <div className="page-container">
      <div className="flex items-center gap-3 mb-6">
        <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
          <UserPlus className="w-5 h-5 text-primary" />
        </div>
        <div>
          <h1 className="page-title">New Visitor</h1>
          <p className="text-xs text-muted-foreground">Quick entry logging</p>
        </div>
      </div>

      {success && (
        <div className="card-section border-success/30 mb-4 text-center">
          <p className="text-success text-sm font-semibold">✓ Visitor logged successfully</p>
        </div>
      )}

      {blacklistAlert && (
        <div className="card-section border-destructive/50 mb-4 flex items-center gap-3">
          <ShieldAlert className="w-5 h-5 text-destructive flex-shrink-0" />
          <p className="text-destructive text-sm font-semibold">⚠ BLACKLISTED — This visitor is flagged!</p>
        </div>
      )}

      {repeatAlert && !blacklistAlert && (
        <div className="card-section border-warning/30 mb-4">
          <p className="text-warning text-sm font-medium">⚠ {repeatAlert}</p>
        </div>
      )}

      <form onSubmit={handleSubmit} className="flex flex-col gap-4">
        {/* Phone */}
        <div>
          <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1.5 block">Phone Number *</label>
          <input
            className="input-field font-mono"
            placeholder="10-digit number"
            type="tel"
            maxLength={10}
            value={form.phone}
            onChange={e => update('phone', e.target.value.replace(/\D/g, ''))}
          />
          {suggestions.length > 0 && form.phone.length >= 4 && form.phone.length < 10 && (
            <div className="mt-1 flex flex-wrap gap-1">
              {suggestions.map(s => (
                <button
                  key={s.id}
                  type="button"
                  className="text-xs bg-secondary px-2 py-1 rounded-md text-secondary-foreground"
                  onClick={() => {
                    setForm(f => ({
                      ...f,
                      phone: s.phone,
                      name: s.name,
                      documentType: s.documentType,
                      documentNumber: s.documentNumber,
                      flatNumber: s.flatNumber,
                    }));
                  }}
                >
                  <Search className="w-3 h-3 inline mr-1" />{s.name} · {s.phone}
                </button>
              ))}
            </div>
          )}
        </div>

        {/* Name */}
        <div>
          <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1.5 block">Full Name *</label>
          <input className="input-field" placeholder="Visitor name" value={form.name} onChange={e => update('name', e.target.value)} />
        </div>

        {/* Flat Number */}
        <div>
          <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1.5 block">Flat / House No. *</label>
          <input className="input-field font-mono" placeholder="e.g. 604" value={form.flatNumber} onChange={e => update('flatNumber', e.target.value)} />
        </div>

        {/* Purpose */}
        <div>
          <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1.5 block">Purpose</label>
          <div className="flex flex-wrap gap-2">
            {PURPOSES.map(p => (
              <button
                key={p}
                type="button"
                className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-all ${form.purpose === p ? 'bg-primary text-primary-foreground' : 'bg-secondary text-secondary-foreground'}`}
                onClick={() => update('purpose', p)}
              >
                {p}
              </button>
            ))}
          </div>
        </div>

        {/* Document */}
        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1.5 block">Doc Type</label>
            <select
              className="input-field"
              value={form.documentType}
              onChange={e => update('documentType', e.target.value)}
            >
              {DOC_TYPES.map(d => (
                <option key={d.value} value={d.value}>{d.label}</option>
              ))}
            </select>
          </div>
          <div>
            <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1.5 block">Doc Number</label>
            <input className="input-field font-mono text-xs" placeholder="ID number" value={form.documentNumber} onChange={e => update('documentNumber', e.target.value)} />
          </div>
        </div>

        {/* Vehicle Toggle */}
        <div className="flex items-center gap-3">
          <button
            type="button"
            className={`w-10 h-6 rounded-full transition-colors relative ${hasVehicle ? 'bg-primary' : 'bg-secondary'}`}
            onClick={() => setHasVehicle(!hasVehicle)}
          >
            <span className={`absolute top-1 w-4 h-4 rounded-full bg-foreground transition-all ${hasVehicle ? 'left-5' : 'left-1'}`} />
          </button>
          <span className="text-sm text-muted-foreground">Has vehicle</span>
        </div>

        {hasVehicle && (
          <div>
            <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1.5 block">Vehicle Number</label>
            <input className="input-field font-mono uppercase" placeholder="e.g. MH02AB1234" value={form.vehicleNumber} onChange={e => update('vehicleNumber', e.target.value.toUpperCase())} />
          </div>
        )}

        <button type="submit" className="btn-primary flex items-center justify-center gap-2 mt-2">
          <Camera className="w-4 h-4" />
          Log Entry
        </button>
      </form>
    </div>
  );
};

export default VisitorEntryPage;
