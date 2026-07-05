import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/platform_branding.dart';
import 'kutumbika_brand_theme.dart';
import 'kutumbika_colors.dart';

abstract final class KutumbikaTheme {
  static ThemeData light([PlatformBranding? branding]) {
    final brand = branding ?? PlatformBranding.defaults();
    final primary = brand.primaryColor;
    final background = brand.backgroundColor;

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        onPrimary: Colors.white,
        surface: KutumbikaColors.surface,
        onSurface: KutumbikaColors.textPrimary,
      ),
      scaffoldBackgroundColor: background,
      cardTheme: CardThemeData(
        color: KutumbikaColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: KutumbikaColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      extensions: [
        KutumbikaBrandTheme(branding: brand),
      ],
    );

    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: KutumbikaColors.textPrimary,
      displayColor: KutumbikaColors.textPrimary,
    );

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
    );
  }
}
