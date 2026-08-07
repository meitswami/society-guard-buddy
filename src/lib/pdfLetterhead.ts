import type { jsPDF } from 'jspdf';
import { PDF_MARGIN_MM } from '@/lib/pdfPage';
import { supabase } from '@/integrations/supabase/client';

export type LetterheadMode = 'auto' | 'image' | 'stationery';

export type SocietyLetterhead = {
  name: string;
  logoUrl?: string | null;
  letterheadUrl?: string | null;
  letterheadMode?: LetterheadMode | null;
  letterheadTopMm?: number | null;
  letterheadBottomMm?: number | null;
  address?: string | null;
  city?: string | null;
  state?: string | null;
  pincode?: string | null;
  contactPhone?: string | null;
  contactEmail?: string | null;
  /** Preloaded data URLs (optional; avoids CORS issues when set). */
  logoDataUrl?: string | null;
  letterheadDataUrl?: string | null;
};

export type LetterheadLayout = {
  margin: number;
  contentTop: number;
  contentBottom: number;
  pageW: number;
  pageH: number;
};

const FULL_SELECT =
  'name, logo_url, letterhead_url, letterhead_mode, letterhead_top_mm, letterhead_bottom_mm, address, city, state, pincode, contact_phone, contact_email';
const FALLBACK_SELECT = 'name, logo_url, address, city, state, pincode, contact_phone, contact_email';

function modeOf(info: SocietyLetterhead): LetterheadMode {
  const m = info.letterheadMode;
  if (m === 'image' || m === 'stationery' || m === 'auto') return m;
  return info.letterheadUrl || info.letterheadDataUrl ? 'image' : 'auto';
}

function topReserve(info: SocietyLetterhead): number {
  const n = Number(info.letterheadTopMm);
  return Number.isFinite(n) && n > 0 ? n : 40;
}

function bottomReserve(info: SocietyLetterhead): number {
  const n = Number(info.letterheadBottomMm);
  return Number.isFinite(n) && n > 0 ? n : 18;
}

export function letterheadAddressLine(info: Pick<SocietyLetterhead, 'address' | 'city' | 'state' | 'pincode'>): string {
  const parts = [info.address, [info.city, info.state].filter(Boolean).join(', '), info.pincode]
    .map((p) => (p || '').trim())
    .filter(Boolean);
  return parts.join(' · ');
}

export function letterheadContactLine(info: Pick<SocietyLetterhead, 'contactPhone' | 'contactEmail'>): string {
  const parts = [info.contactPhone, info.contactEmail].map((p) => (p || '').trim()).filter(Boolean);
  return parts.join(' · ');
}

/** Detect jsPDF image format from a data URL. */
export function dataUrlImageFormat(dataUrl: string): 'PNG' | 'JPEG' {
  if (dataUrl.includes('image/png') || dataUrl.startsWith('data:image/png')) return 'PNG';
  return 'JPEG';
}

function normalizeSocietyRow(data: Record<string, unknown>): SocietyLetterhead {
  return {
    name: String(data.name || 'Society'),
    logoUrl: (data.logo_url as string | null | undefined) ?? null,
    letterheadUrl: (data.letterhead_url as string | null | undefined) ?? null,
    letterheadMode: ((data.letterhead_mode as LetterheadMode | undefined) ?? 'auto') as LetterheadMode,
    letterheadTopMm: Number(data.letterhead_top_mm ?? 40),
    letterheadBottomMm: Number(data.letterhead_bottom_mm ?? 18),
    address: (data.address as string | null | undefined) ?? null,
    city: (data.city as string | null | undefined) ?? null,
    state: (data.state as string | null | undefined) ?? null,
    pincode: (data.pincode as string | null | undefined) ?? null,
    contactPhone: (data.contact_phone as string | null | undefined) ?? null,
    contactEmail: (data.contact_email as string | null | undefined) ?? null,
  };
}

