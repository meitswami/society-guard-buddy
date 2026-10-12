import 'package:flutter/material.dart';

import '../../core/ui/ui.dart';
import '../../models/session_models.dart';
import '../governance/admin_polls_module.dart';
import 'core/admin_module.dart';

/// Legacy full-screen route — thin wrapper around [AdminPollsModule].
class AdminPollsHubScreen extends StatelessWidget {
  const AdminPollsHubScreen({super.key, required this.session, this.subTab});

  final SessionAdmin session;

  /// `polls` opens General Polls; anything else opens Society Elections.
  final String? subTab;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(context.tr('Polls & elections', 'मतदान व चुनाव'))),
        body: AdminPollsModule(
          ctx: AdminModuleContext(
              session: session, goTo: (_, {query, subTab}) {}, subTab: subTab),
        ),
      );
}
