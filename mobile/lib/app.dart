import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    final showSplash = (brandingAsync.isLoading && branding == null) ||
        sessionAsync.isLoading;

    if (showSplash) {
      return MaterialApp(
        title: 'Kutumbika',
        debugShowCheckedModeBanner: false,
        theme: KutumbikaTheme.light(branding),
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final session = sessionAsync.value;
    final locked = session is SessionResident ||
        session is SessionGuard ||
        session is SessionAdmin;

    return BiometricGate(
      locked: locked,
      child: MaterialApp.router(
        title: branding?.appName ?? 'Kutumbika',
        debugShowCheckedModeBanner: false,
        theme: KutumbikaTheme.light(branding),
        routerConfig: router,
      ),
    );
  }
}
