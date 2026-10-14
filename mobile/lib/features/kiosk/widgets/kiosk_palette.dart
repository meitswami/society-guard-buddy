import 'package:flutter/material.dart';

/// The visitor-facing kiosk screen is deliberately fixed-dark on the web
/// (`bg-[#0b1020] text-white`, Tailwind orange / emerald / amber / indigo accents),
/// identical in light and dark theme. This palette mirrors those exact web values;
/// the guard-facing setup screen uses the theme tokens as usual.
abstract final class KioskPalette {
  static const Color background = Color(0xFF0B1020); // bg-[#0b1020]
  static const Color white = Color(0xFFFFFFFF);
  static const Color slate900 = Color(0xFF0F172A); // text-slate-900 (typing field)
  static const Color black = Color(0xFF000000);

  static const Color orange200 = Color(0xFFFED7AA);
  static const Color orange300 = Color(0xFFFDBA74);
  static const Color orange400 = Color(0xFFFB923C);
  static const Color orange500 = Color(0xFFF97316);

  static const Color emerald200 = Color(0xFFA7F3D0);
  static const Color emerald300 = Color(0xFF6EE7B7);
  static const Color emerald400 = Color(0xFF34D399);
  static const Color emerald500 = Color(0xFF10B981);

  static const Color amber200 = Color(0xFFFDE68A);
  static const Color amber400 = Color(0xFFFBBF24);

  static const Color red200 = Color(0xFFFECACA);
  static const Color red400 = Color(0xFFF87171);

  static const Color indigo500 = Color(0xFF6366F1);

  /// `white/NN` (Tailwind opacity modifier).
  static Color whiteA(double opacity) => white.withValues(alpha: opacity);

  static Color a(Color c, double opacity) => c.withValues(alpha: opacity);
}
