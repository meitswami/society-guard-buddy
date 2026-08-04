import { jsPDF } from 'jspdf';
import { fmtDateTimeFull } from '@/lib/dateFormat';
import translations, { type Lang } from '@/i18n/translations';
import {
  ELECTION_PROGRAM_STEPS,
  VOTING_CHARTER_SECTIONS,
  VOTING_CHARTER_TITLE_KEY,
} from '@/lib/votingCharter';

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

/** Resolve charter copy for an explicit language (never falls back to the other language first). */
export function charterText(lang: Lang, key: string): string {
  const row = translations[key];
  if (!row) return key;
  const preferred = (row[lang] || '').trim();
  if (preferred) return preferred;
  return (row.en || row.hi || key).trim() || key;
}

function hasDevanagari(s: string): boolean {
  return /[\u0900-\u097F]/.test(s);
}

/** Ensure Devanagari + Latin Noto fonts are available for canvas capture. */
async function ensureCharterFonts(): Promise<void> {
  const styleId = 'kutumbika-charter-font-face';
  if (!document.getElementById(styleId)) {
    const style = document.createElement('style');
    style.id = styleId;
    style.textContent = `
      @font-face {
        font-family: 'Noto Sans Devanagari';
        src: url('/fonts/NotoSansDevanagari-Regular.ttf') format('truetype');
        font-weight: 400;
        font-style: normal;
        font-display: swap;
      }
      @font-face {
        font-family: 'Noto Sans Devanagari';
        src: url('/fonts/NotoSansDevanagari-Medium.ttf') format('truetype');
        font-weight: 500;
        font-style: normal;
        font-display: swap;
      }
      @font-face {
        font-family: 'Noto Sans Devanagari';
        src: url('/fonts/NotoSansDevanagari-Medium.ttf') format('truetype');
        font-weight: 600;
        font-style: normal;
        font-display: swap;
      }
      @font-face {
        font-family: 'Noto Sans Devanagari';
        src: url('/fonts/NotoSansDevanagari-Bold.ttf') format('truetype');
        font-weight: 700;
        font-style: normal;
        font-display: swap;
      }
      @font-face {
        font-family: 'Noto Sans';
        src: url('/fonts/NotoSans-Regular.ttf') format('truetype');
        font-weight: 400;
        font-style: normal;
        font-display: swap;
      }
      @font-face {
        font-family: 'Noto Sans';
        src: url('/fonts/NotoSans-Bold.ttf') format('truetype');
        font-weight: 700;
        font-style: normal;
        font-display: swap;
      }
    `;
    document.head.appendChild(style);
  }

  const id = 'kutumbika-charter-fonts-cdn';
  if (!document.getElementById(id)) {
    const link = document.createElement('link');
    link.id = id;
    link.rel = 'stylesheet';
    link.href =
      'https://fonts.googleapis.com/css2?family=Noto+Sans+Devanagari:wght@400;500;600;700&family=Noto+Sans:wght@400;700&display=swap';
    document.head.appendChild(link);
  }

  try {
    await Promise.all([
      document.fonts.load("400 16px 'Noto Sans Devanagari'"),
      document.fonts.load("600 16px 'Noto Sans Devanagari'"),
      document.fonts.load("700 16px 'Noto Sans Devanagari'"),
      document.fonts.load("400 16px 'Noto Sans'"),
      document.fonts.load("700 16px 'Noto Sans'"),
    ]);
  } catch {
    /* continue */
  }
  await document.fonts.ready;
  await new Promise((r) => setTimeout(r, 200));
}

