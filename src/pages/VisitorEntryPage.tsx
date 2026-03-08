import { useState, useMemo } from 'react';
import { useStore } from '@/store/useStore';
import type { Visitor } from '@/types';
import { UserPlus, Camera, ShieldAlert, Search, Send, KeyRound } from 'lucide-react';
import { format } from 'date-fns';
import PhotoCapture from '@/components/PhotoCapture';
import { useLanguage } from '@/i18n/LanguageContext';
import { showSuccess } from '@/lib/swal';
import ApprovalRequestModal from '@/components/ApprovalRequestModal';
import OTPVerifyModal from '@/components/OTPVerifyModal';

const DOC_TYPES = [
  { value: 'aadhaar', label: 'Aadhaar' },
  { value: 'driving_license', label: 'Driving License' },
  { value: 'passport', label: 'Passport' },
  { value: 'other', label: 'Other' },
] as const;

const PURPOSE_KEYS = ['purpose.visit', 'purpose.delivery', 'purpose.meeting', 'purpose.maintenance', 'purpose.guest', 'purpose.other'];
const PURPOSE_VALUES = ['Visit', 'Delivery', 'Meeting', 'Maintenance', 'Guest', 'Other'];

interface Props { onDone?: () => void; }

const VisitorEntryPage = ({ onDone }: Props) => {
  const { addVisitor, visitors, currentGuard, isBlacklisted } = useStore();
  const { t } = useLanguage();
  const [blacklistAlert, setBlacklistAlert] = useState(false);
  const [repeatAlert, setRepeatAlert] = useState<string | null>(null);
  const [hasVehicle, setHasVehicle] = useState(false);
  const [visitorPhotos, setVisitorPhotos] = useState<string[]>([]);
  const [documentPhoto, setDocumentPhoto] = useState<string[]>([]);
  const [showApproval, setShowApproval] = useState(false);
  const [showOTP, setShowOTP] = useState(false);
  const [form, setForm] = useState({
    name: '', phone: '', documentType: 'aadhaar' as Visitor['documentType'],
    documentNumber: '', flatNumber: '', purpose: 'Visit', vehicleNumber: '',
  });

  const update = (field: string, value: string) => {
    setForm(f => ({ ...f, [field]: value }));
    if (field === 'phone' && value.length >= 10) {
      if (isBlacklisted(value)) { setBlacklistAlert(true); } else { setBlacklistAlert(false); }
      const today = format(new Date(), 'yyyy-MM-dd');
      const todayVisits = visitors.filter(v => v.phone === value && v.entryTime.startsWith(today));
      if (todayVisits.length > 0) {
        setRepeatAlert(`${t('visitor.repeatAlert')} ${todayVisits.length}${t('visitor.timesToday')}`);
      } else { setRepeatAlert(null); }
      const prev = visitors.find(v => v.phone === value);
      if (prev) {
        setForm(f => ({
          ...f, name: f.name || prev.name, documentType: prev.documentType,
          documentNumber: f.documentNumber || prev.documentNumber, flatNumber: f.flatNumber || prev.flatNumber,
        }));
      }
    }
  };

  const registerVisitor = async (overrideName?: string, overrideFlat?: string, overridePhone?: string) => {
    const name = overrideName || form.name;
    const flatNumber = overrideFlat || form.flatNumber;
    const phone = overridePhone || form.phone;
    if (!name || !phone || !flatNumber) return;

    const visitor: Visitor = {
      id: `V${Date.now()}`, name, phone,
      documentType: form.documentType, documentNumber: form.documentNumber,
      documentPhoto: documentPhoto[0], visitorPhotos, flatNumber,
      purpose: form.purpose, entryTime: new Date().toISOString(),
      guardId: currentGuard?.id || '', guardName: currentGuard?.name || '',
      category: 'visitor', vehicleNumber: hasVehicle ? form.vehicleNumber : undefined,
      vehicleEntryTime: hasVehicle && form.vehicleNumber ? new Date().toISOString() : undefined,
    };
    await addVisitor(visitor);
    showSuccess(t('swal.success'), t('swal.visitorRegistered'));
    setForm({ name: '', phone: '', documentType: 'aadhaar', documentNumber: '', flatNumber: '', purpose: 'Visit', vehicleNumber: '' });
    setHasVehicle(false); setBlacklistAlert(false); setRepeatAlert(null);
    setVisitorPhotos([]); setDocumentPhoto([]);
    if (onDone) setTimeout(() => onDone(), 1600);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    await registerVisitor();
  };

  const handleApprovalResult = (status: 'approved' | 'rejected' | 'timeout') => {
    setShowApproval(false);
    if (status === 'approved') {
      registerVisitor();
    }
  };

  const handleOTPResult = (valid: boolean, passData?: { guestName: string; flatNumber: string; guestPhone: string }) => {
    setShowOTP(false);
    if (valid && passData) {
      showSuccess(t('swal.success'), t('otp.validPass'));
      registerVisitor(passData.guestName, passData.flatNumber, passData.guestPhone || '0000000000');
    }
  };

  const suggestions = useMemo(() => {
    if (form.phone.length < 4) return [];
    const seen = new Set<string>();
    return visitors
      .filter(v => v.phone.includes(form.phone) && !seen.has(v.phone) && (seen.add(v.phone), true))
      .slice(0, 3);
  }, [form.phone, visitors]);

  return (
    <div className="page-container">
      {showApproval && (
        <ApprovalRequestModal
          visitorName={form.name}
          visitorPhone={form.phone}
          flatNumber={form.flatNumber}
          purpose={form.purpose}
          onResult={handleApprovalResult}
          onCancel={() => setShowApproval(false)}
        />
      )}
      {showOTP && (
        <OTPVerifyModal
          onResult={handleOTPResult}
          onCancel={() => setShowOTP(false)}
        />
      )}

      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
            <UserPlus className="w-5 h-5 text-primary" />
          </div>
          <div>
            <h1 className="page-title">{t('visitor.title')}</h1>
            <p className="text-xs text-muted-foreground">{t('visitor.subtitle')}</p>
          </div>
        </div>
        <button onClick={() => setShowOTP(true)}
          className="flex items-center gap-1.5 px-3 py-2 rounded-lg bg-accent text-accent-foreground text-xs font-medium">
          <KeyRound className="w-3.5 h-3.5" /> {t('otp.verifyPass')}
        </button>
      </div>

      {blacklistAlert && (
        <div className="card-section border-destructive/50 mb-4 flex items-center gap-3">
          <ShieldAlert className="w-5 h-5 text-destructive flex-shrink-0" />
          <p className="text-destructive text-sm font-semibold">⚠ {t('visitor.blacklisted')}</p>
        </div>
      )}
      {repeatAlert && !blacklistAlert && (
        <div className="card-section border-warning/30 mb-4">
          <p className="text-warning text-sm font-medium">⚠ {repeatAlert}</p>
        </div>
      )}

      <form onSubmit={handleSubmit} className="flex flex-col gap-4">
        <div>
          <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1.5 block">{t('visitor.phoneNumber')} *</label>
          <input className="input-field font-mono" placeholder="10-digit number" type="tel" maxLength={10}
            value={form.phone} onChange={e => update('phone', e.target.value.replace(/\D/g, ''))} />
          {suggestions.length > 0 && form.phone.length >= 4 && form.phone.length < 10 && (
            <div className="mt-1 flex flex-wrap gap-1">
              {suggestions.map(s => (
                <button key={s.id} type="button" className="text-xs bg-secondary px-2 py-1 rounded-md text-secondary-foreground"
                  onClick={() => setForm(f => ({ ...f, phone: s.phone, name: s.name, documentType: s.documentType, documentNumber: s.documentNumber, flatNumber: s.flatNumber }))}>
                  <Search className="w-3 h-3 inline mr-1" />{s.name} · {s.phone}
                </button>
              ))}
            </div>
          )}
        </div>

        <div>
          <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1.5 block">{t('visitor.fullName')} *</label>
          <input className="input-field" placeholder={t('visitor.fullName')} value={form.name} onChange={e => update('name', e.target.value)} />
        </div>

        <div>
          <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1.5 block">{t('visitor.flatNumber')} *</label>
          <input className="input-field font-mono" placeholder="e.g. 604" value={form.flatNumber} onChange={e => update('flatNumber', e.target.value)} />
        </div>

        <div>
          <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1.5 block">{t('visitor.purpose')}</label>
          <div className="flex flex-wrap gap-2">
            {PURPOSE_VALUES.map((p, i) => (
              <button key={p} type="button"
                className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-all ${form.purpose === p ? 'bg-primary text-primary-foreground' : 'bg-secondary text-secondary-foreground'}`}
                onClick={() => update('purpose', p)}>
                {t(PURPOSE_KEYS[i])}
              </button>
            ))}
          </div>
        </div>

        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1.5 block">{t('visitor.docType')}</label>
            <select className="input-field" value={form.documentType} onChange={e => update('documentType', e.target.value)}>
              {DOC_TYPES.map(d => (<option key={d.value} value={d.value}>{d.label}</option>))}
            </select>
          </div>
          <div>
            <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1.5 block">{t('visitor.docNumber')}</label>
            <input className="input-field font-mono text-xs" placeholder="ID number" value={form.documentNumber} onChange={e => update('documentNumber', e.target.value)} />
          </div>
        </div>

        <PhotoCapture photos={visitorPhotos} onChange={setVisitorPhotos} maxPhotos={3} label={t('visitor.visitorPhotos')} />
        <PhotoCapture photos={documentPhoto} onChange={setDocumentPhoto} maxPhotos={1} label={t('visitor.documentPhoto')} />

        <div className="flex items-center gap-3">
          <button type="button" className={`w-10 h-6 rounded-full transition-colors relative ${hasVehicle ? 'bg-primary' : 'bg-secondary'}`}
            onClick={() => setHasVehicle(!hasVehicle)}>
            <span className={`absolute top-1 w-4 h-4 rounded-full bg-foreground transition-all ${hasVehicle ? 'left-5' : 'left-1'}`} />
          </button>
          <span className="text-sm text-muted-foreground">{t('visitor.hasVehicle')}</span>
        </div>

        {hasVehicle && (
          <div>
            <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1.5 block">{t('visitor.vehicleNumber')}</label>
            <input className="input-field font-mono uppercase" placeholder="e.g. MH02AB1234" value={form.vehicleNumber} onChange={e => update('vehicleNumber', e.target.value.toUpperCase())} />
          </div>
        )}

        {/* Action buttons */}
        <div className="flex gap-2 mt-2">
          {form.name && form.flatNumber && (
            <button type="button" onClick={() => setShowApproval(true)}
              className="flex-1 flex items-center justify-center gap-2 py-3 rounded-xl bg-accent text-accent-foreground font-medium text-sm">
              <Send className="w-4 h-4" /> {t('approval.askPermission')}
            </button>
          )}
          <button type="submit" className="flex-1 btn-primary flex items-center justify-center gap-2">
            <Camera className="w-4 h-4" /> {t('visitor.logEntry')}
          </button>
        </div>
      </form>
    </div>
  );
};

export default VisitorEntryPage;
