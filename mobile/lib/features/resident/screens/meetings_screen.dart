import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../../../models/session_models.dart';
import '../../governance/resident_meetings_view.dart';

/// Legacy full-screen route — thin wrapper around [ResidentMeetingsView] (governance module).
class MeetingsScreen extends StatelessWidget {
  const MeetingsScreen({super.key, required this.session});

  final SessionResident session;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(context.tr('Meetings', 'बैठकें'))),
        body: ResidentMeetingsView(session: session),
      );
}
