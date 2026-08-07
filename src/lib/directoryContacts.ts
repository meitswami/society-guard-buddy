/** Shared directory contact normalization & resolution helpers. */

export function normalizeWhatsAppPhone(raw: string | null | undefined): string | null {
  if (!raw?.trim()) return null;
  let digits = raw.replace(/\D/g, '');
  if (digits.length === 10) digits = `91${digits}`;
  if (digits.length < 11 || digits.length > 15) return null;
  return digits;
}

export function normalizeEmail(raw: string | null | undefined): string | null {
  const v = raw?.trim().toLowerCase() ?? '';
  if (!v) return null;
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v)) return null;
  return v;
}

export type DirectoryMemberContact = {
  id?: string;
  flatId?: string;
  flatNumber?: string;
  name?: string | null;
  phone?: string | null;
  whatsappPhone?: string | null;
  email?: string | null;
  notifyWhatsapp?: boolean | null;
  notifyEmail?: boolean | null;
  isPrimary?: boolean | null;
};

export type ResolvedChannelTargets = {
  whatsapp: string[];
  emails: string[];
};

/**
 * Resolve WhatsApp + email targets from directory members (primary first).
 * WhatsApp: whatsapp_phone → phone (respects notify_whatsapp).
 * Email: member.email (respects notify_email).
 */
export function resolveMemberChannelTargets(
  members: DirectoryMemberContact[],
  opts?: { whatsapp?: boolean; email?: boolean },
): ResolvedChannelTargets {
  const wantWa = opts?.whatsapp !== false;
  const wantEmail = opts?.email !== false;
  const wa = new Set<string>();
  const emails = new Set<string>();

  const sorted = [...members].sort((a, b) => Number(!!b.isPrimary) - Number(!!a.isPrimary));
  for (const m of sorted) {
    if (wantWa && m.notifyWhatsapp !== false) {
      const p = normalizeWhatsAppPhone(m.whatsappPhone ?? m.phone);
      if (p) wa.add(p);
    }
    if (wantEmail && m.notifyEmail !== false) {
      const e = normalizeEmail(m.email);
      if (e) emails.add(e);
    }
  }
  return { whatsapp: [...wa], emails: [...emails] };
}
