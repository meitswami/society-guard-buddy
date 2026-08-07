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

/** Matches Society letter Head.pdf: indigo header rule, charcoal footer rule. */
const HEADER_RULE: [number, number, number] = [55, 65, 120];
const FOOTER_RULE: [number, number, number] = [120, 125, 135];
const NAME_COLOR: [number, number, number] = [17, 24, 39];
const META_COLOR: [number, number, number] = [75, 85, 99];

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
  // Need room for footer rule + society name + page n/N (Society letter Head layout).
  return Number.isFinite(n) && n > 0 ? Math.max(n, 16) : 18;
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
 * Society letter Head.pdf layout — header band:
 *   Society name (bold)
 *   Address line
 *   Phone · email
 *   indigo rule
 * Footer band (below content):
 *   charcoal rule
 *   Society name (left) · page n/N (right)
 */
function drawAutoHeader(doc: jsPDF, lh: SocietyLetterhead, layout: LetterheadLayout): number {
  const { margin, pageW } = layout;
  // Text-only letterhead (Society letter Head.pdf) — logo only when present.
  let textX = margin;
  const logoSize = 14;
  if (lh.logoDataUrl) {
    try {
      doc.addImage(lh.logoDataUrl, dataUrlImageFormat(lh.logoDataUrl), margin, margin - 2, logoSize, logoSize);
      textX = margin + logoSize + 3.5;
    } catch (err) {
      console.warn('[letterhead] logo embed failed', err);
    }
  }

  const maxTextW = Math.max(40, pageW - textX - margin);

  doc.setTextColor(...NAME_COLOR);
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(15);
  doc.text(lh.name || 'Society', textX, margin + 4);

  doc.setFont('helvetica', 'normal');
  doc.setFontSize(8);
  doc.setTextColor(...META_COLOR);
  let y = margin + 9.5;
  const addr = letterheadAddressLine(lh);
  if (addr) {
    const lines = doc.splitTextToSize(addr, maxTextW) as string[];
    doc.text(lines, textX, y);
    y += Math.max(3.6, lines.length * 3.4);
  }
  const contact = letterheadContactLine(lh);
  if (contact) {
    const lines = doc.splitTextToSize(contact, maxTextW) as string[];
    doc.text(lines, textX, y);
    y += Math.max(3.6, lines.length * 3.4);
  }

  const ruleY = Math.min(Math.max(y + 2.5, margin + (lh.logoDataUrl ? logoSize : 6) + 2), layout.contentTop - 3);
  doc.setDrawColor(...HEADER_RULE);
  doc.setLineWidth(0.85);
  doc.line(margin, ruleY, pageW - margin, ruleY);
  return ruleY;
}

function drawFooterBand(
  doc: jsPDF,
  lh: SocietyLetterhead,
  layout: LetterheadLayout,
  pageNumber?: number,
  pageCount?: number,
): void {
  const { margin, contentBottom, pageW, pageH } = layout;

  // Clear footer band so body never shows through.
  doc.setFillColor(255, 255, 255);
  doc.rect(0, contentBottom - 0.5, pageW, pageH - contentBottom + 0.5, 'F');

  doc.setDrawColor(...FOOTER_RULE);
  doc.setLineWidth(0.7);
  doc.line(margin, contentBottom, pageW - margin, contentBottom);

  const footerTextY = Math.min(contentBottom + 5.2, pageH - 6);

  doc.setTextColor(...NAME_COLOR);
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(9);
  doc.text(lh.name || 'Society', margin, footerTextY);

  if (pageNumber != null && pageCount != null && pageCount > 0) {
    doc.setFont('helvetica', 'normal');
    doc.setFontSize(9);
    doc.setTextColor(...META_COLOR);
    doc.text(`${pageNumber}/${pageCount}`, pageW - margin, footerTextY, { align: 'right' });
  }

  doc.setTextColor(0, 0, 0);
}

/**
 * Compute letterhead content band without drawing.
 * Use this before placing body content so the reserved top/bottom bands stay clear.
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

  // Auto: estimate rule position including wrapped address/contact (Society letter Head).
  const logoSize = 14;
  const hasLogo = !!(lh.logoDataUrl || lh.logoUrl);
  const textX = hasLogo ? margin + logoSize + 3.5 : margin;
  const maxTextW = Math.max(40, pageW - textX - margin);
  let y = margin + 9.5;
  const addr = letterheadAddressLine(lh);
  if (addr) {
    const lines = doc.splitTextToSize(addr, maxTextW);
    y += Math.max(3.6, lines.length * 3.4);
  }
  const contact = letterheadContactLine(lh);
  if (contact) {
    const lines = doc.splitTextToSize(contact, maxTextW);
    y += Math.max(3.6, lines.length * 3.4);
  }
  const ruleY = Math.max(y + 2.5, margin + (hasLogo ? logoSize : 6) + 2, top - 8);
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
 * Draw Society letter Head layout on the current PDF page and return content layout.
 * Prefer drawing this AFTER body content (in the reserved bands) so nothing covers it.
 * Page numbers are stamped later via {@link finalizeLetterheadFooters} once total pages are known.
 */
export function applyLetterheadPage(doc: jsPDF, info?: SocietyLetterhead | string | null): LetterheadLayout {
  const lh = coerceLetterhead(info);
  const layout = measureLetterheadLayout(doc, lh);
  const { margin, contentTop, pageW, pageH } = layout;
  const mode = modeOf(lh);
  const top = Math.max(topReserve(lh), margin);

  // Stationery: leave top band blank for physical pre-printed paper; still reserve footer.
  if (mode === 'stationery') {
    drawFooterBand(doc, lh, layout);
    return layout;
  }

  if (mode === 'image' && lh.letterheadDataUrl) {
    try {
      const bandH = Math.min(top, pageH * 0.35, contentTop - 2);
      doc.addImage(lh.letterheadDataUrl, dataUrlImageFormat(lh.letterheadDataUrl), 0, 0, pageW, Math.max(bandH, 12));
      drawFooterBand(doc, lh, layout);
      return layout;
    } catch (err) {
      console.warn('[letterhead] image mode failed, falling back to auto', err);
      /* fall through to auto */
    }
  }

  drawAutoHeader(doc, lh, layout);
  drawFooterBand(doc, lh, layout);
  return layout;
}

/**
 * After all pages are built, stamp `n/N` page numbers into every footer
 * (Society letter Head.pdf style — e.g. 1/3).
 */
export function finalizeLetterheadFooters(doc: jsPDF, info?: SocietyLetterhead | string | null): void {
  const lh = coerceLetterhead(info);
  const total = doc.getNumberOfPages();
  for (let i = 1; i <= total; i++) {
    doc.setPage(i);
    const layout = measureLetterheadLayout(doc, lh);
    drawFooterBand(doc, lh, layout, i, total);
  }
  if (total > 0) doc.setPage(total);
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
