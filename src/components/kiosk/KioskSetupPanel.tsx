import { useEffect, useState } from 'react';
import { ArrowLeft, Bot, Camera, CheckCircle2, Loader2, Mic, ScanFace, Volume2, XCircle } from 'lucide-react';
import { Switch } from '@/components/ui/switch';
import { useLanguage } from '@/i18n/LanguageContext';
import { KIOSK_LANGS, VOICE_LOCALE } from '@/lib/kiosk/kioskCopy';
import { hasVoiceFor, isSpeechRecognitionSupported, loadVoices } from '@/lib/kiosk/kioskSpeech';
import type { KioskSettings } from '@/lib/kiosk/kioskSettings';

type Check = 'checking' | 'ok' | 'missing';

interface Props {
  settings: KioskSettings;
  onChange: (s: KioskSettings) => void;
  onStart: () => void;
  onBack: () => void;
}

const CheckRow = ({ icon: Icon, label, state, hint }: { icon: React.ElementType; label: string; state: Check; hint?: string }) => {
  const { t } = useLanguage();
  return (
    <div className="flex items-start gap-3 py-2">
      <Icon className="w-4 h-4 mt-0.5 text-muted-foreground flex-shrink-0" />
      <div className="flex-1 min-w-0">
        <p className="text-sm">{label}</p>
        {state === 'missing' && hint && <p className="text-[11px] text-muted-foreground mt-0.5">{hint}</p>}
      </div>
      {state === 'checking' && <span className="text-xs text-muted-foreground flex items-center gap-1"><Loader2 className="w-3 h-3 animate-spin" />{t('kiosk.check.checking')}</span>}
      {state === 'ok' && <span className="text-xs text-success flex items-center gap-1"><CheckCircle2 className="w-3.5 h-3.5" />{t('kiosk.check.ok')}</span>}
      {state === 'missing' && <span className="text-xs text-destructive flex items-center gap-1"><XCircle className="w-3.5 h-3.5" />{t('kiosk.check.missing')}</span>}
    </div>
  );
};

/** Guard-facing screen: kiosk options + device readiness, then "Start kiosk". */
const KioskSetupPanel = ({ settings, onChange, onStart, onBack }: Props) => {
  const { t } = useLanguage();
  const [camera, setCamera] = useState<Check>('checking');
  const [voice, setVoice] = useState<Check>('checking');
  const speech: Check = isSpeechRecognitionSupported() ? 'ok' : 'missing';
  const set = <K extends keyof KioskSettings>(key: K, value: KioskSettings[K]) => onChange({ ...settings, [key]: value });

  useEffect(() => {
    let cancelled = false;
    void loadVoices().then((voices) => {
      if (!cancelled) setVoice(hasVoiceFor(voices, VOICE_LOCALE.hi) ? 'ok' : 'missing');
    });
    if (!navigator.mediaDevices?.enumerateDevices) setCamera('missing');
    else {
      void navigator.mediaDevices.enumerateDevices().then((devices) => {
        if (!cancelled) setCamera(devices.some((d) => d.kind === 'videoinput') ? 'ok' : 'missing');
      }).catch(() => !cancelled && setCamera('missing'));
    }
    return () => { cancelled = true; };
  }, []);

  return (
    <div className="page-container">
      <div className="flex items-center gap-3 mb-5">
        <button type="button" onClick={onBack} className="p-2 rounded-lg bg-secondary text-muted-foreground" aria-label={t('kiosk.setup.back')}>
          <ArrowLeft className="w-4 h-4" />
        </button>
        <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
          <Bot className="w-5 h-5 text-primary" />
        </div>
        <div className="min-w-0">
          <h1 className="page-title">{t('kiosk.setup.title')}</h1>
        </div>
      </div>
      <p className="text-sm text-muted-foreground mb-5">{t('kiosk.setup.subtitle')}</p>

      <div className="card-section mb-4">
        <p className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-2">{t('kiosk.setup.defaultLang')}</p>
        <div className="flex gap-2">
          {KIOSK_LANGS.map((l) => (
            <button
              key={l.id}
              type="button"
              onClick={() => set('defaultLang', l.id)}
              className={`flex-1 py-2 rounded-lg text-sm font-semibold transition-all ${settings.defaultLang === l.id ? 'bg-primary text-primary-foreground' : 'bg-secondary text-secondary-foreground'}`}
            >
              {l.label}
            </button>
          ))}
        </div>
      </div>

      <div className="card-section mb-4 flex flex-col gap-4">
        <label className="flex items-start justify-between gap-3">
          <span>
            <span className="text-sm block">{t('kiosk.setup.requireApproval')}</span>
            <span className="text-[11px] text-muted-foreground">{t('kiosk.setup.requireApprovalHint')}</span>
          </span>
          <Switch checked={settings.requireApproval} onCheckedChange={(v) => set('requireApproval', v)} />
        </label>
        <label className="flex items-start justify-between gap-3">
          <span>
            <span className="text-sm block">{t('kiosk.setup.cloudAi')}</span>
            <span className="text-[11px] text-muted-foreground">{t('kiosk.setup.cloudAiHint')}</span>
          </span>
          <Switch checked={settings.useCloudAi} onCheckedChange={(v) => set('useCloudAi', v)} />
        </label>
        <label className="flex items-center justify-between gap-3">
          <span className="text-sm">{t('kiosk.setup.capturePhoto')}</span>
          <Switch checked={settings.capturePhoto} onCheckedChange={(v) => set('capturePhoto', v)} />
        </label>
        <label className="flex items-center justify-between gap-3">
          <span className="text-sm">{t('kiosk.setup.askVehicle')}</span>
          <Switch checked={settings.askVehicle} onCheckedChange={(v) => set('askVehicle', v)} />
        </label>
        <div>
          <label className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1.5 block">{t('kiosk.setup.exitPin')}</label>
          <input
            className="input-field font-mono tracking-widest"
            type="password"
            inputMode="numeric"
            maxLength={6}
            placeholder="••••"
            value={settings.exitPin}
            onChange={(e) => set('exitPin', e.target.value.replace(/\D/g, ''))}
          />
          <p className="text-[11px] text-muted-foreground mt-1">{t('kiosk.setup.exitPinHint')}</p>
        </div>
      </div>

      <div className="card-section mb-4">
        <p className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-1">{t('kiosk.setup.checks')}</p>
        <CheckRow icon={Camera} label={t('kiosk.check.camera')} state={camera} />
        <CheckRow icon={Mic} label={t('kiosk.check.speech')} state={speech} hint={t('kiosk.check.speechMissing')} />
        <CheckRow icon={Volume2} label={t('kiosk.check.voice')} state={voice} />
      </div>

      <p className="text-[11px] text-muted-foreground mb-4">{t('kiosk.setup.tips')}</p>

      <button type="button" onClick={onStart} className="btn-primary w-full py-4 text-base flex items-center justify-center gap-2">
        <ScanFace className="w-5 h-5" /> {t('kiosk.setup.start')}
      </button>
    </div>
  );
};

export default KioskSetupPanel;