/** Load a remote image as a data URL for jsPDF (best-effort). */
export async function fetchImageDataUrl(url: string | null | undefined): Promise<string | null> {
  if (!url?.trim()) return null;
  try {
    const res = await fetch(url, { mode: 'cors' });
    if (!res.ok) {
      console.warn('[letterhead] image fetch failed', url, res.status);
      return null;
    }
    const blob = await res.blob();
    return await new Promise<string | null>((resolve) => {
      const reader = new FileReader();
      reader.onload = () => resolve(typeof reader.result === 'string' ? reader.result : null);
      reader.onerror = () => resolve(null);
      reader.readAsDataURL(blob);
    });
  } catch (err) {
    console.warn('[letterhead] image fetch error', url, err);
    return null;
  }
}

/** Fetch society branding fields used for report letterheads. */
export async function fetchSocietyLetterhead(societyId: string | null | undefined): Promise<SocietyLetterhead | null> {
  if (!societyId) {
    console.warn('[letterhead] fetchSocietyLetterhead: missing societyId');
    return null;
  }

  let data: Record<string, unknown> | null = null;
  const primary = await supabase.from('societies').select(FULL_SELECT).eq('id', societyId).maybeSingle();
  if (primary.error) {
    console.warn('[letterhead] primary select failed, trying fallback columns', primary.error.message);
    const fallback = await supabase.from('societies').select(FALLBACK_SELECT).eq('id', societyId).maybeSingle();
    if (fallback.error || !fallback.data) {
      console.warn('[letterhead] fallback select failed', fallback.error?.message);
      return null;
    }
    data = fallback.data as Record<string, unknown>;
  } else if (!primary.data) {
    console.warn('[letterhead] no society row for', societyId);
    return null;
  } else {
    data = primary.data as Record<string, unknown>;
  }

  return resolveLetterheadAssets(normalizeSocietyRow(data));
}

/** Preload logo / letterhead images into data URLs. */
export async function resolveLetterheadAssets(info: SocietyLetterhead): Promise<SocietyLetterhead> {
  const [logoDataUrl, letterheadDataUrl] = await Promise.all([
    info.logoDataUrl || fetchImageDataUrl(info.logoUrl),
    info.letterheadDataUrl || fetchImageDataUrl(info.letterheadUrl),
  ]);
  return { ...info, logoDataUrl, letterheadDataUrl };
}

function fromNameOnly(name?: string): SocietyLetterhead {
  return { name: name?.trim() || 'Society', letterheadMode: 'auto' };
}

function coerceLetterhead(info?: SocietyLetterhead | string | null): SocietyLetterhead {
  if (!info) return fromNameOnly();
  if (typeof info === 'string') return fromNameOnly(info);
  return info;
}

/**
 * Compute letterhead content band without drawing.
 * Use this before placing body content so the reserved top band stays clear.
 */
export function measureLetterheadLayout(
  doc: jsPDF,
  info?: SocietyLetterhead | string | null,
): LetterheadLayout {
  const lh = coerceLetterhead(info);
  const pageW = doc.internal.pageSize.getWidth();
  const pageH = doc.internal.pageSize.getHeight();
  const margin = PDF_MARGIN_MM;
  const mode = modeOf(lh);
  const top = Math.max(topReserve(lh), margin);
  const bottom = Math.max(bottomReserve(lh), margin);
  const contentBottom = pageH - bottom;

  if (mode === 'stationery') {
    return { margin, contentTop: top, contentBottom, pageW, pageH };
  }

  if (mode === 'image' && (lh.letterheadDataUrl || lh.letterheadUrl)) {
    const bandH = Math.min(top, pageH * 0.35);
    return {
      margin,
      contentTop: Math.max(bandH + 4, top, margin),
      contentBottom,
      pageW,
      pageH,
    };
  }

  // Auto: estimate rule position including wrapped address/contact.
  const logoSize = 16;
  const hasLogo = !!(lh.logoDataUrl || lh.logoUrl);
  const textX = hasLogo ? margin + logoSize + 4 : margin;
  const maxTextW = Math.max(40, pageW - textX - margin);
  let y = margin + 10;
  const addr = letterheadAddressLine(lh);
  if (addr) {
    const lines = doc.splitTextToSize(addr, maxTextW);
    y += Math.max(4, lines.length * 3.5);
  }
  const contact = letterheadContactLine(lh);
  if (contact) {
    const lines = doc.splitTextToSize(contact, maxTextW);
    y += Math.max(4, lines.length * 3.5);
  }
  const ruleY = Math.max(y + 2, margin + (hasLogo ? logoSize : 8) + 2, top - 8);
  return {
    margin,
    // Always keep body below the configured top reserve so letterhead cannot be covered.
    contentTop: Math.max(ruleY + 6, top, margin),
    contentBottom,
    pageW,
    pageH,
  };
}

