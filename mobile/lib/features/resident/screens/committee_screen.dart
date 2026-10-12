import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../../../models/session_models.dart';
import '../../governance/resident_committee_view.dart';

/// Legacy full-screen route — thin wrapper around [ResidentCommitteeView] (governance module).
class CommitteeScreen extends StatelessWidget {
  const CommitteeScreen({super.key, required this.session});

  final SessionResident session;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(context.tr('Committee', 'समिति'))),
        body: ResidentCommitteeView(session: session),
      );
}
