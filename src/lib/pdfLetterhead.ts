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

function addressLine(info: SocietyLetterhead): string {
  const parts = [info.address, [info.city, info.state].filter(Boolean).join(', '), info.pincode]
    .map((p) => (p || '').trim())
    .filter(Boolean);
  return parts.join(' · ');
}

function contactLine(info: SocietyLetterhead): string {
  const parts = [info.contactPhone, info.contactEmail].map((p) => (p || '').trim()).filter(Boolean);
  return parts.join(' · ');
}

/** Load a remote image as a data URL for jsPDF (best-effort). */
export async function fetchImageDataUrl(url: string | null | undefined): Promise<string | null> {
  if (!url?.trim()) return null;
  try {
    const res = await fetch(url, { mode: 'cors' });
    if (!res.ok) return null;
    const blob = await res.blob();
    return await new Promise<string | null>((resolve) => {
      const reader = new FileReader();
      reader.onload = () => resolve(typeof reader.result === 'string' ? reader.result : null);
      reader.onerror = () => resolve(null);
      reader.readAsDataURL(blob);
    });
  } catch {
    return null;
  }
}

/** Fetch society branding fields used for report letterheads. */
export async function fetchSocietyLetterhead(societyId: string | null | undefined): Promise<SocietyLetterhead | null> {
  if (!societyId) return null;
  const { data, error } = await supabase
    .from('societies')
    .select(
      'name, logo_url, letterhead_url, letterhead_mode, letterhead_top_mm, letterhead_bottom_mm, address, city, state, pincode, contact_phone, contact_email',
    )
    .eq('id', societyId)
    .maybeSingle();
  if (error || !data) return null;
  const base: SocietyLetterhead = {
    name: data.name,
    logoUrl: data.logo_url,
    letterheadUrl: (data as { letterhead_url?: string | null }).letterhead_url,
    letterheadMode: (data as { letterhead_mode?: LetterheadMode }).letterhead_mode ?? 'auto',
    letterheadTopMm: Number((data as { letterhead_top_mm?: number }).letterhead_top_mm ?? 40),
    letterheadBottomMm: Number((data as { letterhead_bottom_mm?: number }).letterhead_bottom_mm ?? 18),
    address: data.address,
    city: data.city,
    state: data.state,
    pincode: data.pincode,
    contactPhone: data.contact_phone,
    contactEmail: data.contact_email,
  };
  return resolveLetterheadAssets(base);
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

/**
 * Draw letterhead on the current PDF page and return content layout.
 * Call again after every `doc.addPage()`.
 */
export function applyLetterheadPage(doc: jsPDF, info?: SocietyLetterhead | string | null): LetterheadLayout {
  const lh: SocietyLetterhead = !info
    ? fromNameOnly()
    : typeof info === 'string'
      ? fromNameOnly(info)
      : info;

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

  if (mode === 'image' && lh.letterheadDataUrl) {
    try {
      // Letterhead image across the top band (pre-formatted header).
      const bandH = Math.min(top, pageH * 0.35);
      doc.addImage(lh.letterheadDataUrl, 'PNG', 0, 0, pageW, bandH);
      return { margin, contentTop: bandH + 4, contentBottom, pageW, pageH };
    } catch {
      /* fall through to auto */
    }
  }

  // Auto digital letterhead: logo + society name + address
  let textX = margin;
  const logoSize = 16;
  if (lh.logoDataUrl) {
    try {
      doc.addImage(lh.logoDataUrl, 'PNG', margin, margin - 2, logoSize, logoSize);
      textX = margin + logoSize + 4;
    } catch {
      /* ignore logo */
    }
  }

  doc.setTextColor(17, 24, 39);
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(14);
  doc.text(lh.name || 'Society', textX, margin + 4);

  doc.setFont('helvetica', 'normal');
  doc.setFontSize(8);
  doc.setTextColor(75, 85, 99);
  let y = margin + 9;
  const addr = addressLine(lh);
  if (addr) {
    doc.text(addr, textX, y, { maxWidth: pageW - textX - margin });
    y += 4;
  }
  const contact = contactLine(lh);
  if (contact) {
    doc.text(contact, textX, y, { maxWidth: pageW - textX - margin });
    y += 4;
  }

  const ruleY = Math.max(y + 2, margin + logoSize + 2, top - 6);
  doc.setDrawColor(199, 210, 254);
  doc.setLineWidth(0.5);
  doc.line(margin, ruleY, pageW - margin, ruleY);

  // Footer rule for pre-formatted feel
  doc.setDrawColor(229, 231, 235);
  doc.line(margin, contentBottom, pageW - margin, contentBottom);

  doc.setTextColor(0, 0, 0);
  return {
    margin,
    contentTop: Math.max(ruleY + 6, top * 0.55),
    contentBottom,
    pageW,
    pageH,
  };
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
