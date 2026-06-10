import 'package:flutter/material.dart';

import 'core/theme/kutumbika_theme.dart';
import 'features/auth/society_gate_screen.dart';

class KutumbikaApp extends StatelessWidget {
  const KutumbikaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kutumbika',
      debugShowCheckedModeBanner: false,
      theme: KutumbikaTheme.light(),
      home: const SocietyGateScreen(),
    );
  }
}