function buildCharterHtml(opts: {
  societyName: string;
  lang: Lang;
  generatedAt: string;
}): string {
  const { societyName, lang, generatedAt } = opts;
  const t = (key: string) => charterText(lang, key);
  const isHi = lang === 'hi';
  const langLabel = isHi ? 'हिंदी' : 'English';

  const steps = ELECTION_PROGRAM_STEPS.map(
    (step, i) => `
      <li class="step">
        <div class="step-num">${i + 1}</div>
        <div class="step-body">
          <h4>${escapeHtml(t(step.stepKey))}</h4>
          <p>${escapeHtml(t(step.detailKey))}</p>
        </div>
      </li>`,
  ).join('');

  const sections = VOTING_CHARTER_SECTIONS.map(
    (sec) => `
      <section class="rule-section">
        <h3>${escapeHtml(t(sec.headingKey))}</h3>
        <ul>
          ${sec.pointKeys.map((k) => `<li><span>${escapeHtml(t(k))}</span></li>`).join('')}
        </ul>
      </section>`,
  ).join('');

  return `
<div class="charter-root" lang="${lang}" dir="ltr" data-charter-lang="${lang}">
  <header class="charter-header">
    <p class="eyebrow">${escapeHtml(societyName || (isHi ? 'सोसाइटी' : 'Society'))}</p>
    <h1>${escapeHtml(t(VOTING_CHARTER_TITLE_KEY))}</h1>
    <p class="meta"><em>${isHi ? 'तैयार' : 'Generated'}: ${escapeHtml(generatedAt)}</em>
      · <strong>${isHi ? 'भाषा' : 'Language'}: ${langLabel}</strong></p>
    <hr />
  </header>

  <section class="program">
    <h2>${escapeHtml(t('votingCharter.program.heading'))}</h2>
    <p class="lead">${escapeHtml(t('votingCharter.program.intro'))}</p>
    <ol class="steps">
      ${steps}
    </ol>
  </section>

  <section class="rules">
    <h2>${escapeHtml(t('votingCharter.rulesHeading'))}</h2>
    ${sections}
  </section>

  <footer class="charter-footer">
    <hr />
    <p><em>${escapeHtml(t('votingCharter.docs.p4'))}</em></p>
  </footer>
</div>`;
}

const CHARTER_CSS = `
.charter-root {
  box-sizing: border-box;
  width: 720px;
  padding: 28px 32px 36px;
  color: #1a1a1a;
  background: #ffffff;
  font-family: 'Noto Sans Devanagari', 'Noto Sans', 'Segoe UI', sans-serif;
  font-size: 13px;
  line-height: 1.55;
  -webkit-font-smoothing: antialiased;
}
.charter-root * { box-sizing: border-box; margin: 0; padding: 0; }
.charter-header { margin-bottom: 18px; }
.eyebrow {
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: #4338ca;
  margin-bottom: 6px;
}
h1 {
  font-size: 22px;
  font-weight: 700;
  line-height: 1.3;
  color: #111827;
  margin-bottom: 8px;
}
.meta {
  font-size: 11px;
  color: #6b7280;
  margin-bottom: 12px;
}
.meta em { font-style: italic; }
.meta strong { font-weight: 600; color: #374151; }
hr {
  border: none;
  border-top: 1.5px solid #c7d2fe;
  margin: 12px 0 0;
}
h2 {
  font-size: 15px;
  font-weight: 700;
  color: #312e81;
  margin: 18px 0 8px;
  padding-bottom: 4px;
  border-bottom: 1px solid #e0e7ff;
}
h3 {
  font-size: 13px;
  font-weight: 700;
  color: #1e1b4b;
  margin: 14px 0 6px;
  text-decoration: underline;
  text-underline-offset: 3px;
  text-decoration-color: #a5b4fc;
}
h4 {
  font-size: 13px;
  font-weight: 700;
  color: #111827;
  margin-bottom: 3px;
}
.lead {
  font-size: 12.5px;
  color: #4b5563;
  margin-bottom: 12px;
  line-height: 1.6;
}
.steps {
  list-style: none;
  display: block;
}
.step {
  display: flex;
  gap: 12px;
  align-items: flex-start;
  margin-bottom: 12px;
  page-break-inside: avoid;
}
.step-num {
  flex: 0 0 24px;
  width: 24px;
  height: 24px;
  border-radius: 999px;
  background: #e0e7ff;
  color: #3730a3;
  font-size: 11px;
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
  line-height: 24px;
  text-align: center;
}
.step-body p {
  font-size: 12px;
  color: #4b5563;
  line-height: 1.55;
}
.rule-section ul {
  list-style: none;
  margin: 0 0 4px 2px;
  padding: 0;
}
.rule-section li {
  position: relative;
  padding-left: 16px;
  margin-bottom: 6px;
  font-size: 12px;
  color: #1f2937;
  line-height: 1.55;
}
.rule-section li::before {
  content: '•';
  position: absolute;
  left: 2px;
  top: 0;
  color: #4f46e5;
  font-weight: 700;
}
.charter-footer {
  margin-top: 20px;
}
.charter-footer p {
  font-size: 11px;
  color: #6b7280;
  margin-top: 10px;
}
.charter-footer em { font-style: italic; }
`;

