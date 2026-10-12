import { describe, expect, it, vi } from 'vitest';

vi.mock('@/integrations/supabase/client', () => ({ supabase: { functions: { invoke: vi.fn() } } }));

import {
  LanguageChangedError,
  runKioskConversation,
  type KioskContext,
  type KioskDraft,
  type KioskInput,
  type KioskIO,
} from './kioskConversation';
import { DEFAULT_KIOSK_SETTINGS } from './kioskSettings';
import type { KioskCopyKey } from './kioskCopy';

type Scripted = KioskInput | Error;

const speech = (...alternatives: string[]): KioskInput => ({ kind: 'speech', alternatives });

function harness(script: Scripted[], overrides: Partial<KioskContext> = {}) {
  const said: KioskCopyKey[] = [];
  const typingStates: boolean[] = [];
  const queue = [...script];
  const io: KioskIO = {
    signal: new AbortController().signal,
    lang: () => 'hi',
    say: async (key) => { said.push(key); },
    hear: async () => {
      const next = queue.shift();
      if (!next) throw new Error(`script exhausted after: ${said.slice(-3).join(', ')}`);
      if (next instanceof Error) throw next;
      return next;
    },
    setStep: () => {},
    setDraft: () => {},
    setUnderstood: () => {},
    setTyping: (on) => { typingStates.push(on); },
  };
  const saved: KioskDraft[] = [];
  const ctx: KioskContext = {
    societyName: 'Green Park',
    societyId: 'soc-1',
    settings: { ...DEFAULT_KIOSK_SETTINGS, requireApproval: false, useCloudAi: false, capturePhoto: false },
    flatNumbers: ['A-604', 'B-604', 'C-101'],
    findPreviousVisit: () => null,
    isBlacklisted: () => false,
    capturePhoto: () => null,
    requestApproval: async () => 'approved',
    onApprovalTick: () => {},
    saveEntry: async (d) => { saved.push(d); return true; },
    ...overrides,
  };
  return { io, ctx, said, saved, typingStates, remaining: () => queue.length };
}

describe('runKioskConversation', () => {
  it('collects every detail from Hindi speech and saves the entry', async () => {
    const h = harness([
      speech('मेरा नाम राहुल शर्मा है'), speech('हाँ'),
      speech('नौ आठ सात छह पांच चार तीन दो एक शून्य'), { kind: 'yes' },
      speech('ए विंग छह सौ चार'), speech('हाँ सही है'),
      speech('अमेज़न का पार्सल'),
      speech('नहीं'),
      { kind: 'yes' },
    ]);
    await expect(runKioskConversation(h.io, h.ctx)).resolves.toBe('saved');
    expect(h.saved).toHaveLength(1);
    expect(h.saved[0]).toMatchObject({
      nameDisplay: 'राहुल शर्मा',
      name: 'Rahul Sharma',
      phone: '9876543210',
      flat: 'A-604',
      purpose: 'Delivery',
      company: 'Amazon',
      vehicle: null,
    });
    expect(h.said[0]).toBe('greeting');
    expect(h.said.at(-1)).toBe('done');
    expect(h.remaining()).toBe(0);
  });

  it('stops a blacklisted visitor before asking anything else', async () => {
    const h = harness(
      [speech('Rahul'), { kind: 'yes' }, speech('9876543210'), { kind: 'yes' }],
      { isBlacklisted: (phone) => phone === '9876543210' },
    );
    await expect(runKioskConversation(h.io, h.ctx)).resolves.toBe('blocked');
    expect(h.saved).toHaveLength(0);
    expect(h.said.at(-1)).toBe('blacklisted');
  });

  it('re-asks after a "no", a language switch and an unknown flat', async () => {
    const h = harness([
      speech('mera naam amit hai'), { kind: 'no' },
      new LanguageChangedError(),
      speech('my name is Amit Kumar'), { kind: 'yes' },
      speech('9123456789'), { kind: 'yes' },
      speech('flat 999'),
      speech('C 101'), { kind: 'yes' },
      speech('milne aaya hoon'),
      speech('haan'), speech('MH 02 AB 1234'), { kind: 'yes' },
      // Summary: change the flat by tapping, then confirm.
      { kind: 'edit', field: 'flat' }, speech('B 604'), { kind: 'yes' },
      { kind: 'yes' },
    ]);
    await expect(runKioskConversation(h.io, h.ctx)).resolves.toBe('saved');
    expect(h.saved[0]).toMatchObject({ name: 'Amit Kumar', phone: '9123456789', flat: 'B-604', purpose: 'Visit', vehicle: 'MH02AB1234' });
    expect(h.said).toContain('flatNotFound');
  });

  it('offers the keyboard after two silent answers and accepts typed text', async () => {
    const h = harness([
      speech(), speech(),
      { kind: 'text', text: 'Sunita Devi' },
      { kind: 'text', text: '9988776655' },
      { kind: 'text', text: 'A-604' },
      { kind: 'skip' },
      { kind: 'no' },
      { kind: 'yes' },
    ]);
    await expect(runKioskConversation(h.io, h.ctx)).resolves.toBe('saved');
    expect(h.said).toContain('typeInstead');
    expect(h.typingStates).toContain(true);
    expect(h.saved[0]).toMatchObject({ name: 'Sunita Devi', phone: '9988776655', flat: 'A-604', purpose: 'Other' });
  });

  it('suggests the previous flat to a returning visitor and waits for approval', async () => {
    const requestApproval = vi.fn(async () => 'approved' as const);
    const h = harness(
      [
        speech('Priya'), { kind: 'yes' },
        speech('9000000001'), { kind: 'yes' },
        { kind: 'yes' }, // same flat as last time
        speech('guest'),
        { kind: 'no' },
        { kind: 'yes' },
      ],
      {
        findPreviousVisit: () => ({ name: 'PRIYA', flatNumber: 'C-101' }),
        settings: { ...DEFAULT_KIOSK_SETTINGS, requireApproval: true, useCloudAi: false, capturePhoto: false },
        requestApproval,
      },
    );
    await expect(runKioskConversation(h.io, h.ctx)).resolves.toBe('saved');
    expect(h.said).toContain('askSameFlat');
    expect(h.said).not.toContain('askFlat');
    expect(requestApproval).toHaveBeenCalledOnce();
    expect(h.saved[0]).toMatchObject({ flat: 'C-101', purpose: 'Guest' });
  });

  it('does not save when the resident declines', async () => {
    const h = harness(
      [speech('Priya'), { kind: 'yes' }, speech('9000000001'), { kind: 'yes' }, speech('A 604'), { kind: 'yes' }, speech('visit'), { kind: 'no' }, { kind: 'yes' }],
      {
        settings: { ...DEFAULT_KIOSK_SETTINGS, requireApproval: true, useCloudAi: false, capturePhoto: false },
        requestApproval: async () => 'rejected',
      },
    );
    await expect(runKioskConversation(h.io, h.ctx)).resolves.toBe('rejected');
    expect(h.saved).toHaveLength(0);
  });
});
