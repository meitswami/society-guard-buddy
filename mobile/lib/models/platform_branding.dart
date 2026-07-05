import 'package:flutter/material.dart';

import '../core/theme/color_utils.dart';
import '../core/theme/kutumbika_colors.dart';

class PlatformBranding {
  const PlatformBranding({
    this.appName = 'Kutumbika',
    this.tagline = '— parivaar jaisi society —',
    this.logoUrl,
    this.primaryColor = KutumbikaColors.primary,
    this.primaryDarkColor = KutumbikaColors.primaryDark,
    this.backgroundColor = KutumbikaColors.background,
  });

  final String appName;
  final String tagline;
  final String? logoUrl;
  final Color primaryColor;
  final Color primaryDarkColor;
  final Color backgroundColor;

  Color get primaryLight => Color.alphaBlend(
        primaryColor.withValues(alpha: 0.12),
        Colors.white,
      );

  static PlatformBranding defaults() => const PlatformBranding();

  factory PlatformBranding.fromJson(Map<String, dynamic> json) {
    return PlatformBranding(
      appName: (json['app_name'] as String?)?.trim().isNotEmpty == true
          ? (json['app_name'] as String).trim()
          : defaults().appName,
      tagline: (json['tagline'] as String?)?.trim().isNotEmpty == true
          ? (json['tagline'] as String).trim()
          : defaults().tagline,
      logoUrl: (json['logo_url'] as String?)?.trim().isNotEmpty == true
          ? (json['logo_url'] as String).trim()
          : null,
      primaryColor: parseHexColor(
        json['primary_color'] as String?,
        fallback: KutumbikaColors.primary,
      ),
      primaryDarkColor: parseHexColor(
        json['primary_dark_color'] as String?,
        fallback: KutumbikaColors.primaryDark,
      ),
      backgroundColor: parseHexColor(
        json['background_color'] as String?,
        fallback: KutumbikaColors.background,
      ),
    );
  }
}
