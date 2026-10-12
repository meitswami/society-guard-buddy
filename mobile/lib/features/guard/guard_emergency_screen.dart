import 'package:flutter/material.dart';

import '../../models/session_models.dart';
import '../comms/core/comms_i18n.dart';
import '../comms/emergency_alert_view.dart';

/// Legacy pushed page — wraps `EmergencyAlertView` (COMMS) for guards.
class GuardEmergencyScreen extends StatelessWidget {
  const GuardEmergencyScreen({super.key, required this.session});

  final SessionGuard session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.ct('comms.emergency.title'))),
      body: EmergencyAlertView(
          societyId: session.societyId,
          senderName: session.guard.name,
          senderRole: 'guard'),
    );
  }
}
