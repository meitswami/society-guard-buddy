import { useState } from 'react';
import {
  LayoutDashboard,
  Zap,
  UserPlus,
  Truck,
  Car,
  BookUser,
  Sparkles,
  X,
} from 'lucide-react';
import { useLanguage } from '@/i18n/LanguageContext';
import TourGuideHub from '@/components/TourGuideHub';
import { toast } from 'sonner';

const PREVIEW_TILES = [
  { id: 'home', labelKey: 'nav.home', icon: LayoutDashboard },
  { id: 'quick', labelKey: 'nav.quick', icon: Zap },
  { id: 'visitor', labelKey: 'nav.visitor', icon: UserPlus },
  { id: 'delivery', labelKey: 'nav.delivery', icon: Truck },
  { id: 'vehicle', labelKey: 'nav.vehicles', icon: Car },
  { id: 'directory', labelKey: 'nav.directory', icon: BookUser },
] as const;

type Props = {
  /** Compact strip on login form vs full-screen overlay */
  variant?: 'inline' | 'fullscreen';
  onClose?: () => void;
};

const GuardLoginPreview = ({ variant = 'inline', onClose }: Props) => {
  const { t } = useLanguage();
  const [showTour, setShowTour] = useState(false);

  if (showTour) {
    return (
      <div className="fixed inset-0 z-[60] flex flex-col bg-background">
        <div className="flex items-center justify-between border-b border-border px-4 py-3 safe-area-inset-top">
          <h2 className="text-sm font-semibold">{t('guard.preview.tourTitle')}</h2>
          <button
            type="button"
            onClick={() => setShowTour(false)}
            className="rounded-lg p-2 text-muted-foreground hover:bg-muted"
            aria-label={t('guard.preview.close')}
          >
            <X className="h-5 w-5" />
          </button>
        </div>
        <div className="flex-1 overflow-auto">
          <TourGuideHub role="guard" t={t} />
        </div>
      </div>
    );
  }

  const grid = (
    <>
      <p className="text-xs font-medium text-foreground">{t('guard.preview.title')}</p>
      <p className="text-[10px] text-muted-foreground mt-0.5 leading-snug">{t('guard.preview.hint')}</p>
      <div className="grid grid-cols-4 gap-2 mt-3">
        {PREVIEW_TILES.map((tile) => {
          const Icon = tile.icon;
          return (
            <button
              key={tile.id}
              type="button"
              onClick={() => toast.message(t('guard.preview.signInToUse'))}
              className="card-section p-2.5 flex flex-col items-center gap-1 min-h-[72px] hover:bg-primary/5 transition-colors"
            >
              <Icon className="w-5 h-5 text-primary shrink-0" />
              <span className="text-[9px] text-muted-foreground leading-tight text-center line-clamp-2">
                {t(tile.labelKey)}
              </span>
            </button>
          );
        })}
        <button
          type="button"
          onClick={() => setShowTour(true)}
          className="card-section p-2.5 flex flex-col items-center gap-1 min-h-[72px] border-primary/30 bg-primary/5 hover:bg-primary/10 transition-colors"
        >
          <Sparkles className="w-5 h-5 text-primary shrink-0" />
          <span className="text-[9px] text-primary font-medium leading-tight text-center">{t('nav.tour')}</span>
        </button>
      </div>
    </>
  );

  if (variant === 'fullscreen') {
    return (
      <div className="fixed inset-0 z-[60] flex flex-col bg-background">
        <div className="flex items-center justify-between border-b border-border px-4 py-3">
          <h2 className="text-sm font-semibold">{t('guard.preview.title')}</h2>
          {onClose && (
            <button
              type="button"
              onClick={onClose}
              className="rounded-lg p-2 text-muted-foreground hover:bg-muted"
              aria-label={t('guard.preview.close')}
            >
              <X className="h-5 w-5" />
            </button>
          )}
        </div>
        <div className="flex-1 overflow-auto p-4 page-container">{grid}</div>
      </div>
    );
  }

  return <div className="card-section p-3 mb-4">{grid}</div>;
};

export default GuardLoginPreview;
