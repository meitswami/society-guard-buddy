import { jsPDF } from 'jspdf';

export type PdfMember = {
  flat_id: string;
  name: string;
  relation?: string | null;
  phone?: string | null;
  age?: number | null;
  gender?: string | null;
  is_primary?: boolean | null;
  spouse_name?: string | null;
  police_verification?: string | null;
  date_joining?: string | null;
  date_leave?: string | null;
  id_photo_front?: string | null;
  id_photo_back?: string | null;
};

export type PdfFlat = {
  id: string;
  flat_number: string;
  owner_name?: string | null;
  floor?: string | null;
  wing?: string | null;
};

function imgFormat(dataUrl: string): 'PNG' | 'JPEG' {
  if (dataUrl.includes('image/png')) return 'PNG';
  return 'JPEG';
}

function addImageBlock(doc: jsPDF, label: string, dataUrl: string, x: number, y: number, w: number, h: number): number {
  doc.setFontSize(7);
  doc.text(label, x, y);
  let next = y + 3;
  try {
    doc.addImage(dataUrl, imgFormat(dataUrl), x, next, w, h);
    next += h + 4;
  } catch {
    doc.setFontSize(8);
    doc.setTextColor(180, 0, 0);
    doc.text('(could not embed image)', x, next + 4);
    doc.setTextColor(0, 0, 0);
    next += 10;
  }
  return next;
}

function newPageIfNeeded(doc: jsPDF, y: number, need: number, margin: number): number {
  const maxY = doc.internal.pageSize.getHeight() - margin;
  if (y + need > maxY) {
    doc.addPage();
    return margin;
  }
  return y;
}

/** Multi-page PDF: one section per flat, member details + ID thumbnails. */
export function exportResidentsDirectoryPdf(societyName: string, flats: PdfFlat[], members: PdfMember[]): void {
  const doc = new jsPDF({ unit: 'mm', format: 'a4' });
  const pageW = doc.internal.pageSize.getWidth();
  const margin = 14;
  let y = margin;

  doc.setFontSize(16);
  doc.text(societyName || 'Society', margin, y);
  y += 8;
  doc.setFontSize(9);
  doc.setTextColor(100, 100, 100);
  doc.text(`Resident directory & ID record — ${new Date().toLocaleString()}`, margin, y);
  doc.setTextColor(0, 0, 0);
  y += 10;

  const flatMembers = (flatId: string) => members.filter((m) => m.flat_id === flatId);
  const sortedFlats = [...flats].sort((a, b) => a.flat_number.localeCompare(b.flat_number, undefined, { numeric: true }));

  for (const flat of sortedFlats) {
    const ms = flatMembers(flat.id);
    y = newPageIfNeeded(doc, y, 24, margin);

    doc.setFillColor(245, 245, 245);
    doc.rect(margin - 2, y - 5, pageW - 2 * margin + 4, 7, 'F');
    doc.setFontSize(12);
    doc.text(`Flat ${flat.flat_number}`, margin, y);
    y += 6;
    doc.setFontSize(8);
    const meta = [flat.owner_name && `Owner: ${flat.owner_name}`, flat.floor, flat.wing && `Wing ${flat.wing}`]
      .filter(Boolean)
      .join(' · ');
    if (meta) {
      doc.setTextColor(80, 80, 80);
      doc.text(meta, margin, y);
      doc.setTextColor(0, 0, 0);
      y += 5;
    } else y += 2;

    if (ms.length === 0) {
      doc.setFontSize(9);
      doc.text('No members listed.', margin, y);
      y += 8;
      continue;
    }

    for (const m of ms) {
      y = newPageIfNeeded(doc, y, 55, margin);
      doc.setFontSize(10);
      doc.text(`${m.name}${m.is_primary ? ' ★ primary' : ''}`, margin, y);
      y += 5;
      doc.setFontSize(8);
      const lines = [
        `Relation: ${m.relation || '—'}`,
        m.phone ? `Phone: ${m.phone}` : null,
        m.age != null ? `Age: ${m.age}` : null,
        m.gender ? `Gender: ${m.gender}` : null,
        m.spouse_name ? `Spouse: ${m.spouse_name}` : null,
        m.police_verification ? `Police verification: ${m.police_verification}` : null,
        m.date_joining ? `Joined: ${m.date_joining}` : null,
        m.date_leave ? `Left: ${m.date_leave}` : null,
      ].filter(Boolean) as string[];
      lines.forEach((line) => {
        doc.text(line, margin + 2, y);
        y += 3.5;
      });

      const imgW = 58;
      const imgH = 34;
      if (m.id_photo_front?.startsWith('data:image')) {
        y = newPageIfNeeded(doc, y, imgH + 8, margin);
        y = addImageBlock(doc, 'Photo ID — front', m.id_photo_front, margin + 2, y, imgW, imgH);
      }
      if (m.id_photo_back?.startsWith('data:image')) {
        y = newPageIfNeeded(doc, y, imgH + 8, margin);
        y = addImageBlock(doc, 'Photo ID — back', m.id_photo_back, margin + 2, y, imgW, imgH);
      }
      y += 4;
    }
    y += 4;
  }

  doc.save(`${(societyName || 'society').replace(/\s+/g, '_')}_residents_${new Date().toISOString().slice(0, 10)}.pdf`);
}
