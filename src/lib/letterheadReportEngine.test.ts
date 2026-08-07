import { describe, expect, it } from 'vitest';
import {
  beginSocietyReport,
  drawReportHeader,
  drawSignatureSection,
  ensureReportSpace,
  finalizeSocietyReport,
  LETTERHEAD_NOT_CONFIGURED_WARNING,
  measureReportLayout,
} from '@/lib/letterheadReportEngine';
import {
  applyLetterheadPage,
  letterheadEnsureSpace,
  measureLetterheadLayout,
  societyHasOfficialLetterhead,
  type SocietyLetterhead,
} from '@/lib/pdfLetterhead';
import { createSocietyPdf } from '@/lib/pdfPage';
import { buildMonthlyReportPdfBlob } from '@/lib/monthlyReportExport';

/** Tiny 1×1 PNG as a stand-in full-page letterhead asset. */
const TINY_PNG =
  'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

function societyA(): SocietyLetterhead {
  return {
    societyId: 'society-a',
    name: 'Alpha Cooperative Housing Society',
    letterheadMode: 'image',
    letterheadDataUrl: TINY_PNG,
    letterheadUrl: 'https://example.test/society-a/letterhead.png',
    letterheadTopMm: 48,
    letterheadBottomMm: 24,
    letterheadLeftMm: 20,
    letterheadRightMm: 20,
    defaultReportFormat: 'letterhead',
    address: 'Sector 1',
    city: 'Jaipur',
    state: 'Rajasthan',
    pincode: '302001',
  };
}

function societyB(): SocietyLetterhead {
  return {
    societyId: 'society-b',
    name: 'Beta Residency',
    letterheadMode: 'image',
    letterheadDataUrl: TINY_PNG,
    letterheadUrl: 'https://example.test/society-b/letterhead.png',
    letterheadTopMm: 40,
    letterheadBottomMm: 18,
    letterheadLeftMm: 19.05,
    letterheadRightMm: 19.05,
    defaultReportFormat: 'letterhead',
  };
}

describe('LetterheadReportEngine — safe content area', () => {
  it('exposes LetterheadLayout fields from the brief', () => {
    const layout = measureReportLayout(societyA(), 'letterhead');
    expect(layout.headerHeight).toBeGreaterThan(0);
    expect(layout.contentTop).toBeGreaterThanOrEqual(layout.headerHeight);
    expect(layout.contentBottom).toBeLessThan(layout.pageH);
    expect(layout.leftMargin).toBe(20);
    expect(layout.rightMargin).toBe(20);
    expect(layout.footerHeight).toBe(24);
    expect(layout.contentTop).toBe(48);
    expect(layout.contentWidth).toBeCloseTo(layout.pageW - 40, 5);
  });

  it('plain mode uses standard margins without requiring a letterhead asset', () => {
    const layout = measureReportLayout({ name: 'No Letterhead Society' }, 'plain');
    expect(layout.contentTop).toBeLessThan(30);
    expect(layout.contentBottom).toBeGreaterThan(layout.pageH - 20);
  });

  it('content never overlaps header or footer reserves across page breaks', () => {
    const lh = societyA();
    let renderer = beginSocietyReport(lh, { mode: 'letterhead' });
    expect(renderer.y).toBe(renderer.layout.contentTop);

    // Force many page breaks (10+ pages).
    for (let i = 0; i < 120; i++) {
      renderer = ensureReportSpace(renderer, 25);
      expect(renderer.y).toBeGreaterThanOrEqual(renderer.layout.contentTop);
      expect(renderer.y + 25).toBeLessThanOrEqual(renderer.layout.contentBottom + 0.01);
      renderer.doc.setFontSize(9);
      renderer.doc.text(`Row ${i}`, renderer.layout.leftMargin, renderer.y);
      renderer = { ...renderer, y: renderer.y + 22 };
    }

    const blob = finalizeSocietyReport(renderer);
    expect(blob.type).toBe('application/pdf');
    expect(renderer.doc.getNumberOfPages()).toBeGreaterThanOrEqual(10);
  });
});

