import { useEffect, useMemo, useState } from 'react';
import {
  BarChart3,
  Bell,
  BookUser,
  Building2,
  Calendar,
  Car,
  ClipboardList,
  Crown,
  Database,
  DollarSign,
  FileText,
  Fingerprint,
  Heart,
  Home,
  KeyRound,
  LayoutDashboard,
  MapPin,
  ParkingSquare,
  Settings,
  Shield,
  ShieldAlert,
  Sparkles,
  Split,
  Tag,
  Truck,
  User,
  UserPlus,
  Users,
  Vote,
  Zap,
  type LucideIcon,
} from 'lucide-react';
import type { TourIconName, TourStepSpec } from '@/lib/tourGuide';

const ICON_MAP: Record<TourIconName, LucideIcon> = {
  sparkles: Sparkles,
  layoutDashboard: LayoutDashboard,
  zap: Zap,
  userPlus: UserPlus,
  truck: Truck,
  car: Car,
  shieldAlert: ShieldAlert,
  bookUser: BookUser,
  settings: Settings,
  home: Home,
  bell: Bell,
  keyRound: KeyRound,
  users: Users,
  dollar: DollarSign,
  vote: Vote,
  user: User,
  shield: Shield,
  mapPin: MapPin,
  fingerprint: Fingerprint,
  clipboard: ClipboardList,
  barChart: BarChart3,
  fileText: FileText,
  crown: Crown,
  building: Building2,
  tag: Tag,
  database: Database,
  heart: Heart,
  calendar: Calendar,
  parking: ParkingSquare,
  split: Split,
};

type TFn = (key: string) => string;

type Props = {
  open: boolean;
  steps: TourStepSpec[];
  initialIndex?: number;
  onClose: () => void;
  onFinished?: () => void;
  /** When true, finishing or skipping calls onFinished */
  persistOnSkip?: boolean;
  t: TFn;
};

const TourGuideOverlay = ({
  open,
  steps,
  initialIndex = 0,
  onClose,
  onFinished,
  persistOnSkip = false,
  t,
}: Props) => {
  const [index, setIndex] = useState(initialIndex);

  useEffect(() => {
    if (open) setIndex(Math.min(initialIndex, Math.max(0, steps.length - 1)));
  }, [open, initialIndex, steps.length]);

  const step = steps[index];
  const Icon = useMemo(() => (step ? ICON_MAP[step.icon] ?? Sparkles : Sparkles), [step]);
  const last = steps.length - 1;
  const safe = steps.length > 0;

  if (!open || !safe || !step) return null;

  const finish = (skipped: boolean) => {
    if (persistOnSkip || !skipped) onFinished?.();
    onClose();
  };

  return (
    <div
      className="fixed inset-0 z-[200] flex items-center justify-center p-4 bg-background/75 backdrop-blur-md animate-in fade-in duration-200"
      role="dialog"
      aria-modal="true"
      aria-labelledby="tour-step-title"
    >
      <div className="absolute inset-0" onClick={() => finish(true)} aria-hidden />

      <div className="relative w-full max-w-md overflow-hidden rounded-2xl border border-primary/25 bg-card shadow-2xl shadow-primary/15 ring-1 ring-primary/20 animate-in zoom-in-95 duration-200">
        <div className="pointer-events-none absolute -right-16 -top-16 h-40 w-40 rounded-full bg-primary/20 blur-3xl" />
        <div className="pointer-events-none absolute -bottom-12 -left-10 h-32 w-32 rounded-full bg-violet-500/15 blur-2xl" />

        <div className="relative px-5 pt-6 pb-5">
          <div className="mb-4 flex items-center justify-between gap-2">
            <span className="rounded-full bg-primary/10 px-2.5 py-0.5 text-[10px] font-semibold uppercase tracking-wider text-primary">
              {t('tour.badge')}
            </span>
            <span className="text-[11px] font-medium text-muted-foreground tabular-nums">
              {index + 1} / {steps.length}
            </span>
          </div>

          <div className="mb-5 flex justify-center">
            <div className="rounded-2xl bg-gradient-to-br from-primary/20 to-violet-500/10 p-4 ring-1 ring-primary/20">
              <Icon className="h-10 w-10 text-primary" strokeWidth={1.75} />
            </div>
          </div>

          <h2 id="tour-step-title" className="mb-2 text-center text-lg font-semibold leading-snug text-foreground">
            {t(step.titleKey)}
          </h2>
          <p className="text-center text-sm leading-relaxed text-muted-foreground">{t(step.bodyKey)}</p>

          <div className="mt-5 flex justify-center gap-1.5">
            {steps.map((_, i) => (
              <span
                key={i}
                className={`h-1.5 rounded-full transition-all ${i === index ? 'w-6 bg-primary' : 'w-1.5 bg-muted-foreground/30'}`}
              />
            ))}
          </div>

          <div className="mt-6 flex flex-wrap items-center justify-end gap-2 border-t border-border pt-4">
            <button
              type="button"
              className="rounded-xl px-4 py-2.5 text-sm font-medium text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
              onClick={() => finish(true)}
            >
              {t('tour.skip')}
            </button>
            {index < last ? (
              <button type="button" className="btn-primary rounded-xl px-5 py-2.5 text-sm font-semibold" onClick={() => setIndex((i) => i + 1)}>
                {t('tour.next')}
              </button>
            ) : (
              <button type="button" className="btn-primary rounded-xl px-5 py-2.5 text-sm font-semibold" onClick={() => finish(false)}>
                {t('tour.done')}
              </button>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

export default TourGuideOverlay;
