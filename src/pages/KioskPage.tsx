import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import Swal from 'sweetalert2';
import { toast } from 'sonner';
import {
  Bot, Car, CheckCircle2, Home, Keyboard, Lock, Mic, Phone, ShieldAlert, Target, User, X, XCircle,
} from 'lucide-react';
import { supabase } from '@/integrations/supabase/client';
import { useStore } from '@/store/useStore';
import { useLanguage } from '@/i18n/LanguageContext';
import type { Visitor } from '@/types';
import KioskSetupPanel from '@/components/kiosk/KioskSetupPanel';
import KioskScreensaver from '@/components/kiosk/KioskScreensaver';
import { useKioskCamera } from '@/hooks/useKioskCamera';
import { normalizeEntryValue } from '@/lib/entryCaps';
import { confirmAction, getSwalThemeColors } from '@/lib/swal';
import {
  KIOSK_LANGS, RECOGNITION_LOCALE, VOICE_LOCALE, kioskSpeech, kioskText, purposeLabel,
  type KioskCopyKey, type KioskLang,
} from '@/lib/kiosk/kioskCopy';
import {
  EMPTY_DRAFT, LanguageChangedError, runKioskConversation,
  type KioskContext, type KioskDraft, type KioskIO, type KioskInput, type KioskOutcome, type KioskStep,
} from '@/lib/kiosk/kioskConversation';
import { formatPhoneForDisplay, type KioskEditField } from '@/lib/kiosk/kioskParsers';
import { requestResidentApproval } from '@/lib/kiosk/kioskApproval';
import { readKioskSettings, setKioskLocked, writeKioskSettings, type KioskSettings } from '@/lib/kiosk/kioskSettings';
import {
  KioskAbortError, cancelSpeech, isSpeechRecognitionSupported, listen, primeSpeechSynthesis, speak,
} from '@/lib/kiosk/kioskSpeech';

/** How long a face must stay framed before the receptionist starts talking. */
const FRAMED_HOLD_MS = 1200;
/** End a conversation when nobody has been in front of the camera for this long. */
const ABANDON_AFTER_MS = 25_000;
const RESULT_SCREEN_MS = 6000;

type Phase = 'idle' | 'session' | 'result' | 'cooldown';

function linkedController(parent: AbortSignal) {
  const ctrl = new AbortController();
  const onAbort = () => ctrl.abort(parent.reason);
  if (parent.aborted) ctrl.abort(parent.reason);
  else parent.addEventListener('abort', onAbort, { once: true });
  return { ctrl, dispose: () => parent.removeEventListener('abort', onAbort) };
}

interface Props { onExit: () => void; }

const KioskPage = ({ onExit }: Props) => {
  const [settings, setSettings] = useState<KioskSettings>(readKioskSettings);
  const [running, setRunning] = useState(false);

  const updateSettings = (s: KioskSettings) => {
    setSettings(s);
    writeKioskSettings(s);
  };

  const start = () => {
    // Called from a tap: unlocks speech output and lets us go fullscreen.
    primeSpeechSynthesis();
    void document.documentElement.requestFullscreen?.().catch(() => undefined);
    setRunning(true);
  };

  if (!running) {
    return <KioskSetupPanel settings={settings} onChange={updateSettings} onStart={start} onBack={onExit} />;
  }
  return (
    <KioskRunner
      settings={settings}
      onStop={() => {
        if (document.fullscreenElement) void document.exitFullscreen().catch(() => undefined);
        setRunning(false);
      }}
    />
  );
};

const STEP_ORDER: { step: KioskStep; key: KioskCopyKey; icon: React.ElementType }[] = [
  { step: 'name', key: 'fieldName', icon: User },
  { step: 'phone', key: 'fieldPhone', icon: Phone },
  { step: 'flat', key: 'fieldFlat', icon: Home },
  { step: 'purpose', key: 'fieldPurpose', icon: Target },
  { step: 'vehicle', key: 'fieldVehicle', icon: Car },
];

