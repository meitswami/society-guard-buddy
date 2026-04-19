import type { TabType } from '@/types';
import { useCallback, useEffect, useRef, useState } from 'react';
import { LayoutDashboard, UserPlus, Car, Truck, FileText, Zap, BookUser, ShieldAlert, BarChart3, Settings, ChevronLeft, ChevronRight, Sparkles } from 'lucide-react';
import { useLanguage } from '@/i18n/LanguageContext';

interface Props {
  activeTab: TabType;
  onTabChange: (tab: TabType) => void;
  guardTabs?: TabType[];
}

const allTabs: { id: TabType; labelKey: string; icon: React.ElementType }[] = [
  { id: 'dashboard', labelKey: 'nav.home', icon: LayoutDashboard },
  { id: 'quick', labelKey: 'nav.quick', icon: Zap },
  { id: 'visitor', labelKey: 'nav.visitor', icon: UserPlus },
  { id: 'delivery', labelKey: 'nav.delivery', icon: Truck },
  { id: 'vehicle', labelKey: 'nav.vehicles', icon: Car },
  { id: 'blacklist', labelKey: 'nav.blacklist', icon: ShieldAlert },
  { id: 'directory', labelKey: 'nav.directory', icon: BookUser },
  { id: 'report', labelKey: 'nav.report', icon: BarChart3 },
  { id: 'logs', labelKey: 'nav.logs', icon: FileText },
  { id: 'settings', labelKey: 'nav.settings', icon: Settings },
  { id: 'tour', labelKey: 'nav.tour', icon: Sparkles },
];

const BottomNav = ({ activeTab, onTabChange, guardTabs }: Props) => {
  const { t } = useLanguage();
  const visibleTabs = guardTabs ? allTabs.filter(tab => guardTabs.includes(tab.id)) : allTabs;
  const scrollRef = useRef<HTMLDivElement | null>(null);
  const [showLeftArrow, setShowLeftArrow] = useState(false);
  const [showRightArrow, setShowRightArrow] = useState(false);

  const updateArrowVisibility = useCallback(() => {
    const container = scrollRef.current;
    if (!container) return;

    const hasOverflow = container.scrollWidth > container.clientWidth + 4;
    if (!hasOverflow) {
      setShowLeftArrow(false);
      setShowRightArrow(false);
      return;
    }

    setShowLeftArrow(container.scrollLeft > 8);
    setShowRightArrow(container.scrollLeft + container.clientWidth < container.scrollWidth - 8);
  }, []);

  const handleArrowScroll = useCallback((direction: 'left' | 'right') => {
    const container = scrollRef.current;
    if (!container) return;

    const scrollStep = Math.max(container.clientWidth * 0.45, 120);
    container.scrollBy({
      left: direction === 'left' ? -scrollStep : scrollStep,
      behavior: 'smooth',
    });
  }, []);

  useEffect(() => {
    const container = scrollRef.current;
    if (!container) return;

    updateArrowVisibility();
    container.addEventListener('scroll', updateArrowVisibility, { passive: true });
    window.addEventListener('resize', updateArrowVisibility);

    return () => {
      container.removeEventListener('scroll', updateArrowVisibility);
      window.removeEventListener('resize', updateArrowVisibility);
    };
  }, [updateArrowVisibility, visibleTabs.length]);

  return (
    <nav className="fixed bottom-0 left-0 right-0 bg-card border-t border-border z-50">
      <div className="max-w-lg mx-auto relative">
        {showLeftArrow && (
          <button
            type="button"
            aria-label="Scroll left"
            onClick={() => handleArrowScroll('left')}
            className="absolute left-0 top-1/2 -translate-y-1/2 z-20 h-8 w-8 rounded-full border border-border bg-card/95 text-foreground shadow-sm flex items-center justify-center"
          >
            <ChevronLeft className="h-5 w-5" />
          </button>
        )}
        {showRightArrow && (
          <button
            type="button"
            aria-label="Scroll right"
            onClick={() => handleArrowScroll('right')}
            className="absolute right-0 top-1/2 -translate-y-1/2 z-20 h-8 w-8 rounded-full border border-border bg-card/95 text-foreground shadow-sm flex items-center justify-center"
          >
            <ChevronRight className="h-5 w-5" />
          </button>
        )}
        <div
          ref={scrollRef}
          className="flex items-center overflow-x-auto gap-0 py-2 pb-[max(0.5rem,env(safe-area-inset-bottom))] px-1 scrollbar-hide"
        >
          {visibleTabs.map(tab => {
            const Icon = tab.icon;
            const isActive = activeTab === tab.id;
            return (
              <button
                key={tab.id}
                onClick={() => onTabChange(tab.id)}
                className={`${isActive ? 'nav-item-active' : 'nav-item'} min-w-[4.25rem] flex-1`}
              >
                <Icon className="w-5 h-5" />
                <span className="text-[11px] font-medium leading-tight">{t(tab.labelKey)}</span>
              </button>
            );
          })}
        </div>
      </div>
      <p className="text-center text-[8px] text-muted-foreground pb-1">{t('app.footer')}</p>
    </nav>
  );
};

export default BottomNav;
