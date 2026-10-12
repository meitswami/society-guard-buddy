import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/i18n/i18n.dart';
import 'core/prefs/app_prefs.dart';
import 'core/router/app_router.dart';
import 'core/theme/kutumbika_theme.dart';
import 'features/shared/widgets/biometric_gate.dart';
import 'models/session_models.dart';
import 'providers/branding_provider.dart';
import 'providers/session_provider.dart';

class KutumbikaApp extends ConsumerWidget {
  const KutumbikaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brandingAsync = ref.watch(platformBrandingProvider);
    final sessionAsync = ref.watch(sessionProvider);
    final branding = brandingAsync.value;
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final translator = ref.watch(translatorProvider);

    Widget withI18n(BuildContext context, Widget? child) =>
        I18nScope(translator: translator, child: child ?? const SizedBox.shrink());

    // Only block on session restore — branding can paint with defaults.
    if (sessionAsync.isLoading) {
      return MaterialApp(
        title: 'Kutumbika',
        debugShowCheckedModeBanner: false,
        theme: KutumbikaTheme.light(branding),
        darkTheme: KutumbikaTheme.dark(branding),
        themeMode: themeMode,
        builder: withI18n,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(child: Text(context.t('app.loading'))),
          ),
        ),
      );
    }

    final session = sessionAsync.value;
    final locked = session is SessionResident ||
        session is SessionGuard ||
        session is SessionAdmin ||
        session is SessionSuperadmin;

    return BiometricGate(
      locked: locked,
      child: MaterialApp.router(
        title: branding?.appName ?? 'Kutumbika',
        debugShowCheckedModeBanner: false,
        theme: KutumbikaTheme.light(branding),
        darkTheme: KutumbikaTheme.dark(branding),
        themeMode: themeMode,
        builder: withI18n,
        routerConfig: router,
      ),
    );
  }
}
