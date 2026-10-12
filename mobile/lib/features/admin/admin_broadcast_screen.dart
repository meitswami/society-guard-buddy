import 'package:flutter/material.dart';

import '../../models/session_models.dart';
import '../comms/admin_notifications_module.dart';
import '../comms/core/comms_i18n.dart';
import 'core/admin_module.dart';

/// Legacy entry point kept for older callers — the full Notification Center now lives in
/// `AdminNotificationsModule` (COMMS).
class AdminBroadcastScreen extends StatelessWidget {
  const AdminBroadcastScreen({super.key, required this.session});

  final SessionAdmin session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.ct('comms.notif.title'))),
      body: AdminNotificationsModule(
        ctx:
            AdminModuleContext(session: session, goTo: (_, {query, subTab}) {}),
      ),
    );
  }
}
