import 'package:flutter/material.dart';

/// Design tokens copied from the web app (`src/index.css`, `:root` / `[data-theme="light"]`).
/// Every screen should take colours from here (via `context.tokens`) so the Android / iOS
/// app looks exactly like the responsive web app in light and dark mode.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.brightness,
    required this.background,
    required this.foreground,
    required this.card,
    required this.cardForeground,
    required this.primary,
    required this.primaryForeground,
    required this.secondary,
    required this.secondaryForeground,
    required this.muted,
    required this.mutedForeground,
    required this.accent,
    required this.accentForeground,
    required this.destructive,
    required this.destructiveForeground,
    required this.success,
    required this.successForeground,
    required this.warning,
    required this.warningForeground,
    required this.border,
    required this.input,
    required this.ring,
  });

  final Brightness brightness;
  final Color background;
  final Color foreground;
  final Color card;
  final Color cardForeground;
  final Color primary;
  final Color primaryForeground;
  final Color secondary;
  final Color secondaryForeground;
  final Color muted;
  final Color mutedForeground;
  final Color accent;
  final Color accentForeground;
  final Color destructive;
  final Color destructiveForeground;
  final Color success;
  final Color successForeground;
  final Color warning;
  final Color warningForeground;
  final Color border;
  final Color input;
  final Color ring;

  /// `--radius: 0.75rem` → 12 logical px (cards). Inputs/buttons use `radiusSm` (rounded-lg = 8).
  static const double radius = 12;
  static const double radiusSm = 8;
  static const double radiusXl = 16;

  bool get isDark => brightness == Brightness.dark;

  static Color _hsl(double h, double s, double l) =>
      HSLColor.fromAHSL(1, h, s / 100, l / 100).toColor();

  /// `[data-theme="light"]`
  static final AppTokens light = AppTokens(
    brightness: Brightness.light,
    background: _hsl(195, 40, 97),
    foreground: _hsl(222, 40, 12),
    card: _hsl(0, 0, 100),
    cardForeground: _hsl(222, 40, 12),
    primary: _hsl(175, 78, 34),
    primaryForeground: _hsl(0, 0, 100),
    secondary: _hsl(200, 30, 92),
    secondaryForeground: _hsl(222, 30, 28),
    muted: _hsl(200, 28, 94),
    mutedForeground: _hsl(215, 16, 42),
    accent: _hsl(190, 85, 38),
    accentForeground: _hsl(0, 0, 100),
    destructive: _hsl(0, 72, 48),
    destructiveForeground: _hsl(0, 0, 100),
    success: _hsl(152, 70, 36),
    successForeground: _hsl(0, 0, 100),
    warning: _hsl(38, 92, 46),
    warningForeground: _hsl(222, 40, 12),
    border: _hsl(200, 22, 86),
    input: _hsl(200, 25, 92),
    ring: _hsl(175, 78, 34),
  );

  /// `:root, [data-theme="dark"]`
  static final AppTokens dark = AppTokens(
    brightness: Brightness.dark,
    background: _hsl(222, 42, 8),
    foreground: _hsl(195, 30, 94),
    card: _hsl(222, 36, 12),
    cardForeground: _hsl(195, 30, 94),
    primary: _hsl(175, 85, 48),
    primaryForeground: _hsl(222, 42, 6),
    secondary: _hsl(222, 30, 17),
    secondaryForeground: _hsl(195, 20, 88),
    muted: _hsl(222, 28, 15),
    mutedForeground: _hsl(210, 15, 58),
    accent: _hsl(190, 90, 52),
    accentForeground: _hsl(222, 42, 6),
    destructive: _hsl(0, 78, 58),
    destructiveForeground: _hsl(0, 0, 100),
    success: _hsl(152, 72, 45),
    successForeground: _hsl(0, 0, 100),
    warning: _hsl(38, 92, 50),
    warningForeground: _hsl(222, 42, 8),
    border: _hsl(222, 28, 20),
    input: _hsl(222, 28, 16),
    ring: _hsl(175, 85, 48),
  );

  /// Tailwind-style translucent fill, e.g. `bg-primary/10` → `primary.tint(0.10)`.
  static Color tint(Color c, double opacity) => c.withValues(alpha: opacity);

  @override
  AppTokens copyWith({Color? primary, Color? ring}) => AppTokens(
        brightness: brightness,
        background: background,
        foreground: foreground,
        card: card,
        cardForeground: cardForeground,
        primary: primary ?? this.primary,
        primaryForeground: primaryForeground,
        secondary: secondary,
        secondaryForeground: secondaryForeground,
        muted: muted,
        mutedForeground: mutedForeground,
        accent: accent,
        accentForeground: accentForeground,
        destructive: destructive,
        destructiveForeground: destructiveForeground,
        success: success,
        successForeground: successForeground,
        warning: warning,
        warningForeground: warningForeground,
        border: border,
        input: input,
        ring: ring ?? this.ring,
      );

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppTokens(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: l(background, other.background),
      foreground: l(foreground, other.foreground),
      card: l(card, other.card),
      cardForeground: l(cardForeground, other.cardForeground),
      primary: l(primary, other.primary),
      primaryForeground: l(primaryForeground, other.primaryForeground),
      secondary: l(secondary, other.secondary),
      secondaryForeground: l(secondaryForeground, other.secondaryForeground),
      muted: l(muted, other.muted),
      mutedForeground: l(mutedForeground, other.mutedForeground),
      accent: l(accent, other.accent),
      accentForeground: l(accentForeground, other.accentForeground),
      destructive: l(destructive, other.destructive),
      destructiveForeground: l(destructiveForeground, other.destructiveForeground),
      success: l(success, other.success),
      successForeground: l(successForeground, other.successForeground),
      warning: l(warning, other.warning),
      warningForeground: l(warningForeground, other.warningForeground),
      border: l(border, other.border),
      input: l(input, other.input),
      ring: l(ring, other.ring),
    );
  }
}

extension AppTokensX on BuildContext {
  /// Web design tokens for the current light / dark theme.
  AppTokens get tokens => Theme.of(this).extension<AppTokens>() ?? AppTokens.light;
}
