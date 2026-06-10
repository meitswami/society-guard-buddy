import 'package:flutter/material.dart';

import '../../../core/theme/kutumbika_brand_theme.dart';

/// Soft peach circles behind content — matches the resident home mockup.
class BrandedBackground extends StatelessWidget {
  const BrandedBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brand = KutumbikaBrandTheme.of(context);

    return Stack(
      children: [
        Positioned(
          top: -80,
          right: -60,
          child: _Orb(color: brand.primary.withValues(alpha: 0.08), size: 220),
        ),
        Positioned(
          top: 120,
          left: -100,
          child: _Orb(color: brand.primary.withValues(alpha: 0.06), size: 260),
        ),
        Positioned(
          bottom: 180,
          right: -40,
          child: _Orb(color: brand.primary.withValues(alpha: 0.05), size: 180),
        ),
        child,
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
