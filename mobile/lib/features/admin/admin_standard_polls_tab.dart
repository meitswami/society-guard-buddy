import 'package:flutter/material.dart';

import '../../models/session_models.dart';
import 'admin_polls_hub_screen.dart';

/// Legacy route — General Polls section of [AdminPollsHubScreen].
class AdminStandardPollsTab extends StatelessWidget {
  const AdminStandardPollsTab({super.key, required this.session});

  final SessionAdmin session;

  @override
  Widget build(BuildContext context) =>
      AdminPollsHubScreen(session: session, subTab: 'polls');
}
