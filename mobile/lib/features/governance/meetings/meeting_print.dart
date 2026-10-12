import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/export/export_kit.dart';
import '../../../core/format/formatters.dart';
import '../logic/meeting_logic.dart';
import '../models/meeting_models.dart';

/// Printouts of web `MeetingManager` (`printMeetingsFlat`, `printMeetingsGrouped`,
/// `printCurrentMeetingDetail`) — rendered as Letter PDFs for the system print dialog.
abstract final class MeetingPrint {
  static const _margin = pw.EdgeInsets.all(54); // 0.75 in

  static pw.TextStyle get _h1 => pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold);
  static pw.TextStyle get _h2 => pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold);
  static const pw.TextStyle _muted = pw.TextStyle(fontSize: 11, color: PdfColors.grey700);
  static const pw.TextStyle _cell = pw.TextStyle(fontSize: 10);

  static pw.Widget _table(List<String> headers, List<List<String>> rows, {String? empty}) {
    final data = rows.isEmpty && empty != null
        ? [
            [empty, ...List.filled(headers.length - 1, '')],
          ]
        : rows;
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
      cellStyle: _cell,
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.6),
      cellAlignment: pw.Alignment.topLeft,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    );
  }

  static List<String> _row(MeetingRow m, {bool withType = true}) => [
        if (withType) meetingKindLabel(m.meetingKind.value),
        m.title,
        Fmt.dateTimeFull(m.meetingAt),
        m.location ?? '—',
        m.status,
        m.published ? 'Yes' : 'No',
      ];

  /// "Print list (current view)".
  static Future<void> printFlat(List<MeetingRow> rows, String heading) async {
    final doc = await ExportKit.newPdf(title: heading);
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: _margin,
      build: (_) => [
        pw.Text(heading, style: _h1),
        pw.SizedBox(height: 4),
        pw.Text('${rows.length} record(s)', style: _muted),
        pw.SizedBox(height: 10),
        _table(
          const ['Type', 'Title', 'Date & time', 'Venue', 'Status', 'Published'],
          rows.map(_row).toList(),
          empty: 'No meetings in this list.',
        ),
      ],
    ));
    await ExportKit.printPdf(await doc.save(), name: heading);
  }

  /// "Print all types (grouped)" — one section per class. Returns false when nothing to print.
  static Future<bool> printGrouped(List<MeetingRow> meetings) async {
    final groups = <MeetingKind, List<MeetingRow>>{};
    for (final k in MeetingKind.values) {
      final rows = meetings.where((m) => m.meetingKind == k).toList()
        ..sort((a, b) => b.meetingAt.compareTo(a.meetingAt));
      if (rows.isNotEmpty) groups[k] = rows;
    }
    if (groups.isEmpty) return false;
    const heading = 'Meetings by type';
    final doc = await ExportKit.newPdf(title: heading);
    var first = true;
    for (final entry in groups.entries) {
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: _margin,
        build: (_) => [
          if (first) ...[
            pw.Text(heading, style: _h1),
            pw.Text('All meetings — one section per class (${meetings.length} total)', style: _muted),
            pw.SizedBox(height: 12),
          ],
          pw.Text(entry.key.labelEn, style: _h2),
          pw.SizedBox(height: 8),
          _table(
            const ['Title', 'Date & time', 'Venue', 'Status', 'Published'],
            entry.value.map((m) => _row(m, withType: false)).toList(),
          ),
        ],
      ));
      first = false;
    }
    await ExportKit.printPdf(await doc.save(), name: heading);
    return true;
  }

  /// "Print open meeting" — notice, notes, decisions and attendance.
  static Future<void> printDetail({
    required String title,
    required String meetingAt,
    required String location,
    required MeetingKind kind,
    required String status,
    required bool published,
    required String executives,
    required String discussion,
    required String minutes,
    required List<String> decisions,
    required List<AttendeeRow> attendees,
  }) async {
    final doc = await ExportKit.newPdf(title: 'Meeting: $title');
    pw.Widget label(String k, String v) => pw.RichText(
          text: pw.TextSpan(children: [
            pw.TextSpan(text: '$k: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
            pw.TextSpan(text: v, style: const pw.TextStyle(fontSize: 11)),
          ]),
        );
    pw.Widget section(String h, String body) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(height: 14),
            pw.Text(h, style: _h2),
            pw.SizedBox(height: 6),
            pw.Text(body.trim().isEmpty ? '—' : body.trim(), style: const pw.TextStyle(fontSize: 10.5)),
          ],
        );
    final decs = decisions.where((d) => d.trim().isNotEmpty).toList();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: _margin,
      build: (_) => [
        pw.Text(title, style: _h1),
        pw.SizedBox(height: 6),
        label('Type', kind.labelEn),
        label('When', Fmt.dateTimeFull(meetingAt)),
        label('Venue', location.trim().isEmpty ? '—' : location.trim()),
        label('Status', '$status · Published: ${published ? 'Yes' : 'No'}'),
        section('Officers / executives present', executives),
        section('Discussion', discussion),
        section('Minutes summary', minutes),
        pw.SizedBox(height: 14),
        pw.Text('Decisions / resolutions', style: _h2),
        pw.SizedBox(height: 6),
        if (decs.isEmpty) pw.Text('1. —', style: _cell),
        for (final (i, d) in decs.indexed) pw.Text('${i + 1}. $d', style: const pw.TextStyle(fontSize: 10.5)),
        pw.SizedBox(height: 14),
        pw.Text('Attendance', style: _h2),
        pw.SizedBox(height: 6),
        _table(
          const ['Name', 'Flat', 'Role', 'Presence'],
          [
            for (final a in attendees) [a.displayName, a.flatNumber ?? '—', a.attendeeRole, a.isPresent ? 'Present' : 'Absent'],
          ],
          empty: '—',
        ),
      ],
    ));
    await ExportKit.printPdf(await doc.save(), name: 'Meeting: $title');
  }
}
