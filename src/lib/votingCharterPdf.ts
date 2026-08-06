import html2canvas from 'html2canvas';
import { jsPDF } from 'jspdf';
import { fmtDateTimeFull } from '@/lib/dateFormat';
import translations, { type Lang } from '@/i18n/translations';
import {
  ELECTION_PROGRAM_STEPS,
  VOTING_CHARTER_SECTIONS,
  VOTING_CHARTER_TITLE_KEY,
} from '@/lib/votingCharter';

/** Resolve charter copy for an explicit language. */
export function charterText(lang: Lang, key: string): string {
  const row = translations[key];
  if (!row) return key;
  const preferred = (row[lang] || '').trim();
  if (preferred) return preferred;
  return (row.en || row.hi || key).trim() || key;
}

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

/**
 * Build charter as HTML so the browser shapes Devanagari (conjuncts/matras).
 * jsPDF's TTF path cannot do OpenType shaping — Hindi looked broken/inauthentic.
 * English previously used Noto Sans Devanagari only (no Latin glyphs) → blank PDF.
 */
function buildCharterHtml(opts: {
  societyName?: string;
  lang: Lang;
}): string {
  const lang = opts.lang;
  const t = (key: string) => escapeHtml(charterText(lang, key));
  const isHi = lang === 'hi';
  const society = escapeHtml(opts.societyName?.trim() || (isHi ? 'सोसायटी' : 'Society'));
  const generated = escapeHtml(fmtDateTimeFull(new Date().toISOString()) || new Date().toLocaleString());

  const summaryPoints = (
    ['votingCharter.summary.voteRight', 'votingCharter.summary.proxy', 'votingCharter.summary.quorum'] as const
  )
    .map((key) => `<li>${t(key)}</li>`)
    .join('');

  const steps = ELECTION_PROGRAM_STEPS.map(
    (step, i) => `
      <div class="step">
        <div class="badge">${i + 1}</div>
        <div>
          <p class="step-title">${t(step.stepKey)}</p>
          <p class="step-detail">${t(step.detailKey)}</p>
        </div>
      </div>`,
  ).join('');

  const sections = VOTING_CHARTER_SECTIONS.map(
    (sec) => `
      <div class="section">
        <h3>${t(sec.headingKey)}</h3>
        <ul>
          ${sec.pointKeys.map((key) => `<li>${t(key)}</li>`).join('')}
        </ul>
      </div>`,
  ).join('');

  const fontStack = isHi
    ? "'Noto Sans Devanagari', 'Noto Sans', sans-serif"
    : "'Noto Sans', 'Noto Sans Devanagari', sans-serif";

  return `<!DOCTYPE html>
<html lang="${lang}">
<head>
<meta charset="utf-8"/>
<style>
  @font-face {
    font-family: 'Noto Sans';
    src: url('/fonts/NotoSans-Regular.ttf') format('truetype');
    font-weight: 400;
    font-style: normal;
  }
  @font-face {
    font-family: 'Noto Sans';
    src: url('/fonts/NotoSans-Bold.ttf') format('truetype');
    font-weight: 700;
    font-style: normal;
  }
  @font-face {
    font-family: 'Noto Sans Devanagari';
    src: url('/fonts/NotoSansDevanagari-Regular.ttf') format('truetype');
    font-weight: 400;
    font-style: normal;
  }
  @font-face {
    font-family: 'Noto Sans Devanagari';
    src: url('/fonts/NotoSansDevanagari-Bold.ttf') format('truetype');
    font-weight: 700;
    font-style: normal;
  }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    font-family: ${fontStack};
    color: #1a1a1a;
    font-size: 13px;
    line-height: 1.55;
    width: 794px;
    padding: 48px 56px;
    background: #fff;
    -webkit-font-smoothing: antialiased;
  }
  .society { color: #4338ca; font-weight: 700; font-size: 14px; margin-bottom: 6px; }
  h1 { font-size: 22px; font-weight: 700; color: #111827; margin-bottom: 6px; line-height: 1.35; }
  .meta { font-size: 11px; color: #6b7280; margin-bottom: 4px; }
  .note { font-size: 10px; color: #6b7280; margin-bottom: 14px; }
  hr { border: none; border-top: 1.5px solid #c7d2fe; margin: 12px 0 16px; }
  h2 { font-size: 16px; font-weight: 700; color: #312e81; margin: 18px 0 8px; }
  h2.rules { margin-top: 22px; }
  .summary-box {
    border: 1px solid #c7d2fe;
    background: #f8fafc;
    border-radius: 8px;
    padding: 12px 14px;
    margin-bottom: 8px;
  }
  .summary-box .posts { font-size: 13px; color: #1f2937; margin: 4px 0 8px; }
  .summary-box ul { padding-left: 18px; color: #374151; font-size: 12.5px; }
  .summary-box li { margin-bottom: 4px; }
  .intro { color: #4b5563; font-size: 13px; margin-bottom: 12px; }
  .step { display: flex; gap: 10px; margin-bottom: 12px; align-items: flex-start; }
  .badge {
    flex-shrink: 0;
    width: 22px; height: 22px;
    border-radius: 50%;
    background: #e0e7ff;
    color: #3730a3;
    font-weight: 700;
    font-size: 11px;
    display: flex; align-items: center; justify-content: center;
    margin-top: 1px;
  }
  .step-title { font-weight: 700; font-size: 14px; color: #111827; margin-bottom: 2px; }
  .step-detail { color: #4b5563; font-size: 12.5px; }
  .section { margin-bottom: 14px; }
  .section h3 {
    font-size: 13.5px;
    font-weight: 700;
    color: #1e1b4b;
    text-decoration: underline;
    text-underline-offset: 3px;
    margin-bottom: 6px;
  }
  .section ul { padding-left: 18px; }
  .section li { margin-bottom: 5px; color: #1f2937; font-size: 12.5px; }
  .footer { font-size: 11px; color: #6b7280; margin-top: 8px; }
</style>
</head>
<body>
  <p class="society">${society}</p>
  <h1>${t(VOTING_CHARTER_TITLE_KEY)}</h1>
  <p class="meta">${isHi ? 'तैयार' : 'Generated'}: ${generated}  ·  ${isHi ? 'भाषा' : 'Language'}: ${isHi ? 'हिन्दी' : 'English'}</p>
  <p class="note">${
    isHi
      ? 'इस पीडीएफ में देवनागरी लिपि ब्राउज़र द्वारा सही रूप से संयोजित है (नोतो सैंस देवनागरी)।'
      : 'This PDF uses Noto Sans for English. Hindi PDFs use browser-shaped Devanagari.'
  }</p>
  <hr/>

  <div class="summary-box">
    <h2 style="margin-top:0">${t('votingCharter.summary.title')}</h2>
    <p class="posts">${t('votingCharter.summary.posts')}</p>
    <ul>${summaryPoints}</ul>
  </div>

  <h2>${t('votingCharter.program.heading')}</h2>
  <hr style="margin-top:4px;margin-bottom:10px;border-top-color:#e0e7ff"/>
  <p class="intro">${t('votingCharter.program.intro')}</p>
  ${steps}

  <h2 class="rules">${t('votingCharter.rulesHeading')}</h2>
  <hr style="margin-top:4px;margin-bottom:10px;border-top-color:#e0e7ff"/>
  ${sections}

  <hr/>
  <p class="footer">${t('votingCharter.docs.p4')}</p>
</body>
</html>`;
}

