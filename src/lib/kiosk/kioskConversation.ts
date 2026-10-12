/**
 * The AI receptionist's dialogue: asks each visitor detail by voice, reads it back,
 * and hands a finished draft to the page for approval + saving.
 * UI and browser APIs are injected through `KioskIO` / `KioskContext`.
 */
import { aiExtract, type KioskAiField } from './kioskAi';
import type { KioskCopyKey, KioskLang } from './kioskCopy';
import {
  firstParsed,
  formatPhoneForDisplay,
  parseEditField,
  parseFlat,
  parseName,
  parsePhone,
  parsePurpose,
  parseVehicleNumber,
  parseYesNo,
  phoneForSpeech,
  transliterateToLatin,
  type KioskEditField,
  type KioskPurpose,
} from './kioskParsers';
import { KioskAbortError, MicPermissionError } from './kioskSpeech';
import type { KioskSettings } from './kioskSettings';
import type { KioskApprovalOutcome } from './kioskApproval';

export class LanguageChangedError extends Error {
  constructor() {
    super('language changed');
    this.name = 'LanguageChangedError';
  }
}

export type KioskStep =
  | 'greeting' | 'name' | 'phone' | 'flat' | 'purpose' | 'vehicle'
  | 'summary' | 'approval' | 'saving' | 'done' | 'blocked' | 'failed';

export interface KioskDraft {
  /** As the visitor said it (may be Devanagari). */
  nameDisplay: string;
  /** Roman script, stored in the visitor log. */
  name: string;
  phone: string;
  flat: string;
  purpose: KioskPurpose | '';
  company?: string;
  /** null = no vehicle, undefined = not asked yet. */
  vehicle?: string | null;
  photo?: string;
}

export const EMPTY_DRAFT: KioskDraft = { nameDisplay: '', name: '', phone: '', flat: '', purpose: '' };

export type KioskInput =
  | { kind: 'speech'; alternatives: string[] }
  | { kind: 'text'; text: string }
  | { kind: 'yes' }
  | { kind: 'no' }
  | { kind: 'skip' }
  /** Visitor tapped "Type it" — stop listening and wait for the keyboard. */
  | { kind: 'typeMode' }
  | { kind: 'edit'; field: KioskEditField };

export interface KioskIO {
  signal: AbortSignal;
  lang: () => KioskLang;
  /** Show + speak a line. Rejects with LanguageChangedError if the visitor switches language. */
  say: (key: KioskCopyKey, vars?: Record<string, string>) => Promise<void>;
  /** Wait for the visitor: speech, typed text or a tap. */
  hear: (mode: 'field' | 'yesno', opts: { typing: boolean }) => Promise<KioskInput>;
  setStep: (step: KioskStep) => void;
  setDraft: (draft: KioskDraft) => void;
  /** Value the AI understood and is about to confirm (null clears). */
  setUnderstood: (text: string | null) => void;
  setTyping: (on: boolean) => void;
}

export interface KioskContext {
  societyName: string;
  societyId: string | null;
  settings: KioskSettings;
  flatNumbers: string[];
  findPreviousVisit: (phone: string) => { name: string; flatNumber: string } | null;
  isBlacklisted: (phone?: string, vehicle?: string) => boolean;
  capturePhoto: () => string | null;
  requestApproval: (draft: KioskDraft, onTick: (secondsLeft: number) => void) => Promise<KioskApprovalOutcome>;
  onApprovalTick: (secondsLeft: number) => void;
  saveEntry: (draft: KioskDraft) => Promise<boolean>;
}

export type KioskOutcome = 'saved' | 'blocked' | 'rejected' | 'timeout' | 'failed';

const RETRY = Symbol('retry');

/** "A-604" → "A 604" so the voice doesn't read the dash. */
const flatForSpeech = (flat: string) => flat.replace(/[-_/]+/g, ' ');

