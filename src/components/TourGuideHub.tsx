import { useState } from 'react';
import { BookOpen, Sparkles } from 'lucide-react';
import type { AdminPanelPermissions } from '@/lib/adminPermissions';
import type { AppTourRole, TourChapterSpec } from '@/lib/tourGuide';
import { getTourChapters } from '@/lib/tourGuide';
import TourGuideOverlay from '@/components/TourGuideOverlay';

type TFn = (key: string) => string;

type Props = {
  role: AppTourRole;
  t: TFn;
  adminPermissions?: AdminPanelPermissions;
  className?: string;
};

/** In-app tour library: pick a topic, then step through with Next / Skip. */
const TourGuideHub = ({ role, t, adminPermissions, className = '' }: Props) => {
  const chapters = getTourChapters(role, adminPermissions);
  const [chapter, setChapter] = useState<TourChapterSpec | null>(null);

  return (
    <div className={`page-container pb-6 ${className}`}>
      <TourGuideOverlay
        open={!!chapter}
        steps={chapter?.steps ?? []}
        initialIndex={0}
        onClose={() => setChapter(null)}
        t={t}
      />

      <div className="relative mb-6 overflow-hidden rounded-2xl border border-primary/20 bg-gradient-to-br from-primary/12 via-card to-violet-500/10 p-5 shadow-lg">
        <Sparkles className="absolute right-3 top-3 h-16 w-16 text-primary/15" />
        <div className="relative">
          <p className="text-[11px] font-semibold uppercase tracking-wider text-primary">{t('tour.badge')}</p>
          <h1 className="mt-1 text-xl font-bold text-foreground">{t('tour.hubTitle')}</h1>
          <p className="mt-2 max-w-prose text-sm text-muted-foreground">{t('tour.hubSubtitle')}</p>
        </div>
      </div>

      <p className="mb-3 text-xs font-medium uppercase tracking-wide text-muted-foreground">{t('tour.pickTopic')}</p>
      <div className="grid gap-3 sm:grid-cols-2">
        {chapters.map((ch) => (
          <button
            key={ch.id}
            type="button"
            onClick={() => setChapter(ch)}
            className="group flex flex-col items-start gap-2 rounded-xl border border-border bg-card p-4 text-left transition-all hover:border-primary/40 hover:bg-primary/5 hover:shadow-md"
          >
            <div className="flex w-full items-start justify-between gap-2">
              <span className="flex h-9 w-9 items-center justify-center rounded-lg bg-primary/10 text-primary ring-1 ring-primary/15">
                <BookOpen className="h-4 w-4" />
              </span>
              <span className="rounded-md bg-muted px-2 py-0.5 text-[10px] font-medium text-muted-foreground">
                {ch.steps.length} {ch.steps.length === 1 ? t('tour.step') : t('tour.steps')}
              </span>
            </div>
            <span className="text-sm font-semibold text-foreground group-hover:text-primary">{t(ch.titleKey)}</span>
            <span className="text-xs text-muted-foreground">{t('tour.tapToView')}</span>
          </button>
        ))}
      </div>
    </div>
  );
};

export default TourGuideHub;
