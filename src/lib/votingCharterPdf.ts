import { jsPDF } from 'jspdf';
import { fmtDateTimeFull } from '@/lib/dateFormat';
import translations, { type Lang } from '@/i18n/translations';
import {
  ELECTION_PROGRAM_STEPS,
  VOTING_CHARTER_SECTIONS,
  VOTING_CHARTER_TITLE_KEY,
} from '@/lib/votingCharter';

type Translate = (key: string) => string;

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function tFor(lang: Lang, key: string): string {
  return translations[key]?.[lang] || translations[key]?.en || key;
}

/** Ensure Devanagari + Latin Noto fonts are available for canvas capture. */
async function ensureCharterFonts(): Promise<void> {
  const id = 'kutumbika-charter-fonts';
  if (!document.getElementById(id)) {
    const link = document.createElement('link');
    link.id = id;
    link.rel = 'stylesheet';
    link.href =
      'https://fonts.googleapis.com/css2?family=Noto+Sans+Devanagari:wght@400;600;700&family=Noto+Sans:wght@400;600;700&display=swap';
    document.head.appendChild(link);
  }

  // Local TTF fallback (variable fonts in /public/fonts)
  const styleId = 'kutumbika-charter-font-face';
  if (!document.getElementById(styleId)) {
    const style = document.createElement('style');
    style.id = styleId;
    style.textContent = `
      @font-face {
        font-family: 'NotoSansDevanagariLocal';
        src: url('/fonts/NotoSansDevanagari-Regular.ttf') format('truetype');
        font-weight: 100 900;
        font-style: normal;
        font-display: swap;
      }
      @font-face {
        font-family: 'NotoSansLocal';
        src: url('/fonts/NotoSans-Regular.ttf') format('truetype');
        font-weight: 100 900;
        font-style: normal;
        font-display: swap;
      }
    `;
    document.head.appendChild(style);
  }

  try {
    await Promise.all([
      document.fonts.load("400 16px 'Noto Sans Devanagari'"),
      document.fonts.load("700 16px 'Noto Sans Devanagari'"),
      document.fonts.load("400 16px 'Noto Sans'"),
      document.fonts.load("700 16px 'Noto Sans'"),
      document.fonts.load("400 16px 'NotoSansDevanagariLocal'"),
      document.fonts.load("400 16px 'NotoSansLocal'"),
    ]);
  } catch {
    /* continue — browser may still have fallbacks */
  }
  await document.fonts.ready;
  // Brief settle so webfont paint completes before html2canvas
  await new Promise((r) => setTimeout(r, 120));
}

function buildCharterHtml(opts: {
  societyName: string;
  lang: Lang;
  t: Translate;
  generatedAt: string;
}): string {
  const { societyName, lang, t, generatedAt } = opts;
  const isHi = lang === 'hi';
  const langLabel = isHi ? 'हिंदी' : 'English';
  const dir = 'ltr';

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
<div class="charter-root" lang="${lang}" dir="${dir}">
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
  font-family: 'Noto Sans Devanagari', 'NotoSansDevanagariLocal', 'Noto Sans', 'NotoSansLocal', 'Segoe UI', sans-serif;
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
  counter-reset: none;
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
 * Build a formatted Voting Charter PDF in the active UI language.
 * Uses browser HTML rendering (with embedded Noto Devanagari) so Hindi
 * conjuncts display correctly — plain jsPDF Helvetica cannot.
 */
export async function buildVotingCharterPdfBlob(opts: {
  societyName?: string;
  lang?: Lang;
  t?: Translate;
}): Promise<Blob> {
  const lang: Lang = opts.lang === 'hi' ? 'hi' : 'en';
  const t: Translate = opts.t ?? ((key) => tFor(lang, key));

  await ensureCharterFonts();

  const host = document.createElement('div');
  host.setAttribute('data-voting-charter-pdf', '1');
  host.style.cssText =
    'position:fixed;left:-10000px;top:0;width:720px;background:#fff;z-index:-1;pointer-events:none;';
  const styleEl = document.createElement('style');
  styleEl.textContent = CHARTER_CSS;
  host.appendChild(styleEl);

  const wrap = document.createElement('div');
  wrap.innerHTML = buildCharterHtml({
    societyName: opts.societyName || '',
    lang,
    t,
    generatedAt: fmtDateTimeFull(new Date().toISOString()) || new Date().toLocaleString(),
  });
  host.appendChild(wrap);
  document.body.appendChild(host);

  const root = host.querySelector('.charter-root') as HTMLElement;

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
      },
    });

    return doc.output('blob');
  } finally {
    host.remove();
  }
}

export function votingCharterShareMessage(lang: Lang = 'en'): string {
  return tFor(lang, 'votingCharter.shareMessage');
}

export function votingCharterPdfFilename(societyName?: string, lang: Lang = 'en'): string {
  const slug = (societyName || 'society')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
    .slice(0, 40);
  return `voting-charter-${lang}-${slug || 'society'}-${new Date().toISOString().slice(0, 10)}.pdf`;
}
