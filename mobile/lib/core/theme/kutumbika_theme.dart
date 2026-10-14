import 'package:flutter/material.dart';

import '../../models/platform_branding.dart';
import 'app_tokens.dart';
import 'kutumbika_brand_theme.dart';

/// Material theme built from the web design tokens (`AppTokens`), so screens look the
/// same as the responsive web app. Branding supplies the app name / logo / tagline;
/// colours always follow the web palette for light and dark mode.
abstract final class KutumbikaTheme {
  static const String fontFamily = 'Inter';
  static const String monoFamily = 'JetBrainsMono';
  static const List<String> fontFallback = ['NotoSansDevanagari', 'NotoSans'];

  static ThemeData light([PlatformBranding? branding]) => _build(AppTokens.light, branding);

  static ThemeData dark([PlatformBranding? branding]) => _build(AppTokens.dark, branding);

  static ThemeData _build(AppTokens t, PlatformBranding? branding) {
    final brand = (branding ?? PlatformBranding.defaults()).withColors(
      primary: t.primary,
      primaryDark: Color.alphaBlend(Colors.black.withValues(alpha: 0.15), t.primary),
      background: t.background,
    );

    final scheme = ColorScheme(
      brightness: t.brightness,
      primary: t.primary,
      onPrimary: t.primaryForeground,
      primaryContainer: AppTokens.tint(t.primary, 0.12),
      onPrimaryContainer: t.primary,
      secondary: t.accent,
      onSecondary: t.accentForeground,
      secondaryContainer: t.secondary,
      onSecondaryContainer: t.secondaryForeground,
      tertiary: t.success,
      onTertiary: t.successForeground,
      error: t.destructive,
      onError: t.destructiveForeground,
      surface: t.card,
      onSurface: t.foreground,
      onSurfaceVariant: t.mutedForeground,
      surfaceContainerHighest: t.muted,
      surfaceContainerHigh: t.secondary,
      surfaceContainer: t.muted,
      surfaceContainerLow: t.card,
      surfaceContainerLowest: t.card,
      outline: t.border,
      outlineVariant: t.border,
      shadow: Colors.black,
      scrim: Colors.black54,
      inverseSurface: t.foreground,
      onInverseSurface: t.background,
      inversePrimary: t.primary,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: t.brightness,
      colorScheme: scheme,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFallback,
      scaffoldBackgroundColor: t.background,
      canvasColor: t.background,
      dividerColor: t.border,
      splashFactory: InkSparkle.splashFactory,
    );

    final radiusSm = BorderRadius.circular(AppTokens.radiusSm);
    final outline = OutlineInputBorder(borderRadius: radiusSm, borderSide: BorderSide(color: t.border));

    return base.copyWith(
      textTheme: base.textTheme.apply(bodyColor: t.foreground, displayColor: t.foreground),
      primaryTextTheme: base.primaryTextTheme.apply(bodyColor: t.primaryForeground, displayColor: t.primaryForeground),
      appBarTheme: AppBarTheme(
        backgroundColor: t.background,
        foregroundColor: t.foreground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontFamilyFallback: fontFallback,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: t.foreground,
        ),
      ),
      cardTheme: CardThemeData(
        color: t.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radius),
          side: BorderSide(color: t.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.input,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        hintStyle: TextStyle(color: t.mutedForeground, fontSize: 14),
        labelStyle: TextStyle(color: t.mutedForeground, fontSize: 14),
        floatingLabelStyle: TextStyle(color: t.primary),
        border: outline,
        enabledBorder: outline,
        disabledBorder: outline,
        focusedBorder: OutlineInputBorder(borderRadius: radiusSm, borderSide: BorderSide(color: t.ring, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: radiusSm, borderSide: BorderSide(color: t.destructive)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: radiusSm, borderSide: BorderSide(color: t.destructive, width: 2)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.primary,
          foregroundColor: t.primaryForeground,
          disabledBackgroundColor: AppTokens.tint(t.primary, 0.4),
          disabledForegroundColor: AppTokens.tint(t.primaryForeground, 0.8),
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: radiusSm),
          textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: t.primary,
          foregroundColor: t.primaryForeground,
          elevation: 0,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: radiusSm),
          textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.secondaryForeground,
          backgroundColor: t.secondary,
          side: BorderSide(color: t.border),
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: radiusSm),
          textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w500, fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.primary,
          textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: t.mutedForeground)),
      chipTheme: ChipThemeData(
        backgroundColor: t.secondary,
        selectedColor: t.primary,
        disabledColor: t.muted,
        labelStyle: TextStyle(color: t.secondaryForeground, fontSize: 12, fontWeight: FontWeight.w500),
        secondaryLabelStyle: TextStyle(color: t.primaryForeground, fontSize: 12, fontWeight: FontWeight.w600),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: radiusSm),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        checkmarkColor: t.primaryForeground,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusXl)),
        titleTextStyle: TextStyle(fontFamily: fontFamily, fontSize: 18, fontWeight: FontWeight.w700, color: t.foreground),
        contentTextStyle: TextStyle(fontFamily: fontFamily, fontSize: 14, color: t.mutedForeground),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        showDragHandle: true,
        dragHandleColor: t.border,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: t.foreground,
        contentTextStyle: TextStyle(fontFamily: fontFamily, color: t.background, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: radiusSm),
      ),
      dividerTheme: DividerThemeData(color: t.border, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: t.mutedForeground,
        textColor: t.foreground,
        subtitleTextStyle: TextStyle(fontFamily: fontFamily, fontSize: 12, color: t.mutedForeground),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.primaryForeground : t.mutedForeground),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.primary : t.secondary),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.primary : Colors.transparent),
        checkColor: WidgetStateProperty.all(t.primaryForeground),
        side: BorderSide(color: t.border, width: 1.5),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.primary : t.mutedForeground),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: t.primary, linearTrackColor: t.secondary),
      tabBarTheme: TabBarThemeData(
        labelColor: t.primary,
        unselectedLabelColor: t.mutedForeground,
        indicatorColor: t.primary,
        dividerColor: t.border,
        labelStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600, fontSize: 13),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: t.card,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppTokens.tint(t.primary, 0.12),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? t.primary : t.mutedForeground),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontFamily: fontFamily,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: s.contains(WidgetState.selected) ? t.primary : t.mutedForeground,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: t.primary,
        foregroundColor: t.primaryForeground,
        elevation: 2,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: t.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radiusSm, side: BorderSide(color: t.border)),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: t.card,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: t.primary,
        headerForegroundColor: t.primaryForeground,
      ),
      expansionTileTheme: ExpansionTileThemeData(
        iconColor: t.primary,
        collapsedIconColor: t.mutedForeground,
        textColor: t.foreground,
        collapsedTextColor: t.foreground,
        shape: const Border(),
        collapsedShape: const Border(),
      ),
      extensions: [
        t,
        KutumbikaBrandTheme(branding: brand),
      ],
    );
  }
}
