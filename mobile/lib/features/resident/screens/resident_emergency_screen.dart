import 'package:flutter/material.dart';

import '../../../models/session_models.dart';
import '../../comms/core/comms_i18n.dart';
import '../../comms/emergency_alert_view.dart';

/// Legacy pushed page — wraps `EmergencyAlertView` (COMMS) for residents.
class ResidentEmergencyScreen extends StatelessWidget {
  const ResidentEmergencyScreen({super.key, required this.session});

  final SessionResident session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.ct('comms.emergency.modeTitle'))),
      body: EmergencyAlertView(
        societyId: session.societyId,
        senderName: session.resident.name,
        senderRole: 'resident',
        flatNumber: session.resident.flatNumber,
      ),
    );
  }
}
