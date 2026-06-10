import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/kutumbika_brand_theme.dart';

class BrandingLogo extends StatelessWidget {
  const BrandingLogo({
    super.key,
    this.size = 44,
    this.borderRadius = 12,
    this.imageUrl,
  });

  final double size;
  final double borderRadius;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final brand = KutumbikaBrandTheme.of(context);
    final url = imageUrl ?? brand.logoUrl;
    final primary = brand.primary;
    final primaryLight = brand.primaryLight;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: primaryLight,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: url != null && url.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.contain,
              placeholder: (_, __) => _FallbackIcon(primary: primary),
              errorWidget: (_, __, ___) => _FallbackIcon(primary: primary),
            )
          : _FallbackIcon(primary: primary),
    );
  }
}

class _FallbackIcon extends StatelessWidget {
  const _FallbackIcon({required this.primary});

  final Color primary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(Icons.home_rounded, color: primary, size: 26),
    );
  }
}
