import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../../../models/session_models.dart';
import '../../governance/resident_polls_view.dart';

/// Legacy full-screen route — thin wrapper around [ResidentPollsView] (governance module).
class ElectionsScreen extends StatelessWidget {
  const ElectionsScreen({super.key, required this.session});

  final SessionResident session;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(context.tr('Society elections', 'सोसायटी चुनाव'))),
        body: ResidentPollsView(session: session),
      );
}