/** Preload TTFs into the document so html2canvas paints with real glyphs. */
async function ensureFontsLoaded(doc: Document, isHi: boolean): Promise<void> {
  const faces: FontFace[] = isHi
    ? [
        new FontFace('Noto Sans Devanagari', "url('/fonts/NotoSansDevanagari-Regular.ttf')", { weight: '400' }),
        new FontFace('Noto Sans Devanagari', "url('/fonts/NotoSansDevanagari-Bold.ttf')", { weight: '700' }),
        new FontFace('Noto Sans', "url('/fonts/NotoSans-Regular.ttf')", { weight: '400' }),
        new FontFace('Noto Sans', "url('/fonts/NotoSans-Bold.ttf')", { weight: '700' }),
      ]
    : [
        new FontFace('Noto Sans', "url('/fonts/NotoSans-Regular.ttf')", { weight: '400' }),
        new FontFace('Noto Sans', "url('/fonts/NotoSans-Bold.ttf')", { weight: '700' }),
        new FontFace('Noto Sans Devanagari', "url('/fonts/NotoSansDevanagari-Regular.ttf')", { weight: '400' }),
      ];

  try {
    const loaded = await Promise.all(
      faces.map(async (face) => {
        const f = await face.load();
        doc.fonts.add(f);
        return f;
      }),
    );
    await doc.fonts.ready;
    // Warm glyph cache for Devanagari shaping
    if (isHi && loaded.length) {
      await doc.fonts.load("400 14px 'Noto Sans Devanagari'");
      await doc.fonts.load("700 16px 'Noto Sans Devanagari'");
    } else {
      await doc.fonts.load("400 14px 'Noto Sans'");
      await doc.fonts.load("700 16px 'Noto Sans'");
    }
  } catch {
    try {
      await doc.fonts.ready;
    } catch {
      /* ignore */
    }
  }
  await new Promise((r) => setTimeout(r, 100));
}

