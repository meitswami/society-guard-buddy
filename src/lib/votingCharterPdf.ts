import { jsPDF } from 'jspdf';
import { fmtDateTimeFull } from '@/lib/dateFormat';
import translations, { type Lang } from '@/i18n/translations';
import {
  ELECTION_PROGRAM_STEPS,
  VOTING_CHARTER_SECTIONS,
  VOTING_CHARTER_TITLE_KEY,
} from '@/lib/votingCharter';

const FONT = 'NotoSansDevanagari';
const FONT_REG = 'NotoSansDevanagari-Regular.ttf';
const FONT_BOLD = 'NotoSansDevanagari-Bold.ttf';

/** Resolve charter copy for an explicit language. */
export function charterText(lang: Lang, key: string): string {
  const row = translations[key];
  if (!row) return key;
  const preferred = (row[lang] || '').trim();
  if (preferred) return preferred;
  return (row.en || row.hi || key).trim() || key;
}

function arrayBufferToBinaryString(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer);
  const chunk = 0x8000;
  let binary = '';
  for (let i = 0; i < bytes.length; i += chunk) {
    binary += String.fromCharCode(...bytes.subarray(i, Math.min(i + chunk, bytes.length)));
  }
  return binary;
}

let fontCache: { regular: string; bold: string } | null = null;

/** Fetch TTFs from /public/fonts and cache as binary strings for jsPDF VFS. */
async function loadDevanagariFonts(): Promise<{ regular: string; bold: string }> {
  if (fontCache) return fontCache;
  const [regRes, boldRes] = await Promise.all([
    fetch('/fonts/NotoSansDevanagari-Regular.ttf'),
    fetch('/fonts/NotoSansDevanagari-Bold.ttf'),
  ]);
  if (!regRes.ok || !boldRes.ok) {
    throw new Error(
      'Devanagari font files missing. Expected /fonts/NotoSansDevanagari-Regular.ttf and Bold.ttf',
    );
  }
  const [regBuf, boldBuf] = await Promise.all([regRes.arrayBuffer(), boldRes.arrayBuffer()]);
  fontCache = {
    regular: arrayBufferToBinaryString(regBuf),
    bold: arrayBufferToBinaryString(boldBuf),
  };
  return fontCache;
}

/** Embed Noto Sans Devanagari (regular + bold) into this PDF document. */
async function embedDevanagariFont(doc: jsPDF): Promise<void> {
  const fonts = await loadDevanagariFonts();
  doc.addFileToVFS(FONT_REG, fonts.regular);
  doc.addFont(FONT_REG, FONT, 'normal');
  doc.addFileToVFS(FONT_BOLD, fonts.bold);
  doc.addFont(FONT_BOLD, FONT, 'bold');
  doc.setFont(FONT, 'normal');
}

type PdfWriter = {
  doc: jsPDF;
  margin: number;
  maxW: number;
  pageH: number;
  y: number;
};

function ensureSpace(w: PdfWriter, need: number) {
  if (w.y + need > w.pageH - w.margin) {
    w.doc.addPage();
    w.doc.setFont(FONT, 'normal');
    w.y = w.margin;
  }
}

function setStyle(w: PdfWriter, style: 'normal' | 'bold', size: number, color: [number, number, number] = [26, 26, 26]) {
  w.doc.setFont(FONT, style);
  w.doc.setFontSize(size);
  w.doc.setTextColor(color[0], color[1], color[2]);
}

function writeWrapped(
  w: PdfWriter,
  text: string,
  opts: {
    style?: 'normal' | 'bold';
    size?: number;
    color?: [number, number, number];
    gap?: number;
    indent?: number;
    underline?: boolean;
  } = {},
) {
  const style = opts.style ?? 'normal';
  const size = opts.size ?? 10;
  const gap = opts.gap ?? size * 0.45;
  const indent = opts.indent ?? 0;
  setStyle(w, style, size, opts.color);
  const width = w.maxW - indent;
  const lines = w.doc.splitTextToSize(text, width) as string[];
  for (const line of lines) {
    ensureSpace(w, gap + 2);
    w.doc.text(line, w.margin + indent, w.y);
    if (opts.underline) {
      const tw = w.doc.getTextWidth(line);
      w.doc.setDrawColor(165, 180, 252);
      w.doc.setLineWidth(0.4);
      w.doc.line(w.margin + indent, w.y + 1.2, w.margin + indent + tw, w.y + 1.2);
    }
    w.y += gap;
  }
}

function hRule(w: PdfWriter, color: [number, number, number] = [199, 210, 254]) {
  ensureSpace(w, 6);
  w.doc.setDrawColor(color[0], color[1], color[2]);
  w.doc.setLineWidth(0.6);
  w.doc.line(w.margin, w.y, w.margin + w.maxW, w.y);
  w.y += 5;
}

