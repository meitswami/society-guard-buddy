import { useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { toast } from 'sonner';
import { useLanguage } from '@/i18n/LanguageContext';
import LanguageToggle from '@/components/LanguageToggle';
import ThemeToggle from '@/components/ThemeToggle';
import { phonepeInitOrder, type SocietySignupDraft } from '@/lib/phonepeClient';

const PRICE_INR = 8500;

export default function NewSocietySignupPage() {
  const { t } = useLanguage();
  const [loading, setLoading] = useState(false);
  const [f, setF] = useState<SocietySignupDraft>({
    society_name: '',
    address: '',
    city: '',
    state: '',
    pincode: '',
    blocks_csv: '',
    total_floors: '',
    flats_per_floor: '',
    flat_series_start: '',
    flat_series_end: '',
    contact_person: '',
    contact_phone: '',
    contact_email: '',
    referral_code: '',
    admin_id: '',
    admin_password: '',
  });

  const canSubmit = useMemo(() => {
    return !!(f.society_name.trim() && f.contact_phone.trim() && f.admin_id.trim() && f.admin_password.trim());
  }, [f]);

  const onPay = async () => {
    if (!canSubmit) return;
    setLoading(true);
    try {
      const res = await phonepeInitOrder({
        ...f,
        society_name: f.society_name.trim(),
        contact_phone: f.contact_phone.trim(),
        admin_id: f.admin_id.trim(),
        admin_password: f.admin_password.trim(),
      });
      if ((res as any).alreadyExists) {
        toast.message('Society already exists. No payment needed.');
        window.location.href = '/';
        return;
      }
      if (!res.redirectUrl) throw new Error('Missing redirect url');
      window.location.href = res.redirectUrl;
    } catch (e: any) {
      console.error(e);
      toast.error(t('signup.errorGeneric'));
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-background px-6 pb-24">
      <div className="max-w-2xl mx-auto">
        <div className="flex items-start justify-between pt-6 pb-4">
          <div>
            <h1 className="page-title">{t('signup.title')}</h1>
            <p className="text-sm text-muted-foreground mt-1">{t('signup.subtitle')}</p>
          </div>
          <div className="flex items-center gap-2">
            <LanguageToggle />
            <ThemeToggle />
          </div>
        </div>

        <div className="card-section p-4">
          <p className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-3">{t('signup.societyDetails')}</p>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-2">
            <input className="input-field" placeholder={t('signup.name')} value={f.society_name} onChange={(e) => setF({ ...f, society_name: e.target.value })} />
            <input className="input-field" placeholder={t('signup.address')} value={f.address ?? ''} onChange={(e) => setF({ ...f, address: e.target.value })} />
            <input className="input-field" placeholder={t('signup.city')} value={f.city ?? ''} onChange={(e) => setF({ ...f, city: e.target.value })} />
            <input className="input-field" placeholder={t('signup.state')} value={f.state ?? ''} onChange={(e) => setF({ ...f, state: e.target.value })} />
            <input className="input-field" placeholder={t('signup.pincode')} value={f.pincode ?? ''} onChange={(e) => setF({ ...f, pincode: e.target.value })} />
            <input className="input-field" placeholder={t('signup.blocks')} value={f.blocks_csv ?? ''} onChange={(e) => setF({ ...f, blocks_csv: e.target.value })} />
            <input className="input-field" inputMode="numeric" placeholder={t('signup.totalFloors')} value={f.total_floors ?? ''} onChange={(e) => setF({ ...f, total_floors: e.target.value })} />
            <input className="input-field" inputMode="numeric" placeholder={t('signup.flatsPerFloor')} value={f.flats_per_floor ?? ''} onChange={(e) => setF({ ...f, flats_per_floor: e.target.value })} />
            <input className="input-field" placeholder={t('signup.flatSeriesFrom')} value={f.flat_series_start ?? ''} onChange={(e) => setF({ ...f, flat_series_start: e.target.value })} />
            <input className="input-field" placeholder={t('signup.flatSeriesTo')} value={f.flat_series_end ?? ''} onChange={(e) => setF({ ...f, flat_series_end: e.target.value })} />
          </div>
        </div>

        <div className="card-section p-4 mt-3">
          <p className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-3">{t('signup.contactDetails')}</p>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-2">
            <input className="input-field" placeholder={t('signup.contactPerson')} value={f.contact_person ?? ''} onChange={(e) => setF({ ...f, contact_person: e.target.value })} />
            <input className="input-field" inputMode="tel" placeholder={t('signup.contactPhone')} value={f.contact_phone} onChange={(e) => setF({ ...f, contact_phone: e.target.value })} />
            <input className="input-field md:col-span-2" type="email" placeholder={t('signup.contactEmail')} value={f.contact_email ?? ''} onChange={(e) => setF({ ...f, contact_email: e.target.value })} />
            <input className="input-field md:col-span-2" placeholder={t('signup.referralOptional')} value={f.referral_code ?? ''} onChange={(e) => setF({ ...f, referral_code: e.target.value })} />
          </div>
        </div>

        <div className="card-section p-4 mt-3">
          <p className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-3">{t('signup.adminCreds')}</p>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-2">
            <input className="input-field" placeholder={t('signup.adminId')} value={f.admin_id} onChange={(e) => setF({ ...f, admin_id: e.target.value })} />
            <input className="input-field" type="password" placeholder={t('signup.adminPassword')} value={f.admin_password} onChange={(e) => setF({ ...f, admin_password: e.target.value })} />
          </div>
        </div>

        <div className="mt-4 flex flex-col gap-2">
          <button className="btn-primary w-full py-3" disabled={!canSubmit || loading} onClick={onPay}>
            {loading ? t('signup.processing') : t('signup.payNow')}
          </button>
          <p className="text-[11px] text-muted-foreground text-center">
            {`Price: ₹${PRICE_INR.toLocaleString('en-IN')}`}
          </p>
          <Link to="/" className="text-xs text-muted-foreground text-center underline">
            {t('login.backToSociety')}
          </Link>
        </div>
      </div>
    </div>
  );
}

