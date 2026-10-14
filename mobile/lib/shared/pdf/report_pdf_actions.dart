import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../core/export/export_kit.dart';
import '../../core/ui/ui.dart';
import 'letterhead_report_engine.dart';
import 'report_export.dart';

/// UI pieces shared by every report screen — ports of `ReportPdfActions`,
/// `ExportFormatMenu`, `SharePdfWhatsAppButton` and the PDF preview tab.

/// Builds a PDF for the chosen mode with the resolved society letterhead.
typedef SocietyPdfBuilder = Future<Uint8List> Function(
    ReportPdfMode mode, SocietyLetterhead? letterhead);

String _pdfName(String filename) =>
    filename.toLowerCase().endsWith('.pdf') ? filename : '$filename.pdf';

/// In-app PDF viewer (web "PDF opens to view" / Preview Report).
class SocietyPdfPreviewPage extends StatelessWidget {
  const SocietyPdfPreviewPage(
      {super.key, required this.bytes, required this.filename, this.title});

  final Uint8List bytes;
  final String filename;
  final String? title;

  static Future<void> open(
          BuildContext context, Uint8List bytes, String filename,
          {String? title}) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => SocietyPdfPreviewPage(
            bytes: bytes, filename: filename, title: title),
      ));

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        title: Text(
            title ?? context.tr('Preview Report', 'प्रतिवेदन पूर्वावलोकन')),
        actions: [
          IconButton(
            tooltip: context.t('mobile.share'),
            icon: const Icon(Icons.ios_share),
            onPressed: () => ExportKit.sharePdf(bytes, _pdfName(filename)),
          ),
        ],
      ),
      body: PdfPreview(
        build: (_) async => bytes,
        pdfFileName: _pdfName(filename),
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        allowPrinting: true,
        allowSharing: true,
      ),
    );
  }
}

/// Output helpers (web `previewSocietyReportPdf` / `downloadSocietyReportPdf` / `sharePdfOnWhatsApp`).
abstract final class SocietyPdfOutput {
  static Future<void> preview(
          BuildContext context, Uint8List bytes, String filename,
          {String? title}) =>
      SocietyPdfPreviewPage.open(context, bytes, filename, title: title);

  /// Mobile "download" = share sheet (Save to Files / Drive / Downloads).
  static Future<void> download(Uint8List bytes, String filename) =>
      ExportKit.sharePdf(bytes, _pdfName(filename));

  /// Share sheet with the message pre-filled (pick WhatsApp).
  static Future<void> shareWhatsApp(Uint8List bytes, String filename,
          {String? message}) =>
      ExportKit.sharePdf(bytes, _pdfName(filename), text: message);
}

/// "Generate Report" → Preview / Official Society Letterhead PDF / Plain PDF.
class ReportPdfActionsButton extends StatefulWidget {
  const ReportPdfActionsButton({
    super.key,
    required this.societyId,
    required this.filename,
    required this.buildPdf,
    this.label,
    this.disabled = false,
  });

  final String? societyId;
  final String filename;
  final SocietyPdfBuilder buildPdf;
  final String? label;
  final bool disabled;

  @override
  State<ReportPdfActionsButton> createState() => _ReportPdfActionsButtonState();
}

class _ReportPdfActionsButtonState extends State<ReportPdfActionsButton> {
  bool _busy = false;
  ReportPdfMode _defaultMode = ReportPdfMode.letterhead;
  bool _hasLetterhead = false;

  @override
  void initState() {
    super.initState();
    _loadDefaults();
  }

  Future<void> _loadDefaults() async {
    try {
      final ctx = await resolveLetterheadReportContext(widget.societyId);
      if (!mounted || ctx == null) return;
      setState(() {
        _defaultMode = ctx.settings.defaultReportFormat;
        _hasLetterhead = ctx.letterhead?.hasOfficialAsset ?? false;
      });
    } catch (_) {}
  }

