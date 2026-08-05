import { useState, useCallback } from 'react';
import { LayoutGrid, List, ChevronRight } from 'lucide-react';
import type { AdminTab } from '@/lib/adminPermissions';
import type { AdminTabDef } from '@/lib/adminNavigation';
import { ADMIN_BOTTOM_NAV_TABS } from '@/lib/adminNavigation';
import { useLanguage } from '@/i18n/LanguageContext';

type ViewMode = 'list' | 'grid';

interface Props {
  tabs: AdminTabDef[];
  activeTab: AdminTab;
  onSelectTab: (tab: AdminTab) => void;
}

const AdminModuleDrawer = ({ tabs, activeTab, onSelectTab }: Props) => {
  const { t } = useLanguage();
  const [open, setOpen] = useState(false);
  const [viewMode, setViewMode] = useState<ViewMode>('list');

  const drawerTabs = tabs.filter((tab) => !ADMIN_BOTTOM_NAV_TABS.includes(tab.id));

  const closeDrawer = useCallback(() => setOpen(false), []);
  const toggleDrawer = useCallback(() => setOpen((v) => !v), []);

  if (drawerTabs.length === 0) return null;

  return (
    <>
      {/* Backdrop — only while open; closes on intentional dismiss */}
      {open && (
        <button
          type="button"
          className="fixed inset-0 z-[59] bg-black/25 border-0 cursor-default"
          aria-label="Close modules menu"
          onClick={closeDrawer}
        />
      )}

      <div className="fixed left-0 top-0 bottom-16 z-[60] flex pointer-events-none">
      {/* Edge tab — visible only as a slim control; panel stays hidden until clicked */}
      <div
        className={`pointer-events-auto w-7 shrink-0 transition-colors duration-200 cursor-pointer touch-manipulation ${
          open
            ? 'bg-primary shadow-[2px_0_12px_hsl(var(--primary)/0.35)]'
            : 'bg-primary/55 hover:bg-primary/80 active:bg-primary'
        }`}
        onClick={toggleDrawer}
        role="button"
        aria-expanded={open}
        aria-label={t('adminNav.allModules')}
        tabIndex={0}
        onKeyDown={(e) => {
          if (e.key === 'Enter' || e.key === ' ') {
            e.preventDefault();
            toggleDrawer();
          }
        }}
      >
        <div className="h-full flex items-center justify-center">
          <ChevronRight
            className={`w-4 h-4 text-primary-foreground transition-transform duration-200 ${
              open ? 'rotate-180' : ''
            }`}
          />
        </div>
      </div>

      {/* Sliding panel — hidden (w-0) until intentionally opened */}
      <aside
        className={`pointer-events-auto bg-card border-r border-border shadow-xl transition-all duration-200 overflow-hidden ${
          open ? 'w-64 opacity-100' : 'w-0 opacity-0 pointer-events-none'
        }`}
        aria-label={t('adminNav.allModules')}
        aria-hidden={!open}
      >
        <div className="w-64 h-full flex flex-col pt-[max(0.5rem,env(safe-area-inset-top))] pb-2">
          <div className="px-3 py-2 border-b border-border flex items-center justify-between gap-2">
            <p className="text-[10px] font-semibold uppercase tracking-wider text-primary">{t('adminNav.allModules')}</p>
            <div className="flex rounded-lg border border-border overflow-hidden">
              <button
                type="button"
                title="Scroll list"
                onClick={() => setViewMode('list')}
                className={`p-1.5 ${viewMode === 'list' ? 'bg-primary/15 text-primary' : 'text-muted-foreground hover:bg-muted/50'}`}
              >
                <List className="w-3.5 h-3.5" />
              </button>
              <button
                type="button"
                title="Grid view"
                onClick={() => setViewMode('grid')}
                className={`p-1.5 ${viewMode === 'grid' ? 'bg-primary/15 text-primary' : 'text-muted-foreground hover:bg-muted/50'}`}
              >
                <LayoutGrid className="w-3.5 h-3.5" />
              </button>
            </div>
          </div>

          <div
            className={`flex-1 overflow-y-auto px-2 py-2 scrollbar-hide ${
              viewMode === 'grid' ? 'grid grid-cols-2 gap-1.5 content-start' : 'space-y-0.5'
            }`}
          >
            {drawerTabs.map((tab) => {
              const Icon = tab.icon;
              const isActive = activeTab === tab.id;
              if (viewMode === 'grid') {
                return (
                  <button
                    key={tab.id}
                    type="button"
                    onClick={() => {
                      onSelectTab(tab.id);
                      closeDrawer();
                    }}
                    className={`flex flex-col items-center gap-1 p-2 rounded-lg text-center min-h-[64px] transition-colors ${
                      isActive
                        ? 'bg-primary/15 text-primary ring-1 ring-primary/40'
                        : 'hover:bg-muted/60 text-foreground'
                    }`}
                  >
                    <Icon className="w-4 h-4 shrink-0" />
                    <span className="text-[9px] leading-tight line-clamp-2">{tab.label}</span>
                  </button>
                );
              }
              return (
                <button
                  key={tab.id}
                  type="button"
                  onClick={() => {
                    onSelectTab(tab.id);
                    closeDrawer();
                  }}
                  className={`w-full flex items-center gap-2 px-2 py-2 rounded-lg text-left transition-colors ${
                    isActive
                      ? 'bg-primary/15 text-primary'
                      : 'hover:bg-muted/60 text-foreground'
                  }`}
                >
                  <Icon className="w-4 h-4 shrink-0" />
                  <span className="text-xs font-medium truncate">{tab.label}</span>
                </button>
              );
            })}
          </div>
        </div>
      </aside>
    </div>
    </>
  );
};

export default AdminModuleDrawer;
