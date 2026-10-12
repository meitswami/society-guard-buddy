import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/export/export_kit.dart';
import '../../../../core/format/formatters.dart';
import '../../../../utils/member_photo.dart';
import '../../../shared/directory/directory_models.dart';
import '../../../shared/directory/directory_search.dart';
import 'society_letterhead.dart';

/// Web `residentsDirectoryPdfFilename`.
String residentsDirectoryPdfFilename(String societyName, {DateTime? now}) {
  final base = (societyName.isEmpty ? 'society' : societyName)
      .replaceAll(RegExp(r'\s+'), '_');
  final date =
      (now ?? DateTime.now()).toUtc().toIso8601String().substring(0, 10);
  return '${base}_residents_$date.pdf';
}

/// Detail lines printed under each member (web `buildResidentsDirectoryPdfBlob`).
List<String> residentPdfMemberLines(PeopleMember m) => [
      'Relation: ${m.relation.isEmpty ? '—' : m.relation}',
      if (m.phone != null) 'Phone: ${m.phone}',
      if (m.age != null) 'Age: ${m.age}',
      if (m.gender != null) 'Gender: ${m.gender}',
      if (m.spouseName != null) 'Spouse: ${m.spouseName}',
      if (m.policeVerification != null)
        'Police verification: ${m.policeVerification}',
      if (m.dateJoining != null) 'Joined: ${Fmt.isoToDisplay(m.dateJoining)}',
      if (m.dateLeave != null) 'Left: ${Fmt.isoToDisplay(m.dateLeave)}',
    ];

/// Flat meta line (`Owner: … · floor · Wing X`).
String residentPdfFlatMeta(PeopleFlat f) => [
      if (f.ownerName != null) 'Owner: ${f.ownerName}',
      if (f.floor != null) f.floor!,
      if (f.wing != null) 'Wing ${f.wing}',
    ].join(' · ');

/// Multi-page PDF: one section per flat, member details + ID thumbnails (data-URL IDs only).
Future<Uint8List> buildResidentsDirectoryPdf({
  required List<PeopleFlat> flats,
  required List<PeopleMember> members,
  required LetterheadContext letterhead,
}) async {
  final theme = await ExportKit.pdfTheme();
  final doc = pw.Document(
      theme: theme, title: 'Resident directory', author: 'Kutumbika');
  const mm = PdfPageFormat.mm;
  final sorted = sortByFlatNumber(flats, (f) => f.flatNumber);
  final byFlat = <String, List<PeopleMember>>{};
  for (final m in members) {
    (byFlat[m.flatId] ??= []).add(m);
  }

  pw.Widget idImage(String label, String dataUrl) {
    final bytes = dataUrlBytes(dataUrl);
    return pw.Padding(
      padding:
          const pw.EdgeInsets.only(left: 2 * mm, top: 1 * mm, bottom: 2 * mm),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 7)),
          pw.SizedBox(height: 1 * mm),
          if (bytes == null)
            pw.Text('(could not embed image)',
                style:
                    const pw.TextStyle(fontSize: 8, color: PdfColor(0.7, 0, 0)))
          else
            pw.SizedBox(
                width: 58 * mm,
                height: 34 * mm,
                child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain)),
        ],
      ),
    );
  }

  final content = <pw.Widget>[
    pw.Text(
      'Resident directory & ID record — ${Fmt.dateTimeFull(DateTime.now())}',
      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
    ),
    pw.SizedBox(height: 4 * mm),
  ];

  for (final flat in sorted) {
    final ms = byFlat[flat.id] ?? const [];
    final meta = residentPdfFlatMeta(flat);
    content.add(pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(top: 2 * mm),
      padding:
          const pw.EdgeInsets.symmetric(horizontal: 2 * mm, vertical: 1 * mm),
      color: const PdfColor.fromInt(0xFFF5F5F5),
      child: pw.Text('Flat ${flat.flatNumber}',
          style: const pw.TextStyle(fontSize: 12)),
    ));
    if (meta.isNotEmpty) {
      content.add(pw.Padding(
        padding: const pw.EdgeInsets.only(top: 1 * mm, bottom: 1 * mm),
        child: pw.Text(meta,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
      ));
    }
    if (ms.isEmpty) {
      content.add(pw.Padding(
        padding: const pw.EdgeInsets.only(top: 1 * mm, bottom: 3 * mm),
        child: pw.Text('No members listed.',
            style: const pw.TextStyle(fontSize: 9)),
      ));
      continue;
    }
    for (final m in ms) {
      content.add(pw.Padding(
        padding: const pw.EdgeInsets.only(top: 2 * mm),
        child: pw.Text('${m.name}${m.isPrimary ? ' (primary)' : ''}',
            style: const pw.TextStyle(fontSize: 10)),
      ));
      for (final line in residentPdfMemberLines(m)) {
        content.add(pw.Padding(
          padding: const pw.EdgeInsets.only(left: 2 * mm),
          child: pw.Text(line, style: const pw.TextStyle(fontSize: 8)),
        ));
      }
      if (isDataImageUrl(m.idPhotoFront)) {
        content.add(idImage('Photo ID — front', m.idPhotoFront!));
      }
      if (isDataImageUrl(m.idPhotoBack)) {
        content.add(idImage('Photo ID — back', m.idPhotoBack!));
      }
    }
    content.add(pw.SizedBox(height: 2 * mm));
  }

  final header = letterheadHeader(letterhead);
  doc.addPage(pw.MultiPage(
    pageTheme: letterheadPageTheme(letterhead, theme: theme),
    header: header == null ? null : (_) => header,
    footer: (ctx) => letterheadFooter(letterhead, ctx),
    build: (_) => content,
  ));
  return doc.save();
}
