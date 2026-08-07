import type { jsPDF } from 'jspdf';
import { PDF_MARGIN_MM } from '@/lib/pdfPage';
import { supabase } from '@/integrations/supabase/client';

export type LetterheadMode = 'auto' | 'image' | 'stationery';

/** User-facing PDF style: official society letterhead vs plain. */
export type ReportPdfMode = 'letterhead' | 'plain';

export type SocietyReportSettings = {
  defaultReportFormat: ReportPdfMode;
};

export type SocietyLetterhead = {
  name: string;
  societyId?: string | null;
  logoUrl?: string | null;
  letterheadUrl?: string | null;
  letterheadStoragePath?: string | null;
  letterheadMode?: LetterheadMode | null;
  letterheadTopMm?: number | null;
  letterheadBottomMm?: number | null;
  letterheadLeftMm?: number | null;
  letterheadRightMm?: number | null;
  defaultReportFormat?: ReportPdfMode | null;
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

/**
 * Safe content area for reports on letterhead stationery.
 * Content must never overlap the society header, date area, or footer.
 */
export type LetterheadLayout = {
  headerHeight: number;
  contentTop: number;
  contentBottom: number;
  leftMargin: number;
  rightMargin: number;
  footerHeight: number;
  pageW: number;
  pageH: number;
  /** @deprecated Use leftMargin — kept for existing report builders. */
  margin: number;
  contentWidth: number;
};

export type LetterheadDrawOptions = {
  mode?: ReportPdfMode;
};

/** Matches Society letter Head.pdf: indigo header rule, charcoal footer rule. */
const HEADER_RULE: [number, number, number] = [55, 65, 120];
const FOOTER_RULE: [number, number, number] = [120, 125, 135];
const NAME_COLOR: [number, number, number] = [17, 24, 39];
const META_COLOR: [number, number, number] = [75, 85, 99];

const FULL_SELECT =
  'id, name, logo_url, letterhead_url, letterhead_storage_path, letterhead_mode, letterhead_top_mm, letterhead_bottom_mm, letterhead_left_mm, letterhead_right_mm, default_report_format, address, city, state, pincode, contact_phone, contact_email';
const FALLBACK_SELECT =
  'id, name, logo_url, letterhead_url, letterhead_mode, letterhead_top_mm, letterhead_bottom_mm, address, city, state, pincode, contact_phone, contact_email';

function modeOf(info: SocietyLetterhead): LetterheadMode {
  const m = info.letterheadMode;
  if (m === 'image' || m === 'stationery' || m === 'auto') return m;
  return info.letterheadUrl || info.letterheadDataUrl || info.letterheadStoragePath ? 'image' : 'auto';
}

function topReserve(info: SocietyLetterhead): number {
  const n = Number(info.letterheadTopMm);
  return Number.isFinite(n) && n > 0 ? n : 40;
}

function bottomReserve(info: SocietyLetterhead): number {
  const n = Number(info.letterheadBottomMm);
  return Number.isFinite(n) && n > 0 ? Math.max(n, 16) : 18;
}

function leftReserve(info: SocietyLetterhead): number {
  const n = Number(info.letterheadLeftMm);
  return Number.isFinite(n) && n > 0 ? n : PDF_MARGIN_MM;
}

function rightReserve(info: SocietyLetterhead): number {
  const n = Number(info.letterheadRightMm);
  return Number.isFinite(n) && n > 0 ? n : PDF_MARGIN_MM;
}

function hasOfficialLetterheadAsset(info: SocietyLetterhead): boolean {
  return !!(info.letterheadDataUrl || info.letterheadUrl || info.letterheadStoragePath);
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
  const fmt = String(data.default_report_format ?? 'letterhead');
  return {
    societyId: (data.id as string | null | undefined) ?? null,
    name: String(data.name || 'Society'),
    logoUrl: (data.logo_url as string | null | undefined) ?? null,
    letterheadUrl: (data.letterhead_url as string | null | undefined) ?? null,
    letterheadStoragePath: (data.letterhead_storage_path as string | null | undefined) ?? null,
    letterheadMode: ((data.letterhead_mode as LetterheadMode | undefined) ?? 'auto') as LetterheadMode,
    letterheadTopMm: Number(data.letterhead_top_mm ?? 40),
    letterheadBottomMm: Number(data.letterhead_bottom_mm ?? 18),
    letterheadLeftMm: Number(data.letterhead_left_mm ?? PDF_MARGIN_MM),
    letterheadRightMm: Number(data.letterhead_right_mm ?? PDF_MARGIN_MM),
    defaultReportFormat: fmt === 'plain' ? 'plain' : 'letterhead',
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
    if (blob.type === 'application/pdf' || url.toLowerCase().includes('.pdf')) {
      // PDF stationery is stored for records; raster background requires an image upload.
      console.warn('[letterhead] PDF letterhead cannot be embedded as image background; upload a PNG/JPG scan');
      return null;
    }
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

async function signedUrlForStoragePath(path: string | null | undefined): Promise<string | null> {
  if (!path?.trim()) return null;
  const { data, error } = await supabase.storage.from('society-documents').createSignedUrl(path, 3600);
  if (error || !data?.signedUrl) {
    console.warn('[letterhead] signed URL failed', path, error?.message);
    return null;
  }
  return data.signedUrl;
}

/** Fetch society branding fields used for report letterheads (current society only). */
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

  const row = normalizeSocietyRow(data);
  // Hard multi-society guard: only assets belonging to this society id.
  if (row.societyId && row.societyId !== societyId) {
    console.error('[letterhead] society id mismatch — refusing letterhead', { societyId, rowId: row.societyId });
    return null;
  }
  row.societyId = societyId;
  return resolveLetterheadAssets(row);
}

/** Preload logo / letterhead images into data URLs. */
export async function resolveLetterheadAssets(info: SocietyLetterhead): Promise<SocietyLetterhead> {
  let letterheadUrl = info.letterheadUrl;
  if (!letterheadUrl && info.letterheadStoragePath) {
    letterheadUrl = await signedUrlForStoragePath(info.letterheadStoragePath);
  }
  const [logoDataUrl, letterheadDataUrl] = await Promise.all([
    info.logoDataUrl || fetchImageDataUrl(info.logoUrl),
    info.letterheadDataUrl || fetchImageDataUrl(letterheadUrl),
  ]);
  return { ...info, letterheadUrl, logoDataUrl, letterheadDataUrl };
}

function fromNameOnly(name?: string): SocietyLetterhead {
  return { name: name?.trim() || 'Society', letterheadMode: 'auto', defaultReportFormat: 'letterhead' };
}

function coerceLetterhead(info?: SocietyLetterhead | string | null): SocietyLetterhead {
  if (!info) return fromNameOnly();
  if (typeof info === 'string') return fromNameOnly(info);
  return info;
}

function isPlainMode(opts?: LetterheadDrawOptions): boolean {
  return opts?.mode === 'plain';
}

function buildLayout(
  pageW: number,
  pageH: number,
  left: number,
  right: number,
  headerHeight: number,
  footerHeight: number,
  contentTop: number,
  contentBottom: number,
): LetterheadLayout {
  return {
    headerHeight,
    footerHeight,
    contentTop,
    contentBottom,
    leftMargin: left,
    rightMargin: right,
    pageW,
    pageH,
    margin: left,
    contentWidth: Math.max(10, pageW - left - right),
  };
}

/**
 * Society letter Head.pdf layout — header band (auto mode only):
 *   Society name (bold) · Address · Phone · indigo rule
 * Footer band (below content) when not using full-page stationery image.
 */
function drawAutoHeader(doc: jsPDF, lh: SocietyLetterhead, layout: LetterheadLayout): number {
  const { leftMargin: margin, pageW, rightMargin } = layout;
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

  const maxTextW = Math.max(40, pageW - textX - rightMargin);

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
  doc.line(margin, ruleY, pageW - rightMargin, ruleY);
  return ruleY;
}

function drawFooterBand(
  doc: jsPDF,
  lh: SocietyLetterhead,
  layout: LetterheadLayout,
  pageNumber?: number,
  pageCount?: number,
  opts?: { clearBand?: boolean; drawRule?: boolean },
): void {
  const { leftMargin: margin, rightMargin, contentBottom, pageW, pageH } = layout;
  const clearBand = opts?.clearBand !== false;
  const drawRule = opts?.drawRule !== false;

  if (clearBand) {
    doc.setFillColor(255, 255, 255);
    doc.rect(0, contentBottom - 0.5, pageW, pageH - contentBottom + 0.5, 'F');
  }

  if (drawRule) {
    doc.setDrawColor(...FOOTER_RULE);
    doc.setLineWidth(0.7);
    doc.line(margin, contentBottom, pageW - rightMargin, contentBottom);
  }

  const footerTextY = Math.min(contentBottom + 5.2, pageH - 6);

  doc.setTextColor(...NAME_COLOR);
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(9);
  doc.text(lh.name || 'Society', margin, footerTextY);

  if (pageNumber != null && pageCount != null && pageCount > 0) {
    doc.setFont('helvetica', 'normal');
    doc.setFontSize(9);
    doc.setTextColor(...META_COLOR);
    doc.text(`${pageNumber}/${pageCount}`, pageW - rightMargin, footerTextY, { align: 'right' });
  }

  doc.setTextColor(0, 0, 0);
}

/** Draw uploaded letterhead as a full-page background (every page). */
function drawFullPageLetterheadBackground(doc: jsPDF, lh: SocietyLetterhead, layout: LetterheadLayout): boolean {
  if (!lh.letterheadDataUrl) return false;
  try {
    doc.addImage(
      lh.letterheadDataUrl,
      dataUrlImageFormat(lh.letterheadDataUrl),
      0,
      0,
      layout.pageW,
      layout.pageH,
    );
    return true;
  } catch (err) {
    console.warn('[letterhead] full-page background failed', err);
    return false;
  }
}

/**
 * Compute letterhead content band without drawing.
 * Use this before placing body content so the reserved top/bottom bands stay clear.
 */
export function measureLetterheadLayout(
  doc: jsPDF,
  info?: SocietyLetterhead | string | null,
  opts?: LetterheadDrawOptions,
): LetterheadLayout {
  const lh = coerceLetterhead(info);
  const pageW = doc.internal.pageSize.getWidth();
  const pageH = doc.internal.pageSize.getHeight();
  const left = leftReserve(lh);
  const right = rightReserve(lh);

  if (isPlainMode(opts)) {
    const top = PDF_MARGIN_MM;
    const bottom = Math.max(PDF_MARGIN_MM, 14);
    return buildLayout(pageW, pageH, left, right, top, bottom, top, pageH - bottom);
  }

  const top = Math.max(topReserve(lh), left);
  const bottom = Math.max(bottomReserve(lh), 14);
  const contentBottom = pageH - bottom;
  const brandMode = modeOf(lh);

  if (brandMode === 'stationery' || (brandMode === 'image' && hasOfficialLetterheadAsset(lh))) {
    // Full-page stationery / uploaded letterhead — safe content inside configured reserves.
    return buildLayout(pageW, pageH, left, right, top, bottom, top, contentBottom);
  }

  // Auto: estimate rule position including wrapped address/contact.
  const logoSize = 14;
  const hasLogo = !!(lh.logoDataUrl || lh.logoUrl);
  const textX = hasLogo ? left + logoSize + 3.5 : left;
  const maxTextW = Math.max(40, pageW - textX - right);
  let y = left + 9.5;
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
  const ruleY = Math.max(y + 2.5, left + (hasLogo ? logoSize : 6) + 2, top - 8);
  const contentTop = Math.max(ruleY + 6, top, left);
  return buildLayout(pageW, pageH, left, right, contentTop, bottom, contentTop, contentBottom);
}

/**
 * Draw letterhead on the current PDF page and return content layout.
 *
 * Official (`mode: 'letterhead'`) with an uploaded asset uses the letterhead as a
 * full-page background. Plain mode leaves a blank page with standard margins.
 * Page numbers are stamped later via {@link finalizeLetterheadFooters}.
 */
export function applyLetterheadPage(
  doc: jsPDF,
  info?: SocietyLetterhead | string | null,
  opts?: LetterheadDrawOptions,
): LetterheadLayout {
  const lh = coerceLetterhead(info);
  const layout = measureLetterheadLayout(doc, lh, opts);

  if (isPlainMode(opts)) {
    // Minimal plain footer page number only (no society stationery).
    return layout;
  }

  const brandMode = modeOf(lh);

  // Stationery: leave page blank for physical pre-printed paper; reserve safe area.
  if (brandMode === 'stationery') {
    return layout;
  }

  // Uploaded letterhead → full-page background on every page (do not recreate via HTML text).
  if (brandMode === 'image' && lh.letterheadDataUrl) {
    if (drawFullPageLetterheadBackground(doc, lh, layout)) {
      return layout;
    }
    // Fall through to auto if image embed fails.
  }

  // Auto digital band (only when no full-page letterhead image is available).
  drawAutoHeader(doc, lh, layout);
  drawFooterBand(doc, lh, layout, undefined, undefined, { clearBand: true, drawRule: true });
  return layout;
}

/**
 * After all pages are built, stamp `n/N` page numbers into every footer.
 * For full-page letterhead images, only the page number is added (no white wipe)
 * so the stationery footer / watermark stay visible.
 */
export function finalizeLetterheadFooters(
  doc: jsPDF,
  info?: SocietyLetterhead | string | null,
  opts?: LetterheadDrawOptions,
): void {
  const lh = coerceLetterhead(info);
  const total = doc.getNumberOfPages();
  const brandMode = modeOf(lh);
  const fullPageStationery =
    !isPlainMode(opts) && brandMode === 'image' && !!(lh.letterheadDataUrl || lh.letterheadUrl);

  for (let i = 1; i <= total; i++) {
    doc.setPage(i);
    const layout = measureLetterheadLayout(doc, lh, opts);

    if (isPlainMode(opts)) {
      const y = layout.pageH - 8;
      doc.setFont('helvetica', 'normal');
      doc.setFontSize(8);
      doc.setTextColor(...META_COLOR);
      doc.text(`${i}/${total}`, layout.pageW - layout.rightMargin, y, { align: 'right' });
      doc.setTextColor(0, 0, 0);
      continue;
    }

    if (brandMode === 'stationery' || fullPageStationery) {
      // Preserve letterhead artwork; only stamp page numbers in the footer reserve.
      const footerTextY = Math.min(layout.contentBottom + 5.2, layout.pageH - 6);
      doc.setFont('helvetica', 'normal');
      doc.setFontSize(8);
      doc.setTextColor(...META_COLOR);
      doc.text(`${i}/${total}`, layout.pageW - layout.rightMargin, footerTextY, { align: 'right' });
      doc.setTextColor(0, 0, 0);
      continue;
    }

    drawFooterBand(doc, lh, layout, i, total, { clearBand: true, drawRule: true });
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
  opts?: LetterheadDrawOptions,
): { y: number; layout: LetterheadLayout } {
  if (y + need <= layout.contentBottom) return { y, layout };
  doc.addPage();
  const next = applyLetterheadPage(doc, info, opts);
  return { y: next.contentTop, layout: next };
}

/** Whether this society has an uploaded official letterhead asset. */
export function societyHasOfficialLetterhead(info: SocietyLetterhead | null | undefined): boolean {
  if (!info) return false;
  return hasOfficialLetterheadAsset(info) || info.letterheadMode === 'stationery';
}
