import 'package:flutter/material.dart';

import '../../models/session_models.dart';
import 'admin_polls_hub_screen.dart';

/// Legacy route — Society Elections section of [AdminPollsHubScreen].
class AdminElectionsScreen extends StatelessWidget {
  const AdminElectionsScreen(
      {super.key, required this.session, this.embedded = false});

  final SessionAdmin session;
  final bool embedded;

  @override
  Widget build(BuildContext context) =>
      AdminPollsHubScreen(session: session, subTab: 'elections');
}
