import { useMemo, useState, type ComponentType, type ReactNode } from 'react';
import { Link } from 'react-router-dom';
import { toast } from 'sonner';
import {
  ArrowLeft,
  Building2,
  Hash,
  Home,
  Layers,
  LayoutGrid,
  Mail,
  MapPin,
  Phone,
  Shield,
  Sparkles,
  User,
} from 'lucide-react';
import { useLanguage } from '@/i18n/LanguageContext';
import LanguageToggle from '@/components/LanguageToggle';
import ThemeToggle from '@/components/ThemeToggle';
import { phonepeInitOrder, type SocietySignupDraft } from '@/lib/phonepeClient';
import { cn } from '@/lib/utils';

const PRICE_INR = 8500;

function SignupField({
  id,
  label,
  icon: Icon,
  className,
  children,
}: {
  id: string;
  label: string;
  icon?: ComponentType<{ className?: string }>;
  className?: string;
  children: ReactNode;
}) {
  return (
    <div className={cn('flex flex-col gap-1.5', className)}>
      <label htmlFor={id} className="flex items-center gap-2 text-xs font-medium text-foreground">
        {Icon ? <Icon className="h-3.5 w-3.5 shrink-0 text-primary" aria-hidden /> : null}
        {label}
      </label>
      {children}
    </div>
  );
}

