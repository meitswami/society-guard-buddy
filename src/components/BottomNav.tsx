import type { TabType } from '@/types';
import { LayoutDashboard, UserPlus, Car, Truck, FileText, Zap, BookUser, ShieldAlert, BarChart3, Settings } from 'lucide-react';
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
];

const BottomNav = ({ activeTab, onTabChange, guardTabs }: Props) => {
  const { t } = useLanguage();
  const visibleTabs = guardTabs ? allTabs.filter(tab => guardTabs.includes(tab.id)) : allTabs;

  return (
    <nav className="fixed bottom-0 left-0 right-0 bg-card border-t border-border z-50">
      <div className="max-w-lg mx-auto flex items-center overflow-x-auto gap-0 py-2 pb-[max(0.5rem,env(safe-area-inset-bottom))] px-1 scrollbar-hide">
        {visibleTabs.map(tab => {
          const Icon = tab.icon;
          const isActive = activeTab === tab.id;
          return (
            <button
              key={tab.id}
              onClick={() => onTabChange(tab.id)}
              className={`${isActive ? 'nav-item-active' : 'nav-item'} min-w-[3rem] flex-1`}
            >
              <Icon className="w-4 h-4" />
              <span className="text-[9px] font-medium leading-tight">{t(tab.labelKey)}</span>
            </button>
          );
        })}
      </div>
      <p className="text-center text-[8px] text-muted-foreground pb-1">{t('app.footer')}</p>
    </nav>
  );
};

export default BottomNav;
