import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'kutumbika_colors.dart';

abstract final class KutumbikaTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: KutumbikaColors.primary,
        primary: KutumbikaColors.primary,
        onPrimary: Colors.white,
        surface: KutumbikaColors.surface,
        onSurface: KutumbikaColors.textPrimary,
      ),
      scaffoldBackgroundColor: KutumbikaColors.background,
      cardTheme: CardThemeData(
        color: KutumbikaColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: KutumbikaColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: CircleBorder(),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: KutumbikaColors.background,
        foregroundColor: KutumbikaColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
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