export async function runKioskConversation(io: KioskIO, ctx: KioskContext): Promise<KioskOutcome> {
  let draft: KioskDraft = { ...EMPTY_DRAFT };
  let micBlocked = false;
  const update = (patch: Partial<KioskDraft>) => {
    draft = { ...draft, ...patch };
    io.setDraft(draft);
  };
  const checkAbort = () => {
    if (io.signal.aborted) throw new KioskAbortError();
  };

  /** say() that tolerates a language switch (the caller re-asks). */
  const sayOrRetry = async (key: KioskCopyKey, vars?: Record<string, string>) => {
    try {
      await io.say(key, vars);
      return true;
    } catch (e) {
      if (e instanceof LanguageChangedError) return RETRY;
      throw e;
    }
  };

  const hearOrRetry = async (mode: 'field' | 'yesno', typing: boolean): Promise<KioskInput | typeof RETRY> => {
    try {
      return await io.hear(mode, { typing: typing || micBlocked });
    } catch (e) {
      if (e instanceof LanguageChangedError) return RETRY;
      if (e instanceof MicPermissionError) {
        micBlocked = true;
        io.setTyping(true);
        await sayOrRetry('noMic');
        return RETRY;
      }
      throw e;
    }
  };

  const ai = async (field: KioskAiField, alts: string[]) =>
    ctx.settings.useCloudAi
      ? aiExtract(field, alts, io.lang(), { flats: field === 'flat' ? ctx.flatNumbers : undefined, societyId: ctx.societyId })
      : null;

  /** Yes / no with taps, voice and AI fallback. Returns null if still unclear. */
  const confirm = async (key: KioskCopyKey, vars?: Record<string, string>): Promise<boolean | null> => {
    for (let attempt = 0; attempt < 3; attempt++) {
      checkAbort();
      if ((await sayOrRetry(attempt === 0 ? key : 'sayYesNo', vars)) === RETRY) { attempt--; continue; }
      if (attempt > 0 && (await sayOrRetry(key, vars)) === RETRY) { attempt--; continue; }
      const input = await hearOrRetry('yesno', false);
      if (input === RETRY) { attempt--; continue; }
      if (input.kind === 'yes') return true;
      if (input.kind === 'no' || input.kind === 'skip') return false;
      if (input.kind === 'typeMode' || input.kind === 'edit') { attempt--; continue; }
      const alts = input.kind === 'speech' ? input.alternatives : input.kind === 'text' ? [input.text] : [];
      if (!alts.length) continue;
      const local = firstParsed(alts, parseYesNo);
      if (local !== null) return local;
      const remote = await ai('yesno', alts);
      if (remote?.found) {
        if (/^(yes|true)$/i.test(remote.value)) return true;
        if (/^(no|false)$/i.test(remote.value)) return false;
      }
    }
    return null;
  };

  /**
   * Ask one detail until it is understood (and confirmed). After two misses the
   * on-screen keyboard is offered; typed answers are taken as confirmed.
   */
  async function ask<T>(opts: {
    step: KioskStep;
    prompt: KioskCopyKey;
    promptVars?: Record<string, string>;
    understand: (alts: string[], typed: boolean) => Promise<T | null>;
    /** Line spoken when the answer could not be used (defaults to didNotUnderstand). */
    notUnderstood?: (alts: string[]) => { key: KioskCopyKey; vars?: Record<string, string> };
    show: (v: T) => string;
    confirmLine?: (v: T) => { key: KioskCopyKey; vars?: Record<string, string> };
    allowSkip?: boolean;
  }): Promise<T | null> {
    io.setStep(opts.step);
    io.setUnderstood(null);
    let typing = micBlocked;
    let misses = 0;
    let prompt: { key: KioskCopyKey; vars?: Record<string, string> } = { key: opts.prompt, vars: opts.promptVars };
    let skipPrompt = false;
    io.setTyping(typing);
    try {
      for (;;) {
        checkAbort();
        if (!skipPrompt && (await sayOrRetry(prompt.key, prompt.vars)) === RETRY) {
          prompt = { key: opts.prompt, vars: opts.promptVars };
          continue;
        }
        skipPrompt = false;
        prompt = { key: opts.prompt, vars: opts.promptVars };
        const input = await hearOrRetry('field', typing);
        if (input === RETRY) continue;
        if (input.kind === 'skip' && opts.allowSkip) return null;
        if (input.kind === 'typeMode') {
          typing = true;
          io.setTyping(true);
          skipPrompt = true;
          continue;
        }
        if (input.kind === 'yes' || input.kind === 'no' || input.kind === 'edit' || input.kind === 'skip') continue;

        const typed = input.kind === 'text';
        const alts = input.kind === 'speech' ? input.alternatives : [input.text];
        if (!alts.length || !alts[0].trim()) {
          misses++;
          if (misses >= 2 && !typing) {
            typing = true;
            io.setTyping(true);
            await sayOrRetry('typeInstead');
          } else {
            await sayOrRetry('didNotHear');
          }
          continue;
        }

        const value = await opts.understand(alts, typed);
        checkAbort();
        if (value === null) {
          misses++;
          const line = opts.notUnderstood?.(alts) ?? { key: 'didNotUnderstand' as KioskCopyKey };
          await sayOrRetry(line.key, line.vars);
          if (misses >= 2 && !typing) {
            typing = true;
            io.setTyping(true);
            await sayOrRetry('typeInstead');
          }
          continue;
        }

        io.setUnderstood(opts.show(value));
        if (typed || !opts.confirmLine) return value;
        const line = opts.confirmLine(value);
        const ok = await confirm(line.key, line.vars);
        if (ok) return value;
        io.setUnderstood(null);
      }
    } finally {
      io.setTyping(false);
      io.setUnderstood(null);
    }
  }

  // ── individual details ──

  const askName = async () => {
    const v = await ask<{ display: string; latin: string }>({
      step: 'name',
      prompt: 'askName',
      understand: async (alts, typed) => {
        const local = typed ? alts[0].trim() || null : firstParsed(alts, parseName);
        const needsRoman = !local || /[ऀ-ॿ]/.test(local);
        if (needsRoman && !typed) {
          const remote = await ai('name', alts);
          if (remote?.found && remote.value) return { display: local ?? remote.value, latin: remote.value };
        }
        if (!local) return null;
        return { display: local, latin: transliterateToLatin(local) };
      },
      show: (v) => (v.display === v.latin ? v.display : `${v.display} (${v.latin})`),
      confirmLine: (v) => ({ key: 'confirmName', vars: { name: io.lang() === 'en' ? v.latin : v.display } }),
    });
    if (v) update({ nameDisplay: v.display, name: v.latin });
  };

  const askPhone = async () => {
    const phone = await ask<string>({
      step: 'phone',
      prompt: 'askPhone',
      understand: async (alts) => {
        const local = firstParsed(alts, parsePhone);
        if (local) return local;
        const remote = await ai('phone', alts);
        return remote?.found ? parsePhone(remote.value) : null;
      },
      show: formatPhoneForDisplay,
      confirmLine: (p) => ({ key: 'confirmPhone', vars: { phone: phoneForSpeech(p) } }),
    });
    if (phone) update({ phone });
  };

  const askFlat = async () => {
    let lastHeard = '';
    const flat = await ask<string>({
      step: 'flat',
      prompt: 'askFlat',
      understand: async (alts) => {
        lastHeard = '';
        for (const alt of alts) {
          const r = parseFlat(alt, ctx.flatNumbers);
          lastHeard = lastHeard || r.heard;
          if (r.flat) return r.flat;
        }
        const remote = await ai('flat', alts);
        if (remote?.found) {
          const r = parseFlat(remote.value, ctx.flatNumbers);
          if (r.flat) return r.flat;
        }
        return null;
      },
      notUnderstood: () =>
        lastHeard && ctx.flatNumbers.length
          ? { key: 'flatNotFound', vars: { flat: lastHeard } }
          : { key: 'didNotUnderstand' },
      show: (f) => f,
      confirmLine: (f) => ({ key: 'confirmFlat', vars: { flat: flatForSpeech(f) } }),
    });
    if (flat) update({ flat });
  };

  const askPurpose = async () => {
    let tries = 0;
    const v = await ask<{ purpose: KioskPurpose; company?: string }>({
      step: 'purpose',
      prompt: 'askPurpose',
      understand: async (alts) => {
        tries++;
        const local = firstParsed(alts, parsePurpose);
        if (local) return local;
        const remote = await ai('purpose', alts);
        if (remote?.found) {
          const known: KioskPurpose[] = ['Visit', 'Delivery', 'Meeting', 'Maintenance', 'Guest', 'Other'];
          const p = known.find((k) => k.toLowerCase() === remote.value.toLowerCase());
          if (p) return { purpose: p };
        }
        // Don't keep a visitor stuck on the purpose question.
        return tries >= 2 ? { purpose: 'Other' } : null;
      },
      show: (v) => v.purpose + (v.company ? ` · ${v.company}` : ''),
      allowSkip: true,
    });
    update({ purpose: v?.purpose ?? 'Other', company: v?.company });
  };

  const askVehicle = async () => {
    io.setStep('vehicle');
    const has = await confirm('askVehicle');
    if (!has) { update({ vehicle: null }); return; }
    const plate = await ask<string>({
      step: 'vehicle',
      prompt: 'askVehicleNumber',
      understand: async (alts, typed) => {
        const local = typed ? alts[0].toUpperCase().replace(/[^A-Z0-9]/g, '') || null : firstParsed(alts, parseVehicleNumber);
        if (local) return local;
        const remote = await ai('vehicle', alts);
        return remote?.found ? parseVehicleNumber(remote.value) : null;
      },
      show: (p) => p,
      confirmLine: (p) => ({ key: 'confirmVehicle', vars: { vehicle: p.split('').join(' ') } }),
      allowSkip: true,
    });
    update({ vehicle: plate });
  };

  const askField = async (field: KioskEditField) => {
    if (field === 'name') await askName();
    else if (field === 'phone') await askPhone();
    else if (field === 'flat') await askFlat();
    else if (field === 'purpose') await askPurpose();
    else await askVehicle();
  };

  const blocked = async () => {
    io.setStep('blocked');
    await sayOrRetry('blacklisted');
    return 'blocked' as const;
  };

  // ── the conversation ──

  io.setDraft(draft);
  io.setStep('greeting');
  if (ctx.settings.capturePhoto) {
    const photo = ctx.capturePhoto();
    if (photo) update({ photo });
  }
  await sayOrRetry('greeting', { society: ctx.societyName });

  while (!draft.name) await askName();
  while (!draft.phone) await askPhone();
  if (ctx.isBlacklisted(draft.phone)) return blocked();

  const previous = ctx.findPreviousVisit(draft.phone);
  if (previous?.flatNumber && (!ctx.flatNumbers.length || ctx.flatNumbers.includes(previous.flatNumber))) {
    io.setStep('flat');
    const same = await confirm('askSameFlat', { flat: flatForSpeech(previous.flatNumber) });
    if (same) update({ flat: previous.flatNumber });
  }
  while (!draft.flat) await askFlat();
  await askPurpose();
  if (ctx.settings.askVehicle) {
    await askVehicle();
    if (draft.vehicle && ctx.isBlacklisted(undefined, draft.vehicle)) return blocked();
  } else {
    update({ vehicle: null });
  }

  // Summary with corrections.
  for (let round = 0; round < 6; round++) {
    checkAbort();
    io.setStep('summary');
    if ((await sayOrRetry('summary')) === RETRY) continue;
    const input = await hearOrRetry('yesno', false);
    if (input === RETRY) continue;
    let field: KioskEditField | null = null;
    if (input.kind === 'yes') break;
    if (input.kind === 'edit') field = input.field;
    else if (input.kind === 'speech' || input.kind === 'text') {
      const alts = input.kind === 'speech' ? input.alternatives : [input.text];
      if (!alts.length) continue;
      field = firstParsed(alts, parseEditField);
      if (!field) {
        const yn = firstParsed(alts, parseYesNo);
        if (yn === true) break;
        if (yn === null) {
          const remote = await ai('editField', alts);
          if (remote?.found && ['name', 'phone', 'flat', 'purpose', 'vehicle'].includes(remote.value)) {
            field = remote.value as KioskEditField;
          } else if (remote?.found && remote.value === 'none') break;
        }
      }
    }
    if (!field) {
      io.setStep('summary');
      await sayOrRetry('whichField');
      const which = await hearOrRetry('field', false);
      if (which === RETRY) continue;
      if (which.kind === 'edit') field = which.field;
      else if (which.kind === 'speech' || which.kind === 'text') {
        const alts = which.kind === 'speech' ? which.alternatives : [which.text];
        field = firstParsed(alts, parseEditField);
      }
    }
    if (field) {
      if (field === 'phone') update({ phone: '' });
      await askField(field);
      while (!draft.name) await askName();
      while (!draft.phone) await askPhone();
      while (!draft.flat) await askFlat();
      if (ctx.isBlacklisted(draft.phone, draft.vehicle ?? undefined)) return blocked();
    }
  }

  if (ctx.settings.requireApproval) {
    io.setStep('approval');
    await sayOrRetry('askingResident', { flat: flatForSpeech(draft.flat) });
    const outcome = await ctx.requestApproval(draft, ctx.onApprovalTick);
    checkAbort();
    if (outcome === 'approved') await sayOrRetry('approved');
    else if (outcome === 'rejected') {
      io.setStep('failed');
      await sayOrRetry('rejected');
      return 'rejected';
    } else if (outcome === 'timeout') {
      io.setStep('failed');
      await sayOrRetry('approvalTimeout');
      return 'timeout';
    }
    // 'no_flat': flat not in the society table — save directly, as the manual form does.
  }

  io.setStep('saving');
  const saved = await ctx.saveEntry(draft);
  if (!saved) {
    io.setStep('failed');
    await sayOrRetry('saveFailed');
    return 'failed';
  }
  io.setStep('done');
  await sayOrRetry('done', { name: io.lang() === 'en' ? draft.name : draft.nameDisplay || draft.name });
  return 'saved';
}