/** Slice a tall canvas into A4 PDF pages. */
function canvasToPdfBlob(canvas: HTMLCanvasElement): Blob {
  const pdf = new jsPDF({ unit: 'mm', format: 'a4', compress: true });
  const pageW = pdf.internal.pageSize.getWidth();
  const pageH = pdf.internal.pageSize.getHeight();
  const imgW = pageW;
  const pageCanvas = document.createElement('canvas');
  const pageCtx = pageCanvas.getContext('2d');
  if (!pageCtx) {
    throw new Error('Could not create canvas for PDF pages');
  }

  const pxPerMm = canvas.width / imgW;
  const pageHeightPx = Math.floor(pageH * pxPerMm);
  let yPx = 0;
  let pageIndex = 0;

  while (yPx < canvas.height) {
    const sliceH = Math.min(pageHeightPx, canvas.height - yPx);
    pageCanvas.width = canvas.width;
    pageCanvas.height = sliceH;
    pageCtx.fillStyle = '#ffffff';
    pageCtx.fillRect(0, 0, pageCanvas.width, pageCanvas.height);
    pageCtx.drawImage(canvas, 0, yPx, canvas.width, sliceH, 0, 0, canvas.width, sliceH);
    const sliceData = pageCanvas.toDataURL('image/jpeg', 0.92);
    const sliceHmm = sliceH / pxPerMm;
    if (pageIndex > 0) pdf.addPage();
    pdf.addImage(sliceData, 'JPEG', 0, 0, imgW, sliceHmm);
    yPx += sliceH;
    pageIndex += 1;
  }

  return pdf.output('blob');
}

/**
 * Build Voting Charter PDF.
 * English → Noto Sans (Latin). Hindi → browser-shaped Noto Sans Devanagari.
 */
export async function buildVotingCharterPdfBlob(opts: {
  societyName?: string;
  lang?: Lang;
}): Promise<Blob> {
  const lang: Lang = opts.lang === 'hi' ? 'hi' : 'en';
  const html = buildCharterHtml({ societyName: opts.societyName, lang });

  const iframe = document.createElement('iframe');
  iframe.setAttribute('aria-hidden', 'true');
  iframe.style.cssText =
    'position:fixed;left:-10000px;top:0;width:794px;height:1200px;border:0;opacity:0;pointer-events:none;';
  document.body.appendChild(iframe);

  try {
    const idoc = iframe.contentDocument;
    if (!idoc) throw new Error('Could not open PDF render frame');
    idoc.open();
    idoc.write(html);
    idoc.close();

    await ensureFontsLoaded(idoc, lang === 'hi');
    const body = idoc.body;
    if (!body) throw new Error('PDF render body missing');

    const canvas = await html2canvas(body, {
      scale: 2,
      useCORS: true,
      allowTaint: true,
      backgroundColor: '#ffffff',
      logging: false,
      windowWidth: 794,
      width: 794,
      onclone: (_clonedDoc, el) => {
        el.style.width = '794px';
        el.style.background = '#ffffff';
      },
    });

    if (!canvas.width || !canvas.height) {
      throw new Error('PDF canvas was empty');
    }

    return canvasToPdfBlob(canvas);
  } finally {
    iframe.remove();
  }
}

export function votingCharterShareMessage(lang: Lang = 'en'): string {
  return charterText(lang, 'votingCharter.shareMessage');
}

export function votingCharterPdfFilename(societyName?: string, lang: Lang = 'en'): string {
  const slug = (societyName || 'society')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
    .slice(0, 40);
  return `voting-charter-${lang}-${slug || 'society'}-${new Date().toISOString().slice(0, 10)}.pdf`;
}
