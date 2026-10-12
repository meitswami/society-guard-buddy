import 'package:flutter/material.dart';

/// Legacy constant palette (light theme values from the web `src/index.css`).
/// Prefer `context.tokens` from `app_tokens.dart`, which also follows dark mode.
abstract final class KutumbikaColors {
  static const Color primary = Color(0xFF139A8E); // hsl(175 78% 34%)
  static const Color primaryDark = Color(0xFF0F7F75);
  static const Color primaryLight = Color(0xFFE3F5F3);

  static const Color background = Color(0xFFF4F9FB); // hsl(195 40% 97%)
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFEDF3F6); // hsl(200 28% 94%)

  static const Color textPrimary = Color(0xFF121A2B); // hsl(222 40% 12%)
  static const Color textSecondary = Color(0xFF59677D); // hsl(215 16% 42%)
  static const Color textMuted = Color(0xFF8B97A8);

  static const Color success = Color(0xFF1B9C62); // hsl(152 70% 36%)
  static const Color successBg = Color(0xFFE3F6EC);

  static const Color badge = Color(0xFF139A8E);
  static const Color navInactive = Color(0xFF8B97A8);

  static const Color announcementBlue = Color(0xFF3B82F6);
  static const Color announcementTeal = Color(0xFF0D9488);
}
