import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../device/kiosk_camera.dart';
import 'kiosk_palette.dart';

/// Round live camera preview (`<video className="rounded-full object-cover">`).
/// The plugins already mirror the front camera preview like the web `-scale-x-100`.
class KioskCameraBubble extends StatelessWidget {
  const KioskCameraBubble({
    super.key,
    required this.camera,
    required this.size,
    required this.borderColor,
    this.borderWidth = 4,
    this.background,
    this.overlay,
    this.shadow = false,
  });

  final KioskCamera camera;
  final double size;
  final Color borderColor;
  final double borderWidth;
  final Color? background;
  final Widget? overlay;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: background ?? KioskPalette.black,
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: shadow ? [BoxShadow(color: KioskPalette.a(KioskPalette.black, 0.4), blurRadius: 40, offset: const Offset(0, 20))] : null,
      ),
      child: ClipOval(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ListenableBuilder(
              listenable: camera,
              builder: (context, _) {
                final c = camera.controller;
                if (c == null || !c.value.isInitialized) return const SizedBox.expand();
                final portrait = MediaQuery.orientationOf(context) == Orientation.portrait;
                final ar = c.value.aspectRatio;
                return FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: portrait ? 100 : 100 * ar,
                    height: portrait ? 100 * ar : 100,
                    child: CameraPreview(c),
                  ),
                );
              },
            ),
            if (overlay != null) overlay!,
          ],
        ),
      ),
    );
  }
}
