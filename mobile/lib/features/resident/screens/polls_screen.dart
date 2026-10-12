import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../../../models/session_models.dart';
import '../../governance/resident_polls_view.dart';

/// Legacy full-screen route — thin wrapper around [ResidentPollsView] (governance module).
class PollsScreen extends StatelessWidget {
  const PollsScreen({super.key, required this.session});

  final SessionResident session;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(context.tr('Polls & elections', 'मतदान व चुनाव'))),
        body: ResidentPollsView(session: session),
      );
}