describe('LetterheadReportEngine — report modes & multi-society', () => {
  it('marks official letterhead only when the current society has an asset', () => {
    expect(societyHasOfficialLetterhead(societyA())).toBe(true);
    expect(societyHasOfficialLetterhead({ name: 'Bare Society', letterheadMode: 'auto' })).toBe(false);
    expect(LETTERHEAD_NOT_CONFIGURED_WARNING).toContain('not been configured');
  });

  it('does not share letterhead assets across societies', () => {
    const a = societyA();
    const b = societyB();
    expect(a.societyId).not.toBe(b.societyId);
    expect(a.letterheadUrl).not.toBe(b.letterheadUrl);
    const layoutA = measureLetterheadLayout(createSocietyPdf(), a, { mode: 'letterhead' });
    const layoutB = measureLetterheadLayout(createSocietyPdf(), b, { mode: 'letterhead' });
    expect(layoutA.contentTop).toBe(48);
    expect(layoutB.contentTop).toBe(40);
  });

  it('draws report header + signatures inside the safe area', () => {
    let renderer = beginSocietyReport(societyA(), { mode: 'letterhead' });
    renderer = drawReportHeader(renderer, {
      title: 'Audit Report',
      reportNo: 'AR-2026-01',
      date: '07 Aug 2026',
      society: societyA().name,
      period: 'Jul 2026',
      generatedBy: 'Secretary',
    });
    expect(renderer.y).toBeGreaterThan(renderer.layout.contentTop);
    expect(renderer.y).toBeLessThan(renderer.layout.contentBottom);

    renderer = drawSignatureSection(renderer);
    expect(renderer.y).toBeLessThanOrEqual(renderer.layout.contentBottom + 0.01);
    const blob = finalizeSocietyReport(renderer);
    expect(blob.size).toBeGreaterThan(500);
  });
});

describe('LetterheadReportEngine — pagination & empty / long tables', () => {
  it('1-page report stays on a single page', () => {
    let renderer = beginSocietyReport(societyA(), { mode: 'letterhead' });
    renderer = drawReportHeader(renderer, { title: 'Short Report', society: 'Alpha' });
    renderer.doc.text('One line of content', renderer.layout.leftMargin, renderer.y);
    const blob = finalizeSocietyReport(renderer);
    expect(renderer.doc.getNumberOfPages()).toBe(1);
    expect(blob.size).toBeGreaterThan(200);
  });

  it('long table splits across pages without leaving the content band', () => {
    const lh = societyA();
    const doc = createSocietyPdf();
    let layout = applyLetterheadPage(doc, lh, { mode: 'letterhead' });
    let y = layout.contentTop;
    for (let i = 0; i < 80; i++) {
      const next = letterheadEnsureSpace(doc, layout, y, 8, lh, { mode: 'letterhead' });
      layout = next.layout;
      y = next.y;
      expect(y).toBeGreaterThanOrEqual(layout.contentTop);
      expect(y + 8).toBeLessThanOrEqual(layout.contentBottom + 0.01);
      doc.setFontSize(8);
      doc.text(`Flat ${i + 1} · dues · ₹${(i + 1) * 100}`, layout.leftMargin, y);
      y += 7;
    }
    expect(doc.getNumberOfPages()).toBeGreaterThan(1);
  });

  it('empty monthly report still produces a valid PDF with header', () => {
    const blob = buildMonthlyReportPdfBlob({
      societyName: 'Alpha Cooperative Housing Society',
      reportMonth: '2026-08',
      tab: 'financial',
      letterhead: societyA(),
      pdfMode: 'letterhead',
      financeEntries: [],
      financeGroups: [],
      includeSignatures: true,
    });
    expect(blob.type).toBe('application/pdf');
    expect(blob.size).toBeGreaterThan(400);
  });

  it('plain PDF mode works when society has no letterhead', () => {
    const blob = buildMonthlyReportPdfBlob({
      societyName: 'Unbranded Society',
      reportMonth: '2026-08',
      tab: 'visitor',
      letterhead: { name: 'Unbranded Society', letterheadMode: 'auto' },
      pdfMode: 'plain',
      visitors: [],
      includeSignatures: false,
    });
    expect(blob.type).toBe('application/pdf');
    expect(blob.size).toBeGreaterThan(200);
  });

  it('supports Unicode / Hindi title text in report header', () => {
    let renderer = beginSocietyReport(societyA(), { mode: 'letterhead' });
    renderer = drawReportHeader(renderer, {
      title: 'समिति के 7 सदस्यों का चुनाव',
      society: 'एवरग्रीन हाइट्स',
      period: 'अगस्त 2026',
    });
    const blob = finalizeSocietyReport(renderer);
    expect(blob.size).toBeGreaterThan(300);
  });
});
