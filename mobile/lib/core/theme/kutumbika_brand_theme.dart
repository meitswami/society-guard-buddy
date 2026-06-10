import 'package:flutter/material.dart';

import '../../models/platform_branding.dart';

class KutumbikaBrandTheme extends ThemeExtension<KutumbikaBrandTheme> {
  const KutumbikaBrandTheme({
    required this.branding,
  });

  final PlatformBranding branding;

  Color get primary => branding.primaryColor;
  Color get primaryDark => branding.primaryDarkColor;
  Color get primaryLight => branding.primaryLight;
  Color get background => branding.backgroundColor;
  String? get logoUrl => branding.logoUrl;
  String get appName => branding.appName;
  String get tagline => branding.tagline;

  @override
  KutumbikaBrandTheme copyWith({PlatformBranding? branding}) {
    return KutumbikaBrandTheme(branding: branding ?? this.branding);
  }

  @override
  KutumbikaBrandTheme lerp(ThemeExtension<KutumbikaBrandTheme>? other, double t) {
    if (other is! KutumbikaBrandTheme) return this;
    return KutumbikaBrandTheme(branding: other.branding);
  }

  static KutumbikaBrandTheme of(BuildContext context) {
    return Theme.of(context).extension<KutumbikaBrandTheme>() ??
        KutumbikaBrandTheme(branding: PlatformBranding.defaults());
  }
}
