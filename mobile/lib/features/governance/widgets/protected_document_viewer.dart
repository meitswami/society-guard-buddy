import 'dart:async';

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../core/ui/ui.dart';
import '../logic/document_logic.dart';

/// Port of web `ProtectedDocumentViewer.tsx`: view-only page with a tiled
/// watermark, optional heavy blur (member default until the office enables
/// viewing), countdown of the reveal window and an "obscured" overlay while the
/// app is in the background (web `visibilitychange`). PDFs are rasterised in-app
/// (no download / print / share actions are offered).
class ProtectedDocumentViewer extends StatefulWidget {
  const ProtectedDocumentViewer({
    super.key,
    required this.title,
    required this.loadBytes,
    required this.fileName,
    this.mimeType,
    required this.watermark,
    this.revealUntil,
    this.protectedForMember = false,
  });

  final String title;
  final Future<Uint8List> Function() loadBytes;
  final String fileName;
  final String? mimeType;
  final String watermark;

  /// Live `member_reveal_until` (updated by the realtime feed of the list page).
  final ValueListenable<String?>? revealUntil;

  /// Resident view: content blurred unless a reveal window is active.
  final bool protectedForMember;

  static Future<void> open(
    BuildContext context, {
    required String title,
    required Future<Uint8List> Function() loadBytes,
    required String fileName,
    String? mimeType,
    required String watermark,
    ValueListenable<String?>? revealUntil,
    bool protectedForMember = false,
  }) {
    return Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => ProtectedDocumentViewer(
        title: title,
        loadBytes: loadBytes,
        fileName: fileName,
        mimeType: mimeType,
        watermark: watermark,
        revealUntil: revealUntil,
        protectedForMember: protectedForMember,
      ),
    ));
  }

  @override
  State<ProtectedDocumentViewer> createState() =>
      _ProtectedDocumentViewerState();
}

class _ProtectedDocumentViewerState extends State<ProtectedDocumentViewer>
    with WidgetsBindingObserver {
  Timer? _clock;
  DateTime _now = DateTime.now();
  bool _obscured = false;
  bool _loading = true;
  String? _error;
  Uint8List? _imageBytes;
  final List<Uint8List> _pdfPages = [];

  bool get _isPdf =>
      viewerIsPdf(mimeType: widget.mimeType, url: widget.fileName);
  bool get _isImage =>
      viewerIsImage(mimeType: widget.mimeType, url: widget.fileName);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    widget.revealUntil?.addListener(_onReveal);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.revealUntil?.removeListener(_onReveal);
    _clock?.cancel();
    super.dispose();
  }

  void _onReveal() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final hidden = state != AppLifecycleState.resumed;
    if (hidden != _obscured && mounted) setState(() => _obscured = hidden);
  }

  Future<void> _load() async {
    try {
      final bytes = await widget.loadBytes();
      if (_isPdf) {
        await for (final page in Printing.raster(bytes, dpi: 144)) {
          final png = await page.toPng();
          if (!mounted) return;
          setState(() => _pdfPages.add(png));
        }
      } else if (_isImage) {
        _imageBytes = bytes;
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final until = widget.revealUntil?.value;
    final revealActive = isRevealActive(until, _now);
    final secondsLeft = revealSecondsLeft(until, _now);
    final blurred = widget.protectedForMember && !revealActive;

    final status = blurred
        ? context.tr(
            'Preview hidden — waiting for society office to enable viewing',
            'पूर्वावलोकन छिपा है — सोसायटी कार्यालय द्वारा देखने की अनुमति की प्रतीक्षा')
        : (widget.protectedForMember && secondsLeft > 0)
            ? context.tr('Viewing enabled — ${secondsLeft}s remaining',
                'देखना सक्षम — $secondsLeft सेकंड शेष')
            : context.tr(
                'View only — copying, saving, and printing are disabled',
                'केवल देखें — कॉपी, सहेजना और प्रिंट अक्षम हैं');

    Widget content;
    if (_loading && _pdfPages.isEmpty) {
      content = const SizedBox(height: 400, child: LoadingView());
    } else if (_error != null) {
      content = ErrorView(
          message:
              context.tr('Could not open document', 'दस्तावेज़ नहीं खुल सका'));
    } else if (_isPdf) {
      content = Column(
        children: [
          for (final p in _pdfPages)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child:
                  Image.memory(p, fit: BoxFit.fitWidth, gaplessPlayback: true),
            ),
          if (_loading)
            const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator()),
        ],
      );
    } else if (_isImage && _imageBytes != null) {
      content = Center(child: Image.memory(_imageBytes!, fit: BoxFit.contain));
    } else {
      content = Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          context.tr(
              'This file type cannot be previewed in the app. Contact your society office for access.',
              'इस फ़ाइल प्रकार का ऐप में पूर्वावलोकन नहीं हो सकता। पहुँच के लिए सोसायटी कार्यालय से संपर्क करें।'),
          textAlign: TextAlign.center,
          style: AppText.body(context).copyWith(color: t.mutedForeground),
        ),
      );
    }

    final viewer = InteractiveViewer(
      minScale: 1,
      maxScale: 5,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: blurred
            ? ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: content)
            : content,
      ),
    );

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.card,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.sectionTitle(context)),
            Row(
              children: [
                Icon(Icons.shield_outlined, size: 11, color: t.mutedForeground),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(status,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.tiny(context)),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
              child: ColoredBox(color: AppTokens.tint(t.muted, 0.3))),
          Positioned.fill(child: viewer),
          Positioned.fill(
              child: IgnorePointer(child: _Watermark(text: widget.watermark))),
          if (blurred)
            Positioned.fill(
              child: ColoredBox(
                color: AppTokens.tint(t.background, 0.8),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline,
                            size: 32, color: t.mutedForeground),
                        const SizedBox(height: 8),
                        Text(
                            context.tr('Document preview hidden',
                                'दस्तावेज़ पूर्वावलोकन छिपा है'),
                            style: AppText.bodyMedium(context)),
                        const SizedBox(height: 4),
                        Text(
                          context.tr(
                              'Your society office will enable viewing when needed. The image stays blurred until then.',
                              'आवश्यकता होने पर सोसायटी कार्यालय देखने की अनुमति देगा। तब तक चित्र धुंधला रहेगा।'),
                          textAlign: TextAlign.center,
                          style: AppText.caption(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_obscured)
            Positioned.fill(
              child: ColoredBox(
                color: t.background,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      context.tr(
                          'Content hidden — return to this screen to continue viewing.',
                          'सामग्री छिपी है — देखना जारी रखने के लिए इस स्क्रीन पर लौटें।'),
                      textAlign: TextAlign.center,
                      style: AppText.caption(context),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Watermark extends StatelessWidget {
  const _Watermark({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final color = AppTokens.tint(context.tokens.foreground, 0.10);
    return LayoutBuilder(
      builder: (context, c) => ClipRect(
        child: Stack(
          children: [
            for (var i = 0; i < 12; i++)
              Positioned(
                left: c.maxWidth * (((i % 4) * 28 - 8) / 100),
                top: c.maxHeight * (((i ~/ 4) * 32 + 8) / 100),
                child: Transform.rotate(
                  angle: -24 * 3.1415926 / 180,
                  child: Text(text,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: color)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
