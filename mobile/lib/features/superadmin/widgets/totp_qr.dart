import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw show Barcode, BarcodeBar;

import '../../../core/ui/ui.dart';
import '../logic/totp.dart';

/// QR code of the `otpauth://` URI (web shows `api.qrserver.com` image of the same URI).
/// Rendered on-device with the barcode engine bundled in the `pdf` package; falls back
/// to the web's QR image service if local encoding fails.
class TotpQrCode extends StatelessWidget {
  const TotpQrCode({super.key, required this.data, this.size = 196});

  final String data;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    List<pw.BarcodeBar>? bars;
    try {
      bars = pw.Barcode.qrCode()
          .make(data, width: 1000, height: 1000)
          .whereType<pw.BarcodeBar>()
          .where((b) => b.black)
          .toList();
    } catch (_) {
      bars = null;
    }
    // QR codes must stay dark-on-white to scan, in light and dark theme (web `bg-white`).
    const qrBackground = Colors.white;
    const qrForeground = Colors.black;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: qrBackground,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        border: Border.all(color: t.border),
      ),
      child: bars == null
          ? CachedNetworkImage(
              imageUrl: totpQrImageUrl(data, size: (size * 2).round()),
              fit: BoxFit.contain,
              errorWidget: (_, __, ___) => const Icon(Icons.qr_code_2, color: qrForeground, size: 64),
            )
          : CustomPaint(painter: _QrPainter(bars, qrForeground), size: Size.square(size - 24)),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.bars, this.color);

  final List<pw.BarcodeBar> bars;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 1000;
    final paint = Paint()
      ..color = color
      ..isAntiAlias = false;
    for (final b in bars) {
      // Barcode elements use a top-left origin like the Flutter canvas (the pdf
      // package flips them for PDF space); +0.5 avoids hairline gaps between modules.
      canvas.drawRect(
        Rect.fromLTWH(b.left * scale, b.top * scale, b.width * scale + 0.5, b.height * scale + 0.5),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) => old.bars != bars || old.color != color;
}
