import 'dart:async';

import 'package:flutter/material.dart';

import '../device/kiosk_camera.dart';
import '../logic/kiosk_copy.dart';
import 'kiosk_camera_bubble.dart';
import 'kiosk_effects.dart';
import 'kiosk_palette.dart';

enum KioskStatusTone { ok, warn, error }

/// One-line camera / face-detection status for the guard, with an optional retry.
class KioskStatus {
  const KioskStatus(this.text, this.tone, {this.onRetry, this.retryLabel});

  final String text;
  final KioskStatusTone tone;
  final VoidCallback? onRetry;
  final String? retryLabel;
}

const List<KioskCopyKey> _tips = [KioskCopyKey.idleTip1, KioskCopyKey.idleTip2, KioskCopyKey.idleTip3];

/// Idle attract screen; a small live camera bubble keeps face detection running —
/// port of web `KioskScreensaver.tsx`.
class KioskScreensaver extends StatefulWidget {
  const KioskScreensaver({
    super.key,
    required this.lang,
    required this.societyName,
    required this.timeLabel,
    required this.dateLabel,
    required this.camera,
    required this.status,
    required this.onTap,
  });

  final KioskLang lang;
  final String societyName;
  final String timeLabel;
  final String dateLabel;
  final KioskCamera camera;
  final KioskStatus status;
  final VoidCallback onTap;

  @override
  State<KioskScreensaver> createState() => _KioskScreensaverState();
}

class _KioskScreensaverState extends State<KioskScreensaver> {
  int _tip = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 4500), (_) => setState(() => _tip = (_tip + 1) % _tips.length));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    final status = widget.status;
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 640;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final dot = switch (status.tone) {
      KioskStatusTone.ok => KioskPalette.emerald400,
      KioskStatusTone.warn => KioskPalette.amber400,
      KioskStatusTone.error => KioskPalette.red400,
    };
    final dotWidget = Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: dot));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: ColoredBox(
        color: KioskPalette.background,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              top: -128,
              left: -96,
              child: KioskBlob(size: 448, color: KioskPalette.a(KioskPalette.orange500, 0.30), float: true),
            ),
            Positioned(
              bottom: -160,
              right: -96,
              child: KioskBlob(
                size: 512,
                color: KioskPalette.a(KioskPalette.emerald500, 0.20),
                float: true,
                delay: const Duration(seconds: 6),
              ),
            ),
            Positioned(
              top: size.height / 3,
              left: size.width / 2,
              child: KioskBlob(
                size: 352,
                color: KioskPalette.a(KioskPalette.indigo500, 0.20),
                float: true,
                delay: const Duration(seconds: 12),
              ),
            ),
            Positioned.fill(
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 72, 24, 120),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.timeLabel,
                          style: TextStyle(
                            fontSize: wide ? 72 : 60,
                            fontWeight: FontWeight.w300,
                            letterSpacing: -1.5,
                            height: 1,
                            color: KioskPalette.white,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(widget.dateLabel, style: TextStyle(fontSize: 14, color: KioskPalette.whiteA(0.6))),
                        const SizedBox(height: 16),
                        Text(
                          widget.societyName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: KioskPalette.orange300),
                        ),
                        const SizedBox(height: 56),
                        SizedBox(
                          width: 112,
                          height: 112,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              KioskPing(size: 112, color: KioskPalette.a(KioskPalette.orange400, 0.25)),
                              Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: KioskPalette.whiteA(0.10),
                                  border: Border.all(color: KioskPalette.whiteA(0.20)),
                                ),
                                child: const Icon(Icons.face_unlock_outlined, size: 48, color: KioskPalette.orange200),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          kioskText(KioskCopyKey.idleTitle, lang),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: wide ? 36 : 30, fontWeight: FontWeight.w700, color: KioskPalette.white),
                        ),
                        const SizedBox(height: 16),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 448),
                          child: Text(
                            kioskText(KioskCopyKey.idleSubtitle, lang),
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: wide ? 24 : 20, color: KioskPalette.whiteA(0.9)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          kioskText(KioskCopyKey.idleTap, lang),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: KioskPalette.whiteA(0.5)),
                        ),
                        const SizedBox(height: 40),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 384),
                          child: KioskFadeIn(
                            childKey: '$_tip-${lang.name}',
                            child: Text(
                              kioskText(_tips[_tip], lang),
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16, color: KioskPalette.whiteA(0.7)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Bottom-left: keeps the bottom-right corner free (as on the web).
            Positioned(
              left: 16,
              right: 96,
              bottom: bottomInset > 20 ? bottomInset : 20,
              child: Row(
                children: [
                  KioskCameraBubble(
                    camera: widget.camera,
                    size: 80,
                    borderWidth: 2,
                    borderColor: KioskPalette.whiteA(0.30),
                    background: KioskPalette.a(KioskPalette.black, 0.4),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: status.tone == KioskStatusTone.ok ? KioskPulse(child: dotWidget) : dotWidget,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                status.text,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.35,
                                  color: status.tone == KioskStatusTone.error ? KioskPalette.red200 : KioskPalette.whiteA(0.7),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (status.onRetry != null) ...[
                          const SizedBox(height: 6),
                          Material(
                            color: KioskPalette.whiteA(0.15),
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: status.onRetry,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                child: Text(
                                  status.retryLabel ?? '',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: KioskPalette.white),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
