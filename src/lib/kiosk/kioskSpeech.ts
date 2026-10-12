/**
 * Thin promise wrappers over the browser Web Speech APIs used by the AI kiosk.
 * Android Chrome (and the installed PWA) supports both recognition (hi-IN / en-IN)
 * and synthesis; recognition needs network access.
 */

export class KioskAbortError extends Error {
  constructor() {
    super('aborted');
    this.name = 'KioskAbortError';
  }
}

export class MicPermissionError extends Error {
  constructor(message = 'microphone blocked') {
    super(message);
    this.name = 'MicPermissionError';
  }
}

/* eslint-disable @typescript-eslint/no-explicit-any */
type RecognitionCtor = new () => any;

export function getRecognitionCtor(): RecognitionCtor | null {
  if (typeof window === 'undefined') return null;
  const w = window as any;
  return (w.SpeechRecognition || w.webkitSpeechRecognition || null) as RecognitionCtor | null;
}

export const isSpeechRecognitionSupported = () => getRecognitionCtor() !== null;
export const isSpeechSynthesisSupported = () => typeof window !== 'undefined' && 'speechSynthesis' in window;

let voicesPromise: Promise<SpeechSynthesisVoice[]> | null = null;

/** Voices load asynchronously on Chrome; wait (briefly) for the list. */
export function loadVoices(): Promise<SpeechSynthesisVoice[]> {
  if (!isSpeechSynthesisSupported()) return Promise.resolve([]);
  if (voicesPromise) return voicesPromise;
  voicesPromise = new Promise((resolve) => {
    const synth = window.speechSynthesis;
    const now = synth.getVoices();
    if (now.length) { resolve(now); return; }
    const done = () => {
      synth.removeEventListener('voiceschanged', done);
      resolve(synth.getVoices());
    };
    synth.addEventListener('voiceschanged', done);
    setTimeout(done, 2000);
  });
  // No voices yet (still installing, or none on this device): try again later
  // instead of waiting before every line.
  void voicesPromise.then((v) => { if (!v.length) setTimeout(() => { voicesPromise = null; }, 30_000); });
  return voicesPromise;
}

/** Best voice for a BCP-47 locale (prefers Google / female-sounding defaults). */
export function pickVoice(voices: SpeechSynthesisVoice[], locale: string): SpeechSynthesisVoice | null {
  const norm = (l: string) => l.replace('_', '-').toLowerCase();
  const want = norm(locale);
  const base = want.split('-')[0];
  const exact = voices.filter((v) => norm(v.lang) === want);
  const sameBase = voices.filter((v) => norm(v.lang).startsWith(base));
  const pool = exact.length ? exact : sameBase;
  if (!pool.length) return null;
  return pool.find((v) => /google/i.test(v.name)) || pool.find((v) => v.localService) || pool[0];
}

export function hasVoiceFor(voices: SpeechSynthesisVoice[], locale: string): boolean {
  return pickVoice(voices, locale) !== null;
}

/** Call once from a tap so later speech is allowed by the autoplay policy. */
export function primeSpeechSynthesis() {
  if (!isSpeechSynthesisSupported()) return;
  try {
    const u = new SpeechSynthesisUtterance(' ');
    u.volume = 0;
    window.speechSynthesis.speak(u);
  } catch {
    /* ignore */
  }
}

export function cancelSpeech() {
  if (isSpeechSynthesisSupported()) window.speechSynthesis.cancel();
}