/**
 * Build a Voting Charter PDF in the requested language.
 * Uses HTML + Noto Devanagari so Hindi conjuncts render correctly.
 * Always resolves copy from static translations for `lang` (does not use UI `t()`,
 * which can fall back to English overrides).
 */
export async function buildVotingCharterPdfBlob(opts: {
  societyName?: string;
  lang?: Lang;
}): Promise<Blob> {
  const lang: Lang = opts.lang === 'hi' ? 'hi' : 'en';

  // Sanity: Hindi must resolve to Devanagari title before we render.
  const title = charterText(lang, VOTING_CHARTER_TITLE_KEY);
  if (lang === 'hi' && !hasDevanagari(title)) {
    throw new Error('Hindi charter translations are missing Devanagari text');
  }

  await ensureCharterFonts();

  const host = document.createElement('div');
  host.setAttribute('data-voting-charter-pdf', '1');
  host.style.cssText =
    'position:fixed;left:-10000px;top:0;width:720px;background:#fff;z-index:-1;pointer-events:none;';

  const wrap = document.createElement('div');
  wrap.innerHTML = buildCharterHtml({
    societyName: opts.societyName || '',
    lang,
    generatedAt: fmtDateTimeFull(new Date().toISOString()) || new Date().toLocaleString(),
  });

  const root = wrap.querySelector('.charter-root') as HTMLElement | null;
  if (!root) {
    wrap.remove();
    throw new Error('Charter HTML failed to render');
  }

  // Confirm DOM actually contains Hindi when requested (guards against wrong lang).
  if (lang === 'hi' && !hasDevanagari(root.textContent || '')) {
    host.remove();
    throw new Error('Hindi charter HTML did not contain Devanagari text');
  }

  const styleEl = document.createElement('style');
  styleEl.textContent = CHARTER_CSS;
  root.insertBefore(styleEl, root.firstChild);
  host.appendChild(wrap);
  document.body.appendChild(host);

  try {
    const doc = new jsPDF({ unit: 'pt', format: 'a4', compress: true });
    const pageW = doc.internal.pageSize.getWidth();
    const margin = 36;
    const contentW = pageW - margin * 2;

    await doc.html(root, {
      margin: [margin, margin, margin, margin],
      autoPaging: 'text',
      width: contentW,
      windowWidth: 720,
      html2canvas: {
        scale: 1.5,
        useCORS: true,
        allowTaint: true,
        backgroundColor: '#ffffff',
        logging: false,
        onclone: (_doc, el) => {
          // Force computed font on clone so html2canvas paints Devanagari glyphs.
          const node = el as HTMLElement;
          node.style.fontFamily = "'Noto Sans Devanagari', 'Noto Sans', sans-serif";
          node.querySelectorAll('*').forEach((child) => {
            (child as HTMLElement).style.fontFamily =
              "'Noto Sans Devanagari', 'Noto Sans', sans-serif";
          });
        },
      },
    });

    return doc.output('blob');
  } finally {
    host.remove();
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
