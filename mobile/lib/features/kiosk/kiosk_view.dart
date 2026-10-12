import 'package:flutter/material.dart';

import '../../models/session_models.dart';
import 'data/kiosk_settings_store.dart';
import 'logic/kiosk_settings.dart';
import 'widgets/kiosk_runner.dart';
import 'widgets/kiosk_setup_panel.dart';

export 'kiosk_lock.dart' show isKioskLocked, kioskLockedListenable;

/// Guard tab "AI Kiosk" — port of web `KioskPage.tsx`.
///
/// Shows the guard setup screen (options + device checks); "Start kiosk" opens the
/// running receptionist as its own full-screen route (immersive, screen kept awake,
/// Android back blocked). Leaving the kiosk (hold the lock 3 s, optional PIN)
/// returns here; the back arrow calls [onExit].
class KioskView extends StatefulWidget {
  const KioskView({super.key, required this.session, this.onExit});

  final SessionGuard session;
  final VoidCallback? onExit;

  @override
  State<KioskView> createState() => _KioskViewState();
}

class _KioskViewState extends State<KioskView> {
  KioskSettings _settings = KioskSettingsStore.read();
  bool _running = false;

  void _update(KioskSettings s) {
    setState(() => _settings = s);
    KioskSettingsStore.write(s);
  }

  Future<void> _start() async {
    if (_running) return;
    setState(() => _running = true);
    try {
      await Navigator.of(context, rootNavigator: true).push<void>(
        PageRouteBuilder<void>(
          opaque: true,
          fullscreenDialog: true,
          transitionDuration: const Duration(milliseconds: 200),
          pageBuilder: (_, __, ___) => KioskRunnerPage(settings: _settings, session: widget.session),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
        ),
      );
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KioskSetupPanel(
      settings: _settings,
      onChange: _update,
      onStart: _start,
      onBack: widget.onExit,
    );
  }
}