export async function speak(
  text: string,
  opts: { locale: string; signal?: AbortSignal; rate?: number },
): Promise<void> {
  if (!text.trim() || !isSpeechSynthesisSupported()) return;
  if (opts.signal?.aborted) throw new KioskAbortError();
  const voices = await loadVoices();
  const synth = window.speechSynthesis;
  synth.cancel();
  await new Promise<void>((resolve, reject) => {
    const u = new SpeechSynthesisUtterance(text);
    u.lang = opts.locale;
    const voice = pickVoice(voices, opts.locale);
    if (voice) u.voice = voice;
    u.rate = opts.rate ?? 1;
    u.pitch = 1;
    let settled = false;
    // Android sometimes never fires `end`; don't hang the conversation.
    const guard = setTimeout(() => finish(), Math.max(3000, text.length * 110) + 2500);
    const onAbort = () => {
      synth.cancel();
      finish(new KioskAbortError());
    };
    function finish(err?: Error) {
      if (settled) return;
      settled = true;
      clearTimeout(guard);
      opts.signal?.removeEventListener('abort', onAbort);
      if (err) reject(err);
      else resolve();
    }
    u.onend = () => finish();
    u.onerror = (e) => {
      const code = (e as SpeechSynthesisErrorEvent).error;
      if (code === 'interrupted' || code === 'canceled') finish(opts.signal?.aborted ? new KioskAbortError() : undefined);
      else finish();
    };
    opts.signal?.addEventListener('abort', onAbort, { once: true });
    synth.speak(u);
  });
}

export interface ListenResult {
  /** Best guess first, then alternatives from the recogniser. */
  alternatives: string[];
}

/**
 * Listen for one utterance. Resolves with transcripts (empty when nothing was heard);
 * rejects with KioskAbortError on abort and MicPermissionError when the mic is blocked.
 */
export function listen(opts: {
  locale: string;
  signal?: AbortSignal;
  onInterim?: (text: string) => void;
  maxMs?: number;
}): Promise<ListenResult> {
  const Ctor = getRecognitionCtor();
  if (!Ctor) return Promise.resolve({ alternatives: [] });
  if (opts.signal?.aborted) return Promise.reject(new KioskAbortError());

  return new Promise((resolve, reject) => {
    const rec = new Ctor();
    rec.lang = opts.locale;
    rec.interimResults = true;
    rec.continuous = false;
    rec.maxAlternatives = 3;

    const finals: string[][] = [];
    let interim = '';
    let settled = false;
    let fatal: Error | null = null;

    const timer = setTimeout(() => {
      try { rec.stop(); } catch { /* ignore */ }
    }, opts.maxMs ?? 10000);

    const onAbort = () => {
      fatal = new KioskAbortError();
      try { rec.abort(); } catch { /* ignore */ }
      finish();
    };
    opts.signal?.addEventListener('abort', onAbort, { once: true });

    function finish() {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      opts.signal?.removeEventListener('abort', onAbort);
      if (fatal) { reject(fatal); return; }
      // Combine segment alternatives: first alternative of every segment, plus
      // each alternative of the last segment for re-parsing.
      const best = finals.map((alts) => alts[0]).join(' ').trim() || interim.trim();
      const out = [best];
      const last = finals[finals.length - 1];
      if (last && finals.length === 1) out.push(...last.slice(1));
      resolve({ alternatives: out.filter(Boolean) });
    }

    rec.onresult = (event: any) => {
      interim = '';
      for (let i = event.resultIndex; i < event.results.length; i++) {
        const res = event.results[i];
        if (res.isFinal) {
          const alts: string[] = [];
          for (let a = 0; a < res.length; a++) alts.push(String(res[a].transcript || '').trim());
          finals[i] = alts;
        } else {
          interim += res[0].transcript;
        }
      }
      const shown = [...finals.filter(Boolean).map((a) => a[0]), interim].join(' ').trim();
      opts.onInterim?.(shown);
    };
    rec.onerror = (event: any) => {
      const code = event?.error;
      if (code === 'not-allowed' || code === 'service-not-allowed') fatal = new MicPermissionError(code);
      // 'no-speech', 'aborted', 'network', 'audio-capture' → treat as nothing heard
    };
    rec.onend = () => finish();

    try {
      rec.start();
    } catch {
      finish();
    }
  });
}
/* eslint-enable @typescript-eslint/no-explicit-any */
