import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/kutumbika_theme.dart';
import 'features/auth/society_gate_screen.dart';
import 'providers/branding_provider.dart';

class KutumbikaApp extends ConsumerWidget {
  const KutumbikaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brandingAsync = ref.watch(platformBrandingProvider);
    final branding = brandingAsync.value;

    return MaterialApp(
      title: branding?.appName ?? 'Kutumbika',
      debugShowCheckedModeBanner: false,
      theme: KutumbikaTheme.light(branding),
      home: brandingAsync.isLoading && branding == null
          ? const _SplashScreen()
          : const SocietyGateScreen(),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