  Future<void> _run({required bool preview, ReportPdfMode? preferred}) async {
    final sid = widget.societyId;
    if (sid == null || sid.isEmpty) {
      AppFeedback.toast(
          context, context.tr('Select a society first', 'पहले सोसाइटी चुनें'),
          tone: BadgeTone.alert);
      return;
    }
    setState(() => _busy = true);
    try {
      final ctx = await resolveLetterheadReportContext(sid,
          preferredMode: preferred ?? _defaultMode);
      if (!mounted) return;
      if (ctx == null) {
        AppFeedback.toast(
            context, context.tr('Society not found', 'सोसाइटी नहीं मिली'),
            tone: BadgeTone.alert);
        return;
      }
      if (ctx.warning != null) {
        AppFeedback.toast(context, letterheadWarningText(context),
            tone: BadgeTone.warning);
      }
      final bytes = await widget.buildPdf(ctx.mode, ctx.letterhead);
      if (!mounted) return;
      if (preview) {
        await SocietyPdfOutput.preview(context, bytes, widget.filename);
      } else {
        await SocietyPdfOutput.download(bytes, widget.filename);
        if (mounted) {
          AppFeedback.toast(context, context.tr('PDF ready', 'PDF तैयार'),
              tone: BadgeTone.success);
        }
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.toast(
            context, '${context.tr('PDF failed', 'PDF विफल')}: $e',
            tone: BadgeTone.alert);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openMenu() async {
    final t = context.tokens;
    final dflt = context.tr(' (default)', ' (डिफ़ॉल्ट)');
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: Text(ctx.tr('Preview Report', 'प्रतिवेदन पूर्वावलोकन')),
              onTap: () => Navigator.pop(ctx, 'preview'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: Text(
                '${ctx.tr('Official Society Letterhead PDF', 'आधिकारिक सोसाइटी लेटरहेड PDF')}'
                '${_defaultMode == ReportPdfMode.letterhead ? dflt : ''}',
              ),
              onTap: () => Navigator.pop(ctx, 'letterhead'),
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: Text(
                  '${ctx.tr('Plain PDF', 'साधारण PDF')}${_defaultMode == ReportPdfMode.plain ? dflt : ''}'),
              onTap: () => Navigator.pop(ctx, 'plain'),
            ),
            if (!_hasLetterhead)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Text(letterheadWarningText(ctx),
                    style: TextStyle(fontSize: 12, color: t.warning)),
              ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    switch (choice) {
      case 'preview':
        await _run(preview: true, preferred: _defaultMode);
      case 'letterhead':
        await _run(preview: false, preferred: ReportPdfMode.letterhead);
      case 'plain':
        await _run(preview: false, preferred: ReportPdfMode.plain);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppButton.secondary(
      label: widget.label ?? context.tr('Generate Report', 'प्रतिवेदन बनाएं'),
      icon: Icons.description_outlined,
      loading: _busy,
      expand: false,
      dense: true,
      onPressed: widget.disabled || _busy ? null : _openMenu,
    );
  }
}

/// Bilingual copy of [kLetterheadNotConfiguredWarning].
String letterheadWarningText(BuildContext context) => context.tr(
    kLetterheadNotConfiguredWarning,
    'आधिकारिक सोसाइटी लेटरहेड कॉन्फ़िगर नहीं किया गया है।');

/// Web `ExportFormatMenu`.
class ExportFormatMenuButton extends StatelessWidget {
  const ExportFormatMenuButton({
    super.key,
    required this.onExport,
    this.formats = const [
      ExportFormat.pdf,
      ExportFormat.excel,
      ExportFormat.word,
      ExportFormat.csv
    ],
    this.label,
    this.disabled = false,
  });

  final void Function(ExportFormat format) onExport;
  final List<ExportFormat> formats;
  final String? label;
  final bool disabled;

  IconData _icon(ExportFormat f) => switch (f) {
        ExportFormat.pdf => Icons.description_outlined,
        ExportFormat.excel => Icons.table_chart_outlined,
        ExportFormat.word => Icons.article_outlined,
        ExportFormat.csv => Icons.download_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ExportFormat>(
      enabled: !disabled,
      onSelected: onExport,
      itemBuilder: (_) => [
        for (final f in formats)
          PopupMenuItem(
            value: f,
            child: Row(children: [
              Icon(_icon(f), size: 16),
              const SizedBox(width: 8),
              Text(f.label)
            ]),
          ),
      ],
      child: IgnorePointer(
        child: AppButton.secondary(
          label: label ?? context.tr('Export', 'निर्यात'),
          icon: Icons.download_outlined,
          expand: false,
          dense: true,
          onPressed: disabled ? null : () {},
        ),
      ),
    );
  }
}

/// Web `SharePdfWhatsAppButton` (WhatsApp-green tinted).
class SharePdfWhatsAppButton extends StatefulWidget {
  const SharePdfWhatsAppButton({
    super.key,
    required this.getBytes,
    required this.filename,
    this.message,
    this.label,
    this.disabled = false,
  });

  final Future<Uint8List> Function() getBytes;
  final String filename;
  final String? message;
  final String? label;
  final bool disabled;

  @override
  State<SharePdfWhatsAppButton> createState() => _SharePdfWhatsAppButtonState();
}

class _SharePdfWhatsAppButtonState extends State<SharePdfWhatsAppButton> {
  bool _busy = false;

  /// WhatsApp brand green (#25D366 / #128C7E) — brand colours, identical in both themes.
  static const _waGreen = Color(0xFF25D366);
  static const _waDark = Color(0xFF128C7E);

  Future<void> _share() async {
    if (_busy || widget.disabled) return;
    setState(() => _busy = true);
    try {
      final bytes = await widget.getBytes();
      await SocietyPdfOutput.shareWhatsApp(bytes, widget.filename,
          message: widget.message);
    } catch (_) {
      if (mounted) {
        AppFeedback.toast(
            context, context.tr('Could not share PDF', 'PDF साझा नहीं हो सका'),
            tone: BadgeTone.alert);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fg = context.tokens.isDark ? _waGreen : _waDark;
    return Opacity(
      opacity: widget.disabled ? 0.5 : 1,
      child: Material(
        color: AppTokens.tint(_waGreen, 0.10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          side: BorderSide(color: AppTokens.tint(_waGreen, 0.30)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          onTap: widget.disabled || _busy ? null : _share,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_busy)
                  SizedBox(
                      width: 14,
                      height: 14,
                      child:
                          CircularProgressIndicator(strokeWidth: 2, color: fg))
                else
                  Icon(Icons.chat_rounded, size: 14, color: fg),
                const SizedBox(width: 6),
                Text(
                  _busy
                      ? context.tr('Sharing…', 'साझा हो रहा है…')
                      : (widget.label ??
                          context.tr('Share PDF', 'PDF साझा करें')),
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