function paraBreak(w: PdfWriter, mm = 3) {
  w.y += mm;
}

/**
 * Build Voting Charter PDF with Noto Sans Devanagari **embedded** in the file.
 * Hindi (`lang: 'hi'`) uses Devanagari translation strings drawn with that font.
 */
export async function buildVotingCharterPdfBlob(opts: {
  societyName?: string;
  lang?: Lang;
}): Promise<Blob> {
  const lang: Lang = opts.lang === 'hi' ? 'hi' : 'en';
  const t = (key: string) => charterText(lang, key);
  const isHi = lang === 'hi';

  const doc = new jsPDF({ unit: 'mm', format: 'a4', compress: true });
  await embedDevanagariFont(doc);

  const margin = 16;
  const pageW = doc.internal.pageSize.getWidth();
  const pageH = doc.internal.pageSize.getHeight();
  const maxW = pageW - 2 * margin;
  const w: PdfWriter = { doc, margin, maxW, pageH, y: margin };

  // —— Header ——
  writeWrapped(w, opts.societyName || (isHi ? 'सोसाइटी' : 'Society'), {
    style: 'bold',
    size: 11,
    color: [67, 56, 202],
    gap: 5,
  });
  writeWrapped(w, t(VOTING_CHARTER_TITLE_KEY), {
    style: 'bold',
    size: 16,
    color: [17, 24, 39],
    gap: 7,
  });
  const generated = fmtDateTimeFull(new Date().toISOString()) || new Date().toLocaleString();
  writeWrapped(
    w,
    `${isHi ? 'तैयार' : 'Generated'}: ${generated}  ·  ${isHi ? 'भाषा' : 'Language'}: ${isHi ? 'हिंदी' : 'English'}`,
    { style: 'normal', size: 8, color: [107, 114, 128], gap: 4 },
  );
  // Embedded-font note
  writeWrapped(
    w,
    isHi
      ? 'इस PDF में Noto Sans Devanagari फ़ॉन्ट एम्बेड है।'
      : 'This PDF embeds the Noto Sans Devanagari font for Hindi glyphs.',
    { style: 'normal', size: 7.5, color: [107, 114, 128], gap: 4 },
  );
  hRule(w);
  paraBreak(w, 2);

  // —— Program (ordered list) ——
  writeWrapped(w, t('votingCharter.program.heading'), {
    style: 'bold',
    size: 13,
    color: [49, 46, 129],
    gap: 6,
  });
  hRule(w, [224, 231, 255]);
  writeWrapped(w, t('votingCharter.program.intro'), {
    style: 'normal',
    size: 10,
    color: [75, 85, 99],
    gap: 5,
  });
  paraBreak(w, 2);

  ELECTION_PROGRAM_STEPS.forEach((step, i) => {
    ensureSpace(w, 14);
    // Number badge
    const cx = margin + 3.5;
    const cy = w.y - 1.2;
    doc.setFillColor(224, 231, 255);
    doc.circle(cx, cy, 3.2, 'F');
    setStyle(w, 'bold', 8, [55, 48, 163]);
    doc.text(String(i + 1), cx, cy + 1.1, { align: 'center' });

    writeWrapped(w, t(step.stepKey), {
      style: 'bold',
      size: 11,
      color: [17, 24, 39],
      gap: 5,
      indent: 10,
    });
    writeWrapped(w, t(step.detailKey), {
      style: 'normal',
      size: 9.5,
      color: [75, 85, 99],
      gap: 4.5,
      indent: 10,
    });
    paraBreak(w, 2.5);
  });

  paraBreak(w, 2);
  // —— Rules ——
  writeWrapped(w, t('votingCharter.rulesHeading'), {
    style: 'bold',
    size: 13,
    color: [49, 46, 129],
    gap: 6,
  });
  hRule(w, [224, 231, 255]);

  for (const sec of VOTING_CHARTER_SECTIONS) {
    paraBreak(w, 2);
    writeWrapped(w, t(sec.headingKey), {
      style: 'bold',
      size: 11,
      color: [30, 27, 75],
      gap: 5,
      underline: true,
    });
    for (const key of sec.pointKeys) {
      const bullet = isHi ? '•' : '•';
      // Bullet + body on same wrapped block with hanging indent
      ensureSpace(w, 6);
      setStyle(w, 'bold', 10, [79, 70, 229]);
      doc.text(bullet, margin + 1, w.y);
      writeWrapped(w, t(key), {
        style: 'normal',
        size: 9.5,
        color: [31, 41, 55],
        gap: 4.5,
        indent: 6,
      });
      paraBreak(w, 1);
    }
  }

  paraBreak(w, 4);
  hRule(w);
  writeWrapped(w, t('votingCharter.docs.p4'), {
    style: 'normal',
    size: 8.5,
    color: [107, 114, 128],
    gap: 4,
  });

  return doc.output('blob');
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
