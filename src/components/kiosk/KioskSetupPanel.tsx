import { useEffect, useState } from 'react';
import { useKioskCamera } from '@/hooks/useKioskCamera';
import { AlertCircle, ArrowLeft, Bot, Camera, CheckCircle2, Loader2, Mic, Play, ScanFace, Volume2, XCircle } from 'lucide-react';
import { Switch } from '@/components/ui/switch';
import { useLanguage } from '@/i18n/LanguageContext';
import { KIOSK_LANGS, VOICE_LOCALE, kioskSpeech } from '@/lib/kiosk/kioskCopy';
import { hasVoiceFor, isSpeechRecognitionSupported, isSpeechSynthesisSupported, speak } from '@/lib/kiosk/kioskSpeech';
import type { KioskSettings } from '@/lib/kiosk/kioskSettings';

type Check = 'checking' | 'ok' | 'missing' | 'unknown';

interface Props {
  settings: KioskSettings;
  onChange: (s: KioskSettings) => void;
  onStart: () => void;
  onBack: () => void;
}

const CheckRow = ({ icon: Icon, label, state, hint, action }: {
  icon: React.ElementType; label: string; state: Check; hint?: string; action?: React.ReactNode;
}) => {
  const { t } = useLanguage();
  return (
    <div className="flex items-start gap-3 py-2">
      <Icon className="w-4 h-4 mt-0.5 text-muted-foreground flex-shrink-0" />
      <div className="flex-1 min-w-0">
        <p className="text-sm">{label}</p>
        {(state === 'missing' || state === 'unknown') && hint && <p className="text-[11px] text-muted-foreground mt-0.5">{hint}</p>}
        {action}
      </div>
      {state === 'checking' && <span className="text-xs text-muted-foreground flex items-center gap-1"><Loader2 className="w-3 h-3 animate-spin" />{t('kiosk.check.checking')}</span>}
      {state === 'ok' && <span className="text-xs text-success flex items-center gap-1"><CheckCircle2 className="w-3.5 h-3.5" />{t('kiosk.check.ok')}</span>}
      {state === 'missing' && <span className="text-xs text-destructive flex items-center gap-1"><XCircle className="w-3.5 h-3.5" />{t('kiosk.check.missing')}</span>}
      {state === 'unknown' && <span className="text-xs text-warning flex items-center gap-1"><AlertCircle className="w-3.5 h-3.5" />{t('kiosk.check.notListed')}</span>}
    </div>
  );
};

const FRAMING_KEYS = {
  none: 'kiosk.test.none', tooFar: 'kiosk.test.tooFar', tooClose: 'kiosk.test.tooClose',
  offCenter: 'kiosk.test.offCenter', framed: 'kiosk.test.framed',
} as const;

/** Live preview so the guard can see whether the camera and face detection work on this device. */
const CameraTest = () => {
  const { t } = useLanguage();
  const [open, setOpen] = useState(false);
  const cam = useKioskCamera(open);
  if (!open) {
    return (
      <button
        type="button"
        onClick={() => setOpen(true)}
        className="mt-2 w-full inline-flex items-center justify-center gap-2 rounded-lg border border-border py-2 text-sm font-medium"
      >
        <ScanFace className="w-4 h-4" /> {t('kiosk.test.open')}
      </button>
    );
  }
  const status =
    cam.cameraState === 'denied' ? t('kiosk.test.camDenied')
      : cam.cameraState === 'error' ? t('kiosk.test.camError')
        : cam.cameraState === 'starting' ? t('kiosk.check.checking')
          : cam.detectorState === 'loading' ? t('kiosk.test.loadingDetector')
            : cam.detectorState === 'none' ? t('kiosk.check.faceMissing')
              : t(FRAMING_KEYS[cam.framing]);
  const good = cam.framing === 'framed';
  return (
    <div className="mt-2 flex items-center gap-3 rounded-lg border border-border p-2">
      <video
        ref={cam.attachVideo}
        muted
        playsInline
        autoPlay
        className={`w-20 h-20 rounded-full object-cover bg-black -scale-x-100 border-4 ${good ? 'border-success' : 'border-warning/60'}`}
      />
      <div className="flex-1 min-w-0">
        <p className={`text-sm font-medium ${good ? 'text-success' : ''}`}>{status}</p>
        <button type="button" onClick={() => setOpen(false)} className="mt-1 text-xs text-muted-foreground underline">
          {t('kiosk.test.close')}
        </button>
      </div>
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
    // Android Chrome often lists voices late (or never) even though Hindi speech works,
    // so poll for a while and fall back to "not listed — test it".
    let tries = 0;
    const pollVoices = () => {
      if (cancelled) return;
      if (!isSpeechSynthesisSupported()) { setVoice('missing'); return; }
      if (hasVoiceFor(window.speechSynthesis.getVoices(), VOICE_LOCALE.hi)) { setVoice('ok'); return; }
      if (++tries >= 8) { setVoice('unknown'); return; }
      setTimeout(pollVoices, 750);
    };
    pollVoices();
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
        <CheckRow
          icon={Volume2}
          label={t('kiosk.check.voice')}
          state={voice}
          hint={t('kiosk.check.voiceHint')}
          action={
            isSpeechSynthesisSupported() && (
              <button
                type="button"
                onClick={() => void speak(kioskSpeech('greeting', 'hi', { society: t('app.name') }), { locale: VOICE_LOCALE.hi })}
                className="mt-1.5 inline-flex items-center gap-1 rounded-md bg-secondary px-2.5 py-1 text-xs font-semibold text-secondary-foreground"
              >
                <Play className="w-3 h-3" /> {t('kiosk.check.testVoice')}
              </button>
            )
          }
        />
        <CameraTest />
      </div>

      <p className="text-[11px] text-muted-foreground mb-4">{t('kiosk.setup.tips')}</p>

      <button type="button" onClick={onStart} className="btn-primary w-full py-4 text-base flex items-center justify-center gap-2">
        <ScanFace className="w-5 h-5" /> {t('kiosk.setup.start')}
      </button>
    </div>
  );
};

export default KioskSetupPanel;
