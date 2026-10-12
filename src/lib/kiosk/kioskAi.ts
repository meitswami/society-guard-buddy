import { supabase } from '@/integrations/supabase/client';
import type { KioskLang } from './kioskCopy';

export type KioskAiField = 'name' | 'phone' | 'flat' | 'purpose' | 'vehicle' | 'yesno' | 'editField';

export interface KioskAiResult {
  found: boolean;
  value: string;
}

/** After a failure (no API key, offline), stop calling for a while. */
let disabledUntil = 0;

/**
 * Ask the `kiosk-assistant` Edge Function to read a transcript. Returns null when the
 * function is unavailable or slow — callers always have a local fallback.
 */
export async function aiExtract(
  field: KioskAiField,
  transcripts: string[],
  lang: KioskLang,
  context?: { flats?: string[]; societyId?: string | null },
  timeoutMs = 5000,
): Promise<KioskAiResult | null> {
  if (Date.now() < disabledUntil) return null;
  const transcript = transcripts.filter(Boolean).slice(0, 3);
  if (!transcript.length) return null;
  try {
    const call = supabase.functions.invoke<KioskAiResult>('kiosk-assistant', {
      body: {
        field,
        transcripts: transcript,
        lang,
        flats: context?.flats?.slice(0, 800),
        society_id: context?.societyId ?? null,
      },
    });
    const timeout = new Promise<null>((resolve) => setTimeout(() => resolve(null), timeoutMs));
    const res = await Promise.race([call, timeout]);
    if (!res) return null;
    if (res.error || !res.data || typeof res.data.found !== 'boolean') {
      disabledUntil = Date.now() + 5 * 60_000;
      return null;
    }
    return { found: res.data.found, value: String(res.data.value ?? '').trim() };
  } catch {
    disabledUntil = Date.now() + 5 * 60_000;
    return null;
  }
}