function SectionCard({
  step,
  stepLabel,
  title,
  icon: Icon,
  children,
  className,
}: {
  step: number;
  stepLabel: string;
  title: string;
  icon: ComponentType<{ className?: string }>;
  children: ReactNode;
  className?: string;
}) {
  return (
    <section
      className={cn(
        'motion-safe:animate-in motion-safe:fade-in motion-safe:slide-in-from-bottom-2 motion-safe:duration-500 motion-safe:fill-mode-both rounded-2xl border border-border/70 bg-card p-5 shadow-sm',
        className,
      )}
      style={{ animationDelay: `${Math.min(step, 4) * 70}ms` }}
    >
      <div className="mb-5 flex items-start gap-3">
        <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-xl bg-primary/12 text-primary ring-1 ring-primary/25">
          <Icon className="h-6 w-6" aria-hidden />
        </div>
        <div className="min-w-0 pt-0.5">
          <p className="text-[10px] font-semibold uppercase tracking-wider text-primary">{stepLabel}</p>
          <h2 className="text-base font-semibold leading-tight text-foreground">{title}</h2>
        </div>
      </div>
      <div className="grid gap-4 sm:grid-cols-2">{children}</div>
    </section>
  );
}

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

  const inputClass =
    'input-field w-full min-h-[44px] rounded-xl border-border/80 bg-background transition-shadow focus-visible:ring-2 focus-visible:ring-primary/30';

  return (
    <div className="min-h-screen bg-gradient-to-b from-muted/40 via-background to-background px-4 pb-28 pt-4 sm:px-6">
      <div className="mx-auto max-w-2xl">
        <div className="mb-6 flex items-center justify-between gap-3">
          <Link
            to="/"
            className="inline-flex items-center gap-2 rounded-xl border border-border bg-card px-3 py-2 text-xs font-medium text-muted-foreground transition hover:border-primary/30 hover:text-foreground"
          >
            <ArrowLeft className="h-4 w-4 shrink-0" />
            {t('login.backToSociety')}
          </Link>
          <div className="flex shrink-0 items-center gap-2">
            <LanguageToggle />
            <ThemeToggle />
          </div>
        </div>

        <header className="relative mb-8 overflow-hidden rounded-2xl border border-primary/20 bg-gradient-to-br from-primary/12 via-card to-cyan-500/[0.08] p-6 shadow-sm">
          <div
            className="pointer-events-none absolute -right-12 -top-12 h-40 w-40 rounded-full bg-primary/15 blur-3xl motion-safe:animate-pulse"
            aria-hidden
          />
          <div className="relative flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
            <div className="flex gap-4">
              <div className="flex h-14 w-14 shrink-0 items-center justify-center rounded-2xl bg-primary/20 text-primary ring-2 ring-primary/25 motion-safe:animate-in motion-safe:zoom-in-95 motion-safe:duration-500">
                <Sparkles className="h-7 w-7" aria-hidden />
              </div>
              <div>
                <h1 className="page-title text-2xl leading-tight">{t('signup.title')}</h1>
                <p className="mt-2 max-w-md text-sm leading-relaxed text-muted-foreground">{t('signup.subtitle')}</p>
                <p className="mt-2 text-[11px] leading-snug text-muted-foreground/90">{t('signup.requiredNote')}</p>
              </div>
            </div>
          </div>
        </header>

        <div className="flex flex-col gap-6">
          <SectionCard step={1} stepLabel={`${t('signup.step')} 1`} title={t('signup.societyDetails')} icon={Building2}>
            <SignupField id="su-name" label={t('signup.name')} icon={Building2}>
              <input
                id="su-name"
                className={inputClass}
                autoComplete="organization"
                value={f.society_name}
                onChange={(e) => setF({ ...f, society_name: e.target.value })}
              />
            </SignupField>
            <SignupField id="su-address" label={t('signup.address')} icon={MapPin} className="sm:col-span-2">
              <input
                id="su-address"
                className={inputClass}
                autoComplete="street-address"
                value={f.address ?? ''}
                onChange={(e) => setF({ ...f, address: e.target.value })}
              />
            </SignupField>
            <SignupField id="su-city" label={t('signup.city')} icon={Home}>
              <input
                id="su-city"
                className={inputClass}
                value={f.city ?? ''}
                onChange={(e) => setF({ ...f, city: e.target.value })}
              />
            </SignupField>
            <SignupField id="su-state" label={t('signup.state')} icon={MapPin}>
              <input
                id="su-state"
                className={inputClass}
                value={f.state ?? ''}
                onChange={(e) => setF({ ...f, state: e.target.value })}
              />
            </SignupField>
            <SignupField id="su-pin" label={t('signup.pincode')} icon={Hash}>
              <input
                id="su-pin"
                className={inputClass}
                inputMode="numeric"
                value={f.pincode ?? ''}
                onChange={(e) => setF({ ...f, pincode: e.target.value })}
              />
            </SignupField>
            <SignupField id="su-blocks" label={t('signup.blocks')} icon={LayoutGrid}>
              <input
                id="su-blocks"
                className={inputClass}
                value={f.blocks_csv ?? ''}
                onChange={(e) => setF({ ...f, blocks_csv: e.target.value })}
              />
            </SignupField>
            <SignupField id="su-floors" label={t('signup.totalFloors')} icon={Layers}>
              <input
                id="su-floors"
                className={inputClass}
                inputMode="numeric"
                value={f.total_floors ?? ''}
                onChange={(e) => setF({ ...f, total_floors: e.target.value })}
              />
            </SignupField>
            <SignupField id="su-fpf" label={t('signup.flatsPerFloor')} icon={LayoutGrid}>
              <input
                id="su-fpf"
                className={inputClass}
                inputMode="numeric"
                value={f.flats_per_floor ?? ''}
                onChange={(e) => setF({ ...f, flats_per_floor: e.target.value })}
              />
            </SignupField>
            <SignupField id="su-fs1" label={t('signup.flatSeriesFrom')} icon={Home}>
              <input
                id="su-fs1"
                className={inputClass}
                value={f.flat_series_start ?? ''}
                onChange={(e) => setF({ ...f, flat_series_start: e.target.value })}
              />
            </SignupField>
            <SignupField id="su-fs2" label={t('signup.flatSeriesTo')} icon={Home}>
              <input
                id="su-fs2"
                className={inputClass}
                value={f.flat_series_end ?? ''}
                onChange={(e) => setF({ ...f, flat_series_end: e.target.value })}
              />
            </SignupField>
          </SectionCard>

          <SectionCard step={2} stepLabel={`${t('signup.step')} 2`} title={t('signup.contactDetails')} icon={User}>
            <SignupField id="su-cp" label={t('signup.contactPerson')} icon={User}>
              <input
                id="su-cp"
                className={inputClass}
                autoComplete="name"
                value={f.contact_person ?? ''}
                onChange={(e) => setF({ ...f, contact_person: e.target.value })}
              />
            </SignupField>
            <SignupField id="su-cphone" label={t('signup.contactPhone')} icon={Phone}>
              <input
                id="su-cphone"
                className={inputClass}
                inputMode="tel"
                autoComplete="tel"
                value={f.contact_phone}
                onChange={(e) => setF({ ...f, contact_phone: e.target.value })}
              />
            </SignupField>
            <SignupField id="su-cemail" label={t('signup.contactEmail')} icon={Mail} className="sm:col-span-2">
              <input
                id="su-cemail"
                className={inputClass}
                type="email"
                autoComplete="email"
                value={f.contact_email ?? ''}
                onChange={(e) => setF({ ...f, contact_email: e.target.value })}
              />
            </SignupField>
            <SignupField id="su-ref" label={t('signup.referralOptional')} icon={Hash} className="sm:col-span-2">
              <input
                id="su-ref"
                className={inputClass}
                value={f.referral_code ?? ''}
                onChange={(e) => setF({ ...f, referral_code: e.target.value })}
              />
            </SignupField>
          </SectionCard>

          <SectionCard step={3} stepLabel={`${t('signup.step')} 3`} title={t('signup.adminCreds')} icon={Shield}>
            <SignupField id="su-admin" label={t('signup.adminId')} icon={Shield}>
              <input
                id="su-admin"
                className={inputClass}
                autoComplete="username"
                value={f.admin_id}
                onChange={(e) => setF({ ...f, admin_id: e.target.value })}
              />
            </SignupField>
            <SignupField id="su-pass" label={t('signup.adminPassword')} icon={Shield}>
              <input
                id="su-pass"
                className={inputClass}
                type="password"
                autoComplete="new-password"
                value={f.admin_password}
                onChange={(e) => setF({ ...f, admin_password: e.target.value })}
              />
            </SignupField>
          </SectionCard>
        </div>

        <div className="mt-8 space-y-3 rounded-2xl border border-primary/25 bg-card/80 p-5 shadow-lg shadow-primary/5 backdrop-blur-sm motion-safe:animate-in motion-safe:fade-in motion-safe:duration-700">
          <button
            type="button"
            className="btn-primary flex w-full items-center justify-center gap-2 py-4 text-base font-semibold shadow-md shadow-primary/25 transition hover:brightness-[1.03] active:scale-[0.99] disabled:pointer-events-none disabled:opacity-50"
            disabled={!canSubmit || loading}
            onClick={onPay}
          >
            {loading ? (
              t('signup.processing')
            ) : (
              <>
                <Sparkles className="h-5 w-5 shrink-0" aria-hidden />
                {t('signup.payNow')}
              </>
            )}
          </button>
          <p className="text-center text-[11px] text-muted-foreground">
            {`Price: ₹${PRICE_INR.toLocaleString('en-IN')}`}
          </p>
        </div>
      </div>
    </div>
  );
}
