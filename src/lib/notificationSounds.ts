/** Preset keys stored on `notifications.sound_key` (admin-only upload uses `custom` + URL). */
export const NOTIFICATION_SOUND_PRESETS = [
  { id: 'digital', label: 'Digital beep' },
  { id: 'chime', label: 'Soft chime' },
  { id: 'bell', label: 'Bell tone' },
  { id: 'custom', label: 'Society custom (admin upload)' },
] as const;

export type NotificationSoundPresetId = (typeof NOTIFICATION_SOUND_PRESETS)[number]['id'];

let audioCtx: AudioContext | null = null;

function getAudioContext(): AudioContext | null {
  if (typeof window === 'undefined') return null;
  try {
    const Ctx = window.AudioContext || (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
    if (!Ctx) return null;
    if (!audioCtx) audioCtx = new Ctx();
    return audioCtx;
  } catch {
    return null;
  }
}

function playTone(freq: number, durationMs: number, type: OscillatorType = 'sine', gain = 0.12) {
  const ctx = getAudioContext();
  if (!ctx) return;
  if (ctx.state === 'suspended') void ctx.resume();
  const osc = ctx.createOscillator();
  const g = ctx.createGain();
  osc.type = type;
  osc.frequency.value = freq;
  g.gain.value = gain;
  osc.connect(g);
  g.connect(ctx.destination);
  const t0 = ctx.currentTime;
  osc.start(t0);
  g.gain.exponentialRampToValueAtTime(0.001, t0 + durationMs / 1000);
  osc.stop(t0 + durationMs / 1000 + 0.02);
}

/** Short synthetic tones (no audio files). */
export function playPresetNotificationSound(preset: string) {
  switch (preset) {
    case 'chime':
      playTone(880, 120, 'sine', 0.1);
      setTimeout(() => playTone(1174, 140, 'sine', 0.08), 90);
      break;
    case 'bell':
      playTone(523, 200, 'triangle', 0.14);
      setTimeout(() => playTone(659, 220, 'triangle', 0.12), 120);
      break;
    case 'custom':
      break;
    case 'digital':
    default:
      playTone(1200, 80, 'square', 0.08);
      setTimeout(() => playTone(900, 90, 'square', 0.06), 70);
      break;
  }
}

/** Play preset or load custom URL (admin-uploaded MP3/OGG/WAV). */
export function playNotificationAlert(soundKey: string | null | undefined, soundCustomUrl?: string | null) {
  const key = (soundKey || 'digital').toLowerCase();
  if (key === 'custom' && soundCustomUrl?.trim()) {
    const audio = new Audio(soundCustomUrl.trim());
    audio.volume = 0.9;
    void audio.play().catch(() => {
      playPresetNotificationSound('digital');
    });
    return;
  }
  if (key === 'custom') {
    playPresetNotificationSound('digital');
    return;
  }
  playPresetNotificationSound(key);
}
