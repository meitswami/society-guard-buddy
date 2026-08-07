import { jsPDF } from 'jspdf';

/**
 * Standard PDF / print page for all society downloads and displays.
 * US Letter (8.5×11") with moderate margins (~0.75" / 19.05 mm).
 */
export const PDF_PAGE_FORMAT = 'letter' as const;
export type PdfPageOrientation = 'portrait' | 'landscape';

/** Moderate margin in millimetres (0.75 inch). */
export const PDF_MARGIN_MM = 19.05;

/** Moderate margin in CSS inches for @page / print HTML. */
export const PDF_MARGIN_IN = '0.75in';

/** Content width for HTML→canvas Letter portrait renders (~96 dpi). */
export const PDF_LETTER_CONTENT_WIDTH_PX = 816;

/** Create a jsPDF document on Letter with mm units. */
export function createSocietyPdf(opts?: {
  orientation?: PdfPageOrientation;
  compress?: boolean;
}): jsPDF {
  return new jsPDF({
    unit: 'mm',
    format: PDF_PAGE_FORMAT,
    orientation: opts?.orientation ?? 'portrait',
    compress: opts?.compress ?? true,
  });
}

/** CSS snippet for browser print / print-preview windows. */
export function pdfPrintPageCss(extra = ''): string {
  return `@page { size: letter; margin: ${PDF_MARGIN_IN}; }
${extra}`;
}
