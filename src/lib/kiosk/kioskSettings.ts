import type { KioskLang } from './kioskCopy';

export interface KioskSettings {
  defaultLang: KioskLang;
  /** Ask the flat's resident to approve before saving the entry. */
  requireApproval: boolean;
  /** Use the `kiosk-assistant` Edge Function (Claude) when local parsing is unsure. */
  useCloudAi: boolean;
  /** Save a camera snapshot with the entry. */
  capturePhoto: boolean;
  /** Ask about vehicles. */
  askVehicle: boolean;
  /** When set, leaving the kiosk asks for this PIN. */
  exitPin: string;
}

const KEY = 'kiosk-settings-v1';

export const DEFAULT_KIOSK_SETTINGS: KioskSettings = {
  defaultLang: 'hi',
  requireApproval: true,
  useCloudAi: true,
  capturePhoto: true,
  askVehicle: true,
  exitPin: '',
};

export function readKioskSettings(): KioskSettings {
  try {
    const raw = localStorage.getItem(KEY);
    if (!raw) return DEFAULT_KIOSK_SETTINGS;
    const parsed = JSON.parse(raw) as Partial<KioskSettings>;
    return { ...DEFAULT_KIOSK_SETTINGS, ...parsed };
  } catch {
    return DEFAULT_KIOSK_SETTINGS;
  }
}

export function writeKioskSettings(s: KioskSettings) {
  try {
    localStorage.setItem(KEY, JSON.stringify(s));
  } catch {
    /* private mode / storage full — settings stay for this session only */
  }
}

/** While the kiosk is running, the guard shell must not react to the Android back button. */
let kioskLocked = false;
export const setKioskLocked = (on: boolean) => { kioskLocked = on; };
export const isKioskLocked = () => kioskLocked;
