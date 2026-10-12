import 'package:flutter/material.dart';

import '../../models/session_models.dart';
import '../comms/guard_settings_view.dart';

/// Legacy entry point — guard settings now live in `GuardSettingsView` (COMMS).
class GuardSettingsScreen extends StatelessWidget {
  const GuardSettingsScreen({super.key, required this.session});

  final SessionGuard session;

  @override
  Widget build(BuildContext context) => GuardSettingsView(session: session);
}
