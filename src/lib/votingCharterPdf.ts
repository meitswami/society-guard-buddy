import { jsPDF } from 'jspdf';
import { fmtDateTimeFull } from '@/lib/dateFormat';
import {
  ELECTION_PROGRAM_STEPS,
  VOTING_CHARTER_SECTIONS,
  VOTING_CHARTER_TITLE_KEY,
} from '@/lib/votingCharter';

type Translate = (key: string) => string;

export function buildVotingCharterPdfBlob(opts: {
  societyName?: string;
  t: Translate;
}): Blob {
  const doc = new jsPDF({ unit: 'mm', format: 'a4' });
  const margin = 14;
  const pageW = doc.internal.pageSize.getWidth();
  const pageH = doc.internal.pageSize.getHeight();
  const maxW = pageW - 2 * margin;
  let y = margin;

  const ensureSpace = (need: number) => {
    if (y + need > pageH - margin) {
      doc.addPage();
      y = margin;
    }
  };

  const writeLines = (text: string, fontSize: number, gap = 4) => {
    doc.setFontSize(fontSize);
    const lines = doc.splitTextToSize(text, maxW) as string[];
    for (const line of lines) {
      ensureSpace(gap + 1);
      doc.text(line, margin, y);
      y += gap;
    }
  };

  doc.setFont('helvetica', 'bold');
  writeLines(opts.societyName || 'Society', 14, 6);
  writeLines(opts.t(VOTING_CHARTER_TITLE_KEY), 12, 5);
  doc.setFont('helvetica', 'normal');
  doc.setTextColor(80, 80, 80);
  writeLines(`Generated: ${fmtDateTimeFull(new Date().toISOString())}`, 8, 4);
  doc.setTextColor(0, 0, 0);
  y += 2;

  doc.setFont('helvetica', 'bold');
  writeLines(opts.t('votingCharter.program.heading'), 11, 5);
  doc.setFont('helvetica', 'normal');
  writeLines(opts.t('votingCharter.program.intro'), 9, 4);
  y += 2;

  ELECTION_PROGRAM_STEPS.forEach((step, i) => {
    doc.setFont('helvetica', 'bold');
    writeLines(`${i + 1}. ${opts.t(step.stepKey)}`, 10, 4.5);
    doc.setFont('helvetica', 'normal');
    writeLines(opts.t(step.detailKey), 9, 4);
    y += 1.5;
  });

  y += 2;
  doc.setFont('helvetica', 'bold');
  writeLines(opts.t('votingCharter.rulesHeading'), 11, 5);
  doc.setFont('helvetica', 'normal');

  for (const sec of VOTING_CHARTER_SECTIONS) {
    y += 1;
    doc.setFont('helvetica', 'bold');
    writeLines(opts.t(sec.headingKey), 10, 4.5);
    doc.setFont('helvetica', 'normal');
    for (const key of sec.pointKeys) {
      writeLines(`• ${opts.t(key)}`, 9, 4);
    }
  }

  return doc.output('blob');
}

export function votingCharterPdfFilename(societyName?: string): string {
  const slug = (societyName || 'society')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
    .slice(0, 40);
  return `voting-charter-${slug || 'society'}-${new Date().toISOString().slice(0, 10)}.pdf`;
}
