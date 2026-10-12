import 'package:flutter/material.dart';

import '../../../models/session_models.dart';
import '../../comms/notifications_inbox_view.dart';

/// Legacy entry point — the resident inbox now lives in `NotificationsInboxView` (COMMS).
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key, required this.session});

  final SessionResident session;

  @override
  Widget build(BuildContext context) =>
      NotificationsInboxView(session: session, showEmergencyButton: true);
}