const KioskRunner = ({ settings, onStop }: { settings: KioskSettings; onStop: () => void }) => {
  const { t } = useLanguage();
  const societyId = useStore((s) => s.societyId);
  const currentGuard = useStore((s) => s.currentGuard);
  const camera = useKioskCamera(true);
  const { msSinceFace } = camera;

  const [lang, setLangState] = useState<KioskLang>(settings.defaultLang);
  const langRef = useRef<KioskLang>(settings.defaultLang);
  const [phase, setPhase] = useState<Phase>('idle');
  const phaseRef = useRef<Phase>('idle');
  const [step, setStep] = useState<KioskStep>('greeting');
  const stepRef = useRef<KioskStep>('greeting');
  const [draft, setDraft] = useState<KioskDraft>(EMPTY_DRAFT);
  const [assistantLine, setAssistantLine] = useState<{ key: KioskCopyKey; vars?: Record<string, string> } | null>(null);
  const [listening, setListening] = useState(false);
  const [inputMode, setInputMode] = useState<'field' | 'yesno' | null>(null);
  const [interim, setInterim] = useState('');
  const [understood, setUnderstood] = useState<string | null>(null);
  const [typing, setTyping] = useState(false);
  const [typedText, setTypedText] = useState('');
  const [approvalLeft, setApprovalLeft] = useState<number | null>(null);
  const [outcome, setOutcome] = useState<KioskOutcome | null>(null);
  const [societyName, setSocietyName] = useState('');
  const [now, setNow] = useState(() => new Date());
  const [facePresent, setFacePresent] = useState(false);

  const sessionRef = useRef<AbortController | null>(null);
  const callRef = useRef<AbortController | null>(null);
  const inputResolverRef = useRef<((input: KioskInput) => void) | null>(null);
  const cooldownStartRef = useRef(0);
  const speechSupported = isSpeechRecognitionSupported();
  const faceDetection = camera.detectorState === 'mediapipe' || camera.detectorState === 'native';

  const goPhase = useCallback((p: Phase) => { phaseRef.current = p; setPhase(p); }, []);
  const goStep = useCallback((s: KioskStep) => { stepRef.current = s; setStep(s); }, []);

  // Kiosk lifecycle: block the guard shell's back handling, keep the screen awake.
  useEffect(() => {
    setKioskLocked(true);
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    let lock: any = null;
    const requestLock = async () => {
      try {
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        lock = await (navigator as any).wakeLock?.request('screen');
      } catch {
        /* not supported / denied */
      }
    };
    void requestLock();
    const onVisible = () => { if (document.visibilityState === 'visible') void requestLock(); };
    document.addEventListener('visibilitychange', onVisible);
    const clock = setInterval(() => setNow(new Date()), 15_000);
    return () => {
      setKioskLocked(false);
      document.removeEventListener('visibilitychange', onVisible);
      clearInterval(clock);
      void lock?.release?.().catch?.(() => undefined);
      sessionRef.current?.abort();
      cancelSpeech();
    };
  }, []);

  useEffect(() => {
    if (!societyId) return;
    let cancelled = false;
    void supabase.from('societies').select('name').eq('id', societyId).maybeSingle().then(({ data }) => {
      if (!cancelled && data?.name) setSocietyName(data.name);
    });
    return () => { cancelled = true; };
  }, [societyId]);

  // Face present (with a short hold so the screensaver doesn't flicker).
  useEffect(() => {
    if (camera.framing !== 'none') { setFacePresent(true); return; }
    const id = setTimeout(() => setFacePresent(false), 2500);
    return () => clearTimeout(id);
  }, [camera.framing]);

  const changeLang = useCallback((l: KioskLang) => {
    if (l === langRef.current) return;
    langRef.current = l;
    setLangState(l);
    cancelSpeech();
    callRef.current?.abort(new LanguageChangedError());
  }, []);

  const sendInput = useCallback((input: KioskInput) => {
    inputResolverRef.current?.(input);
  }, []);

  const notifyGuard = useCallback((result: KioskOutcome, d: KioskDraft) => {
    const vars = { name: d.name || d.nameDisplay, flat: d.flat, phone: d.phone };
    if (result === 'saved') toast.success(t('kiosk.toast.saved', vars));
    else if (result === 'blocked') toast.error(t('kiosk.toast.blocked', vars), { duration: 15_000 });
    else if (result === 'rejected') toast.warning(t('kiosk.toast.rejected', vars), { duration: 10_000 });
    else if (result === 'timeout') toast.warning(t('kiosk.toast.timeout', vars), { duration: 15_000 });
  }, [t]);

  const startSession = useCallback(async () => {
    if (sessionRef.current || phaseRef.current === 'session') return;
    const session = new AbortController();
    sessionRef.current = session;
    let latestDraft: KioskDraft = EMPTY_DRAFT;
    setDraft(EMPTY_DRAFT);
    setOutcome(null);
    setUnderstood(null);
    setInterim('');
    setTypedText('');
    setApprovalLeft(null);
    goStep('greeting');
    goPhase('session');

    const io: KioskIO = {
      signal: session.signal,
      lang: () => langRef.current,
      say: async (key, vars) => {
        const { ctrl, dispose } = linkedController(session.signal);
        callRef.current = ctrl;
        const l = langRef.current;
        setAssistantLine({ key, vars });
        setListening(false);
        setInputMode(null);
        try {
          await speak(kioskSpeech(key, l, vars), { locale: VOICE_LOCALE[l], signal: ctrl.signal });
        } catch (e) {
          if (ctrl.signal.reason instanceof LanguageChangedError) throw ctrl.signal.reason;
          throw e;
        } finally {
          dispose();
          if (callRef.current === ctrl) callRef.current = null;
        }
        if (ctrl.signal.reason instanceof LanguageChangedError) throw ctrl.signal.reason;
      },
      hear: (mode, { typing: typingOnly }) =>
        new Promise<KioskInput>((resolve, reject) => {
          const { ctrl, dispose } = linkedController(session.signal);
          callRef.current = ctrl;
          let done = false;
          let timer: ReturnType<typeof setTimeout> | undefined;
          const finish = (fn: () => void) => {
            if (done) return;
            done = true;
            if (timer) clearTimeout(timer);
            dispose();
            inputResolverRef.current = null;
            if (callRef.current === ctrl) callRef.current = null;
            setListening(false);
            setInputMode(null);
            fn();
          };
          inputResolverRef.current = (input) => {
            finish(() => resolve(input));
            ctrl.abort();
          };
          ctrl.signal.addEventListener('abort', () => finish(() => reject(
            ctrl.signal.reason instanceof LanguageChangedError ? ctrl.signal.reason : new KioskAbortError(),
          )), { once: true });
          setInputMode(mode);
          setInterim('');
          if (typingOnly || !speechSupported) {
            timer = setTimeout(() => finish(() => resolve({ kind: 'speech', alternatives: [] })), 60_000);
            return;
          }
          setListening(true);
          listen({
            locale: RECOGNITION_LOCALE[langRef.current],
            signal: ctrl.signal,
            onInterim: setInterim,
            maxMs: mode === 'yesno' ? 7000 : 11_000,
          })
            .then((r) => {
              if (r.alternatives[0]) setInterim(r.alternatives[0]);
              finish(() => resolve({ kind: 'speech', alternatives: r.alternatives }));
            })
            .catch((e) => finish(() => reject(e)));
        }),
      setStep: goStep,
      setDraft: (d) => { latestDraft = d; setDraft(d); },
      setUnderstood,
      setTyping: (on) => { setTyping(on); if (on) setTypedText(''); },
    };

    const ctx: KioskContext = {
      societyName: societyName || 'Kutumbika',
      societyId,
      settings,
      flatNumbers: useStore.getState().flats.map((f) => f.flatNumber),
      findPreviousVisit: (phone) => {
        const v = useStore.getState().visitors.find((x) => x.phone === phone);
        return v ? { name: v.name, flatNumber: v.flatNumber } : null;
      },
      isBlacklisted: (phone, vehicle) => useStore.getState().isBlacklisted(phone, vehicle),
      capturePhoto: camera.captureFrame,
      requestApproval: async (d, onTick) => {
        if (!societyId) return 'no_flat';
        return requestResidentApproval({
          societyId,
          flatNumber: d.flat,
          visitorName: d.name,
          visitorPhone: d.phone,
          purpose: d.purpose,
          guardId: currentGuard?.id || '',
          guardName: `${currentGuard?.name || ''} · AI Kiosk`,
          signal: session.signal,
          onTick,
        });
      },
      onApprovalTick: setApprovalLeft,
      saveEntry: async (d) => {
        const nowIso = new Date().toISOString();
        const visitor: Visitor = {
          id: `V${Date.now()}`,
          name: normalizeEntryValue(d.name, { field: 'name' }),
          phone: d.phone,
          documentType: 'other',
          documentNumber: '',
          visitorPhotos: d.photo ? [d.photo] : [],
          flatNumber: d.flat,
          purpose: d.purpose || 'Other',
          entryTime: nowIso,
          guardId: currentGuard?.id || '',
          guardName: `${currentGuard?.name || ''} · AI Kiosk`,
          category: d.purpose === 'Delivery' ? 'delivery' : 'visitor',
          company: d.company,
          vehicleNumber: d.vehicle || undefined,
          vehicleEntryTime: d.vehicle ? nowIso : undefined,
        };
        return useStore.getState().addVisitor(visitor);
      },
    };

    let result: KioskOutcome | null = null;
    try {
      result = await runKioskConversation(io, ctx);
    } catch (e) {
      if (!(e instanceof KioskAbortError)) {
        console.error('Kiosk conversation failed', e);
        result = 'failed';
      }
    } finally {
      sessionRef.current = null;
      callRef.current = null;
      inputResolverRef.current = null;
      cancelSpeech();
      setListening(false);
      setInputMode(null);
      setTyping(false);
    }

    if (result) {
      notifyGuard(result, latestDraft);
      setOutcome(result);
      goPhase('result');
      setTimeout(() => {
        if (phaseRef.current === 'result') {
          cooldownStartRef.current = Date.now();
          goPhase('cooldown');
        }
      }, RESULT_SCREEN_MS);
    } else {
      cooldownStartRef.current = Date.now();
      goPhase('cooldown');
    }
  }, [camera.captureFrame, currentGuard?.id, currentGuard?.name, goPhase, goStep, notifyGuard, settings, societyId, societyName, speechSupported]);

  // Auto-start when a face has been properly framed for a moment.
  useEffect(() => {
    if (phase !== 'idle' || camera.framedSince === null) return;
    const wait = Math.max(0, camera.framedSince + FRAMED_HOLD_MS - Date.now());
    const id = setTimeout(() => {
      if (phaseRef.current === 'idle') void startSession();
    }, wait);
    return () => clearTimeout(id);
  }, [phase, camera.framedSince, startSession]);

  // Cooldown: wait until the last visitor has left (or 12 s) before re-arming.
  useEffect(() => {
    if (phase !== 'cooldown') return;
    const id = setInterval(() => {
      const away = msSinceFace() > 2500 || !faceDetection;
      if (away || Date.now() - cooldownStartRef.current > 12_000) {
        setDraft(EMPTY_DRAFT);
        setAssistantLine(null);
        setOutcome(null);
        goPhase('idle');
      }
    }, 500);
    return () => clearInterval(id);
  }, [phase, msSinceFace, faceDetection, goPhase]);

  // Abandoned conversation: nobody in front of the camera for a while.
  useEffect(() => {
    if (phase !== 'session' || !faceDetection) return;
    const startedAt = Date.now();
    const id = setInterval(() => {
      const busy = stepRef.current === 'approval' || stepRef.current === 'saving';
      // A session started by a tap may not have seen a face yet — count from the start.
      const away = Math.min(msSinceFace(), Date.now() - startedAt);
      if (!busy && away > ABANDON_AFTER_MS) sessionRef.current?.abort();
    }, 1000);
    return () => clearInterval(id);
  }, [phase, faceDetection, msSinceFace]);

  // Hold-to-exit lock.
  const holdTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const [holding, setHolding] = useState(false);
  const requestExit = useCallback(async () => {
    const theme = getSwalThemeColors();
    if (settings.exitPin) {
      const res = await Swal.fire({
        title: t('kiosk.exit.pinPrompt'),
        input: 'password',
        inputAttributes: { inputmode: 'numeric', maxlength: '6', autocomplete: 'off' },
        showCancelButton: true,
        background: theme.background,
        color: theme.color,
        confirmButtonColor: theme.confirmButtonColor,
        cancelButtonColor: theme.cancelButtonColor,
      });
      if (!res.isConfirmed) return;
      if (String(res.value ?? '') !== settings.exitPin) {
        toast.error(t('kiosk.exit.wrongPin'));
        return;
      }
    } else {
      const ok = await confirmAction(t('kiosk.exit.confirmTitle'), t('kiosk.exit.confirmText'), t('swal.yes'), t('swal.no'));
      if (!ok) return;
    }
    sessionRef.current?.abort();
    cancelSpeech();
    onStop();
  }, [onStop, settings.exitPin, t]);
  const startHold = () => {
    setHolding(true);
    holdTimer.current = setTimeout(() => {
      setHolding(false);
      void requestExit();
    }, 3000);
  };
  const endHold = () => {
    setHolding(false);
    if (holdTimer.current) clearTimeout(holdTimer.current);
  };

  const timeLabel = now.toLocaleTimeString(lang === 'en' ? 'en-IN' : 'hi-IN', { hour: '2-digit', minute: '2-digit' });
  const showScreensaver = (phase === 'idle' && !facePresent) || (phase === 'cooldown' && !facePresent);
  const framingHint: KioskCopyKey =
    camera.framing === 'tooFar' ? 'frameTooFar'
      : camera.framing === 'tooClose' ? 'frameTooClose'
        : camera.framing === 'offCenter' ? 'frameOffCenter'
          : camera.framing === 'framed' ? 'frameHold' : 'frameNone';
  const ringColor = camera.framing === 'framed' ? 'border-emerald-400' : camera.framing === 'none' ? 'border-white/20' : 'border-amber-400';

  const topBar = (
    <div className="relative z-20 flex items-center justify-between gap-2 px-4 pt-[max(0.75rem,env(safe-area-inset-top))] pb-2">
      <div className="min-w-0">
        <p className="text-sm font-semibold text-orange-300 truncate">{societyName}</p>
        <p className="text-[11px] text-white/50 tabular-nums">{timeLabel}</p>
      </div>
      <div className="flex items-center gap-2">
        <div className="inline-flex rounded-xl bg-white/10 p-1 gap-1" role="group" aria-label="Language">
          {KIOSK_LANGS.map((l) => (
            <button
              key={l.id}
              type="button"
              onClick={(e) => { e.stopPropagation(); changeLang(l.id); }}
              aria-pressed={lang === l.id}
              className={`px-3 py-1.5 rounded-lg text-sm font-semibold transition-all ${lang === l.id ? 'bg-orange-500 text-white shadow' : 'text-white/80'}`}
            >
              {l.label}
            </button>
          ))}
        </div>
        <button
          type="button"
          aria-label={t('kiosk.exit.hold')}
          title={t('kiosk.exit.hold')}
          onPointerDown={(e) => { e.stopPropagation(); startHold(); }}
          onPointerUp={endHold}
          onPointerLeave={endHold}
          onPointerCancel={endHold}
          onClick={(e) => e.stopPropagation()}
          onContextMenu={(e) => e.preventDefault()}
          className={`relative p-2.5 rounded-xl bg-white/10 text-white/60 overflow-hidden ${holding ? 'ring-2 ring-orange-400' : ''}`}
        >
          {holding && <span className="absolute inset-0 bg-orange-500/40 origin-left animate-kiosk-hold" />}
          <Lock className="relative w-4 h-4" />
        </button>
      </div>
    </div>
  );

  const retry = { onRetry: camera.retryCamera, retryLabel: kioskText('retryCamera', lang) };
  const screensaverStatus =
    camera.cameraState === 'starting' ? { text: kioskText('statusCamStarting', lang), tone: 'warn' as const }
      : camera.cameraState === 'denied' ? { text: kioskText('statusCamDenied', lang), tone: 'error' as const, ...retry }
        : camera.cameraState === 'error' ? { text: kioskText('statusCamError', lang), tone: 'error' as const, ...retry }
          : camera.detectorState === 'loading' ? { text: kioskText('statusDetectorLoading', lang), tone: 'warn' as const }
            : camera.detectorState === 'none' ? { text: kioskText('statusNoDetector', lang), tone: 'warn' as const }
              : { text: kioskText('statusLooking', lang), tone: 'ok' as const };

  if (showScreensaver) {
    return (
      <div className="fixed inset-0 z-[70] bg-[#0b1020]">
        <KioskScreensaver
          lang={lang}
          societyName={societyName}
          now={now}
          attachVideo={camera.attachVideo}
          status={screensaverStatus}
          onTap={() => void startSession()}
        />
        <div className="absolute top-0 inset-x-0">{topBar}</div>
      </div>
    );
  }

  const assistantText = assistantLine ? kioskText(assistantLine.key, lang, assistantLine.vars) : '';
  const activeIdx = STEP_ORDER.findIndex((s) => s.step === step);
  const editable = phase === 'session' && step === 'summary';
  const showTyping = phase === 'session' && inputMode === 'field' && (typing || !speechSupported);
  const canSkip = phase === 'session' && inputMode === 'field' && (step === 'purpose' || step === 'vehicle');

  const detailRows: { field: KioskEditField; key: KioskCopyKey; icon: React.ElementType; value: string }[] = [
    { field: 'name', key: 'fieldName', icon: User, value: draft.nameDisplay && draft.nameDisplay !== draft.name ? `${draft.nameDisplay} · ${draft.name}` : draft.name },
    { field: 'phone', key: 'fieldPhone', icon: Phone, value: draft.phone ? formatPhoneForDisplay(draft.phone) : '' },
    { field: 'flat', key: 'fieldFlat', icon: Home, value: draft.flat },
    { field: 'purpose', key: 'fieldPurpose', icon: Target, value: draft.purpose ? purposeLabel(draft.purpose, lang) + (draft.company ? ` · ${draft.company}` : '') : '' },
    ...(settings.askVehicle
      ? [{ field: 'vehicle' as const, key: 'fieldVehicle' as KioskCopyKey, icon: Car, value: draft.vehicle === null ? kioskText('noVehicle', lang) : draft.vehicle || '' }]
      : []),
  ];

  return (
    <div className="fixed inset-0 z-[70] bg-[#0b1020] text-white flex flex-col overflow-hidden">
      <div className="pointer-events-none absolute -top-40 -left-32 w-[30rem] h-[30rem] rounded-full bg-orange-500/15 blur-3xl" />
      <div className="pointer-events-none absolute -bottom-40 -right-32 w-[30rem] h-[30rem] rounded-full bg-emerald-500/10 blur-3xl" />
      {topBar}

      {/* Phones: camera → conversation → details (details first on the summary step).
          Tablets: camera + details on the left, conversation on the right. */}
      <div className="relative z-10 flex-1 overflow-y-auto px-4 pb-6 flex flex-col md:grid md:grid-cols-[2fr_3fr] md:items-start gap-5 max-w-5xl w-full mx-auto">
        <div className="order-1 md:order-none md:col-start-1 md:row-start-1 flex flex-col items-center gap-4">
          <div className={`relative ${phase === 'idle' ? 'w-48 h-48' : 'w-36 h-36'} sm:w-60 sm:h-60 rounded-full border-4 ${ringColor} overflow-hidden transition-all shadow-2xl`}>
            <video ref={camera.attachVideo} muted playsInline autoPlay className="w-full h-full object-cover -scale-x-100" />
            {phase === 'session' && (
              <span className="absolute bottom-2 left-1/2 -translate-x-1/2 px-2 py-0.5 rounded-full bg-black/60 text-[10px] flex items-center gap-1">
                <Bot className="w-3 h-3" /> AI
              </span>
            )}
          </div>
          {phase === 'idle' && (
            <p className={`text-xl font-semibold text-center ${camera.framing === 'framed' ? 'text-emerald-300' : 'text-amber-200'}`}>
              {kioskText(framingHint, lang)}
            </p>
          )}
        </div>

        {(phase === 'session' || ((phase === 'result' || phase === 'cooldown') && outcome)) && (
          <div className={`${editable ? 'order-2' : 'order-4'} md:order-none md:col-start-1 md:row-start-2`}>
            <div className="w-full rounded-2xl bg-white/5 border border-white/10 p-3 flex flex-col gap-1">
              {detailRows.map((row) => {
                const Icon = row.icon;
                return (
                  <div key={row.field} className={`flex items-center gap-3 rounded-xl px-2 py-2 ${editable ? 'bg-white/5' : ''}`}>
                    <Icon className={`w-4 h-4 flex-shrink-0 ${row.value ? 'text-emerald-300' : 'text-white/30'}`} />
                    <div className="flex-1 min-w-0">
                      <p className="text-[11px] text-white/50">{kioskText(row.key, lang)}</p>
                      <p className={`text-base font-semibold truncate ${row.value ? '' : 'text-white/25'}`}>{row.value || '—'}</p>
                    </div>
                    {editable && (
                      <button
                        type="button"
                        onClick={() => sendInput({ kind: 'edit', field: row.field })}
                        className="px-3 py-1.5 rounded-lg bg-white/10 text-xs font-semibold"
                      >
                        {kioskText('edit', lang)}
                      </button>
                    )}
                  </div>
                );
              })}
            </div>
          </div>
        )}

        {/* Conversation */}
        <div className="order-3 md:order-none md:col-start-2 md:row-start-1 md:row-span-2 flex flex-col gap-4 min-w-0">
          {phase === 'idle' && (
            <div className="rounded-3xl bg-white/5 border border-white/10 p-6 text-center">
              <p className="text-2xl font-bold">{kioskText('idleTitle', lang)}</p>
              <p className="text-white/70 mt-2">{kioskText('idleSubtitle', lang)}</p>
              <button
                type="button"
                onClick={() => void startSession()}
                className="mt-5 px-6 py-3 rounded-2xl bg-orange-500 text-white font-semibold"
              >
                {kioskText('idleTap', lang).replace(/^(या|ya|or)\s+/i, '')}
              </button>
            </div>
          )}

          {phase === 'session' && (
            <>
              <div className="flex gap-1.5">
                {STEP_ORDER.filter((s) => s.step !== 'vehicle' || settings.askVehicle).map((s, i) => {
                  const done = activeIdx > i || step === 'summary' || step === 'approval' || step === 'saving';
                  const current = activeIdx === i;
                  return (
                    <span
                      key={s.step}
                      className={`h-1.5 flex-1 rounded-full transition-colors ${done ? 'bg-emerald-400' : current ? 'bg-orange-400' : 'bg-white/15'}`}
                    />
                  );
                })}
              </div>

              <div key={assistantText} className="rounded-3xl rounded-tl-md bg-gradient-to-br from-orange-500/25 to-orange-500/5 border border-orange-400/30 p-5 animate-kiosk-fade">
                <p className="text-[11px] uppercase tracking-wider text-orange-200/80 mb-1 flex items-center gap-1">
                  <Bot className="w-3.5 h-3.5" /> AI Receptionist
                </p>
                <p className="text-2xl sm:text-3xl font-semibold leading-snug">{assistantText}</p>
                {step === 'approval' && approvalLeft !== null && (
                  <p className="mt-3 text-sm text-white/70 tabular-nums">
                    {kioskText('waitingResident', lang)} · {Math.floor(Math.max(approvalLeft, 0) / 60)}:{String(Math.max(approvalLeft, 0) % 60).padStart(2, '0')}
                  </p>
                )}
                {step === 'saving' && <p className="mt-3 text-sm text-white/70">{kioskText('savingEntry', lang)}</p>}
              </div>

              {(listening || interim) && (
                <div className="rounded-3xl rounded-tr-md bg-white/10 border border-white/15 p-5 ml-6">
                  <div className="flex items-center gap-2 mb-1">
                    {listening ? (
                      <span className="flex items-end gap-0.5 h-4" aria-hidden>
                        {[0, 1, 2, 3, 4].map((i) => (
                          <span key={i} className="w-1 h-4 rounded-full bg-emerald-300 origin-bottom animate-kiosk-wave" style={{ animationDelay: `${i * 0.12}s` }} />
                        ))}
                      </span>
                    ) : (
                      <Mic className="w-4 h-4 text-white/50" />
                    )}
                    <p className="text-[11px] uppercase tracking-wider text-white/60">
                      {listening && !interim ? kioskText('listening', lang) : kioskText('youSaid', lang)}
                    </p>
                  </div>
                  <p className="text-2xl font-medium min-h-[2rem] break-words">{interim || '…'}</p>
                </div>
              )}

              {understood && (
                <div className="rounded-2xl bg-emerald-500/15 border border-emerald-400/40 px-5 py-3 flex items-center gap-3">
                  <CheckCircle2 className="w-5 h-5 text-emerald-300 flex-shrink-0" />
                  <div className="min-w-0">
                    <p className="text-[11px] uppercase tracking-wider text-emerald-200/80">{kioskText('understood', lang)}</p>
                    <p className="text-2xl font-bold tracking-wide break-words">{understood}</p>
                  </div>
                </div>
              )}

              {inputMode === 'yesno' && (
                <div className="grid grid-cols-2 gap-3">
                  <button type="button" onClick={() => sendInput({ kind: 'yes' })} className="py-4 rounded-2xl bg-emerald-500 text-white text-lg font-bold">
                    ✓ {kioskText('yes', lang)}
                  </button>
                  <button type="button" onClick={() => sendInput({ kind: 'no' })} className="py-4 rounded-2xl bg-white/10 border border-white/20 text-lg font-bold">
                    ✗ {kioskText('no', lang)}
                  </button>
                </div>
              )}

              {showTyping && (
                <form
                  className="flex gap-2"
                  onSubmit={(e) => {
                    e.preventDefault();
                    const text = typedText.trim();
                    if (!text) return;
                    setTypedText('');
                    sendInput({ kind: 'text', text });
                  }}
                >
                  <input
                    autoFocus
                    value={typedText}
                    onChange={(e) => setTypedText(e.target.value)}
                    inputMode={step === 'phone' ? 'tel' : 'text'}
                    data-caps="off"
                    className="flex-1 min-w-0 rounded-2xl bg-white text-slate-900 px-4 py-4 text-xl font-semibold outline-none"
                    placeholder={kioskText(STEP_ORDER.find((s) => s.step === step)?.key ?? 'fieldName', lang)}
                  />
                  <button type="submit" className="px-5 rounded-2xl bg-orange-500 text-white font-bold">
                    {kioskText('submit', lang)}
                  </button>
                </form>
              )}

              <div className="flex flex-wrap gap-2">
                {inputMode === 'field' && !showTyping && (
                  <button type="button" onClick={() => sendInput({ kind: 'typeMode' })} className="px-4 py-2.5 rounded-xl bg-white/10 text-sm font-semibold flex items-center gap-2">
                    <Keyboard className="w-4 h-4" /> {kioskText('typeIt', lang)}
                  </button>
                )}
                {canSkip && (
                  <button type="button" onClick={() => sendInput({ kind: 'skip' })} className="px-4 py-2.5 rounded-xl bg-white/10 text-sm font-semibold">
                    {kioskText('skip', lang)}
                  </button>
                )}
                <button
                  type="button"
                  onClick={() => sessionRef.current?.abort()}
                  className="ml-auto px-4 py-2.5 rounded-xl text-white/60 text-sm flex items-center gap-1"
                >
                  <X className="w-4 h-4" /> {kioskText('cancelSession', lang)}
                </button>
              </div>
            </>
          )}

          {(phase === 'result' || phase === 'cooldown') && outcome && (
            <div className="rounded-3xl bg-white/5 border border-white/10 p-8 text-center flex flex-col items-center gap-3 animate-kiosk-fade">
              {outcome === 'saved' ? (
                <CheckCircle2 className="w-20 h-20 text-emerald-400" />
              ) : outcome === 'blocked' ? (
                <ShieldAlert className="w-20 h-20 text-red-400" />
              ) : (
                <XCircle className="w-20 h-20 text-amber-400" />
              )}
              <p className="text-2xl font-bold">{assistantText}</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default KioskPage;
