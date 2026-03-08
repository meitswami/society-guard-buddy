import { useStore } from '@/store/useStore';
import { Settings, Shield } from 'lucide-react';
import { useLanguage } from '@/i18n/LanguageContext';
import ThemeToggle from '@/components/ThemeToggle';
import LanguageToggle from '@/components/LanguageToggle';

const SettingsPage = () => {
  const { visitors, flats, members, residentVehicles, blacklist } = useStore();
  const { t } = useLanguage();

  return (
    <div className="page-container">
      <div className="flex items-center gap-3 mb-6">
        <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
          <Settings className="w-5 h-5 text-primary" />
        </div>
        <div>
          <h1 className="page-title">Settings</h1>
          <p className="text-xs text-muted-foreground">App configuration</p>
        </div>
      </div>

      {/* Appearance */}
      <div className="card-section mb-4">
        <h2 className="text-sm font-semibold mb-3">Appearance</h2>
        <div className="flex items-center justify-between">
          <span className="text-xs text-muted-foreground">Theme</span>
          <ThemeToggle />
        </div>
        <div className="flex items-center justify-between mt-3">
          <span className="text-xs text-muted-foreground">Language</span>
          <LanguageToggle />
        </div>
      </div>

      {/* Data summary */}
      <div className="card-section mb-4">
        <h2 className="text-sm font-semibold mb-3 flex items-center gap-1.5">
          <Shield className="w-4 h-4 text-primary" /> Data Summary
        </h2>
        <div className="grid grid-cols-2 gap-2 text-xs">
          <div className="flex justify-between bg-secondary/50 rounded-lg px-3 py-2">
            <span className="text-muted-foreground">Flats</span>
            <span className="font-mono font-bold">{flats.length}</span>
          </div>
          <div className="flex justify-between bg-secondary/50 rounded-lg px-3 py-2">
            <span className="text-muted-foreground">Members</span>
            <span className="font-mono font-bold">{members.length}</span>
          </div>
          <div className="flex justify-between bg-secondary/50 rounded-lg px-3 py-2">
            <span className="text-muted-foreground">Vehicles</span>
            <span className="font-mono font-bold">{residentVehicles.length}</span>
          </div>
          <div className="flex justify-between bg-secondary/50 rounded-lg px-3 py-2">
            <span className="text-muted-foreground">Visitors</span>
            <span className="font-mono font-bold">{visitors.length}</span>
          </div>
          <div className="flex justify-between bg-secondary/50 rounded-lg px-3 py-2">
            <span className="text-muted-foreground">Blacklist</span>
            <span className="font-mono font-bold">{blacklist.length}</span>
          </div>
        </div>
      </div>

      <p className="text-center text-[10px] text-muted-foreground mt-6">{t('app.footer')}</p>
    </div>
  );
};

export default SettingsPage;