/**
 * Draw letterhead on the current PDF page and return content layout.
 * Prefer drawing this AFTER body content (in the reserved top band) so nothing covers it.
 */
export function applyLetterheadPage(doc: jsPDF, info?: SocietyLetterhead | string | null): LetterheadLayout {
  const lh = coerceLetterhead(info);
  const layout = measureLetterheadLayout(doc, lh);
  const { margin, contentTop, contentBottom, pageW, pageH } = layout;
  const mode = modeOf(lh);
  const top = Math.max(topReserve(lh), margin);

  // Stationery: leave top band blank for physical pre-printed paper.
  if (mode === 'stationery') {
    doc.setDrawColor(229, 231, 235);
    doc.setLineWidth(0.4);
    doc.line(margin, contentBottom, pageW - margin, contentBottom);
    doc.setTextColor(0, 0, 0);
    return layout;
  }

  if (mode === 'image' && lh.letterheadDataUrl) {
    try {
      const bandH = Math.min(top, pageH * 0.35, contentTop - 2);
      doc.addImage(lh.letterheadDataUrl, dataUrlImageFormat(lh.letterheadDataUrl), 0, 0, pageW, Math.max(bandH, 12));
      doc.setDrawColor(229, 231, 235);
      doc.line(margin, contentBottom, pageW - margin, contentBottom);
      doc.setTextColor(0, 0, 0);
      return layout;
    } catch (err) {
      console.warn('[letterhead] image mode failed, falling back to auto', err);
      /* fall through to auto */
    }
  }

  // Auto digital letterhead: logo + society name + address
  let textX = margin;
  const logoSize = 16;
  if (lh.logoDataUrl) {
    try {
      doc.addImage(lh.logoDataUrl, dataUrlImageFormat(lh.logoDataUrl), margin, margin - 2, logoSize, logoSize);
      textX = margin + logoSize + 4;
    } catch (err) {
      console.warn('[letterhead] logo embed failed', err);
    }
  }

  const maxTextW = Math.max(40, pageW - textX - margin);

  doc.setTextColor(17, 24, 39);
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(14);
  doc.text(lh.name || 'Society', textX, margin + 5);

  doc.setFont('helvetica', 'normal');
  doc.setFontSize(8);
  doc.setTextColor(75, 85, 99);
  let y = margin + 11;
  const addr = letterheadAddressLine(lh);
  if (addr) {
    const lines = doc.splitTextToSize(addr, maxTextW) as string[];
    doc.text(lines, textX, y);
    y += Math.max(4, lines.length * 3.5);
  }
  const contact = letterheadContactLine(lh);
  if (contact) {
    const lines = doc.splitTextToSize(contact, maxTextW) as string[];
    doc.text(lines, textX, y);
    y += Math.max(4, lines.length * 3.5);
  }

  const ruleY = Math.min(Math.max(y + 2, margin + logoSize + 2, top - 8), contentTop - 3);
  doc.setDrawColor(99, 102, 241);
  doc.setLineWidth(0.7);
  doc.line(margin, ruleY, pageW - margin, ruleY);

  doc.setDrawColor(229, 231, 235);
  doc.setLineWidth(0.4);
  doc.line(margin, contentBottom, pageW - margin, contentBottom);

  doc.setTextColor(0, 0, 0);
  return layout;
}

/** Ensure space; adds a letterheaded page when needed. */
export function letterheadEnsureSpace(
  doc: jsPDF,
  layout: LetterheadLayout,
  y: number,
  need: number,
  info?: SocietyLetterhead | string | null,
): { y: number; layout: LetterheadLayout } {
  if (y + need <= layout.contentBottom) return { y, layout };
  doc.addPage();
  const next = applyLetterheadPage(doc, info);
  return { y: next.contentTop, layout: next };
}
