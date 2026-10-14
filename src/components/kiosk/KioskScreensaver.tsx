import { useEffect, useState } from 'react';
import { ScanFace } from 'lucide-react';
import { kioskText, type KioskLang } from '@/lib/kiosk/kioskCopy';

interface Props {
  lang: KioskLang;
  societyName: string;
  now: Date;
  attachVideo: (el: HTMLVideoElement | null) => void;
  /** One-line camera / face-detection status for the guard, with an optional retry. */
  status: { text: string; tone: 'ok' | 'warn' | 'error'; onRetry?: () => void; retryLabel?: string };
  onTap: () => void;
}

const TIPS = ['idleTip1', 'idleTip2', 'idleTip3'] as const;

/** Idle attract screen; a small live camera bubble keeps face detection running. */
const KioskScreensaver = ({ lang, societyName, now, attachVideo, status, onTap }: Props) => {
  const [tip, setTip] = useState(0);
  useEffect(() => {
    const id = setInterval(() => setTip((i) => (i + 1) % TIPS.length), 4500);
    return () => clearInterval(id);
  }, []);

  const locale = lang === 'en' ? 'en-IN' : 'hi-IN';
  return (
    <button
      type="button"
      onClick={onTap}
      className="absolute inset-0 overflow-hidden bg-[#0b1020] text-white flex flex-col items-center justify-center text-center px-6 select-none"
    >
      <div className="pointer-events-none absolute -top-32 -left-24 w-[28rem] h-[28rem] rounded-full bg-orange-500/30 blur-3xl animate-kiosk-float" />
      <div className="pointer-events-none absolute -bottom-40 -right-24 w-[32rem] h-[32rem] rounded-full bg-emerald-500/20 blur-3xl animate-kiosk-float [animation-delay:-6s]" />
      <div className="pointer-events-none absolute top-1/3 left-1/2 w-[22rem] h-[22rem] rounded-full bg-indigo-500/20 blur-3xl animate-kiosk-float [animation-delay:-12s]" />

      <div className="relative flex flex-col items-center gap-3">
        <p className="text-6xl sm:text-7xl font-light tabular-nums tracking-tight">
          {now.toLocaleTimeString(locale, { hour: '2-digit', minute: '2-digit' })}
        </p>
        <p className="text-sm text-white/60">
          {now.toLocaleDateString(locale, { weekday: 'long', day: 'numeric', month: 'long' })}
        </p>
        <p className="mt-4 text-lg font-semibold text-orange-300">{societyName}</p>
      </div>

      <div className="relative mt-14 flex flex-col items-center gap-4">
        <span className="relative flex items-center justify-center w-28 h-28">
          <span className="absolute inset-0 rounded-full bg-orange-400/25 animate-ping" />
          <span className="relative w-24 h-24 rounded-full bg-white/10 border border-white/20 flex items-center justify-center">
            <ScanFace className="w-12 h-12 text-orange-200" />
          </span>
        </span>
        <h2 className="text-3xl sm:text-4xl font-bold">{kioskText('idleTitle', lang)}</h2>
        <p className="text-xl sm:text-2xl text-white/90 max-w-md">{kioskText('idleSubtitle', lang)}</p>
        <p className="text-sm text-white/50">{kioskText('idleTap', lang)}</p>
        <p key={tip} className="mt-6 text-base text-white/70 max-w-sm animate-kiosk-fade">
          {kioskText(TIPS[tip], lang)}
        </p>
      </div>

      {/* Bottom-left: app wrappers (e.g. AppMySite) float their own button bottom-right. */}
      <div className="absolute bottom-[max(1.25rem,env(safe-area-inset-bottom))] left-4 right-24 flex items-center gap-3 text-left">
        <video
          ref={attachVideo}
          muted
          playsInline
          autoPlay
          className="w-20 h-20 flex-shrink-0 rounded-full object-cover border-2 border-white/30 bg-black/40 -scale-x-100"
        />
        <div className="min-w-0 flex flex-col items-start gap-1.5">
          <span className="flex items-center gap-1.5 text-xs leading-snug">
            <span
              className={`w-2 h-2 flex-shrink-0 rounded-full ${
                status.tone === 'ok' ? 'bg-emerald-400 animate-pulse' : status.tone === 'warn' ? 'bg-amber-400' : 'bg-red-400'
              }`}
            />
            <span className={status.tone === 'error' ? 'text-red-200' : 'text-white/70'}>{status.text}</span>
          </span>
          {status.onRetry && (
            <span
              role="button"
              tabIndex={0}
              onClick={(e) => { e.stopPropagation(); status.onRetry?.(); }}
              className="px-3 py-1 rounded-lg bg-white/15 text-xs font-semibold"
            >
              {status.retryLabel}
            </span>
          )}
        </div>
      </div>
    </button>
  );
};

export default KioskScreensaver;
