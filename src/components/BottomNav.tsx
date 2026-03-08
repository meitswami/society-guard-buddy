import type { TabType } from '@/types';
import { LayoutDashboard, UserPlus, Car, Truck, FileText, Zap, BookUser } from 'lucide-react';

interface Props {
  activeTab: TabType;
  onTabChange: (tab: TabType) => void;
}

const tabs: { id: TabType; label: string; icon: React.ElementType }[] = [
  { id: 'dashboard', label: 'Home', icon: LayoutDashboard },
  { id: 'quick', label: 'Quick', icon: Zap },
  { id: 'visitor', label: 'Visitor', icon: UserPlus },
  { id: 'delivery', label: 'Delivery', icon: Truck },
  { id: 'vehicle', label: 'Vehicles', icon: Car },
  { id: 'directory', label: 'Directory', icon: BookUser },
  { id: 'logs', label: 'Logs', icon: FileText },
];

const BottomNav = ({ activeTab, onTabChange }: Props) => {
  return (
    <nav className="fixed bottom-0 left-0 right-0 bg-card border-t border-border z-50">
      <div className="max-w-lg mx-auto flex items-center overflow-x-auto gap-1 py-2 pb-[max(0.5rem,env(safe-area-inset-bottom))] px-1 scrollbar-hide">
        {tabs.map(tab => {
          const Icon = tab.icon;
          const isActive = activeTab === tab.id;
          return (
            <button
              key={tab.id}
              onClick={() => onTabChange(tab.id)}
              className={`${isActive ? 'nav-item-active' : 'nav-item'} min-w-[3.5rem] flex-1`}
            >
              <Icon className="w-5 h-5" />
              <span className="text-[10px] font-medium">{tab.label}</span>
            </button>
          );
        })}
      </div>
    </nav>
  );
};

export default BottomNav;
