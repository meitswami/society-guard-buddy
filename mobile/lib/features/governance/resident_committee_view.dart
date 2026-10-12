import 'package:flutter/material.dart';

import '../../models/session_models.dart';
import 'committee/committee_page.dart';

/// Resident "Committee" tab (web `CommitteeManager isResident`): roster + duties chart, read-only.
class ResidentCommitteeView extends StatelessWidget {
  const ResidentCommitteeView({super.key, required this.session});

  final SessionResident session;

  @override
  Widget build(BuildContext context) => CommitteePage(societyId: session.societyId, isResident: true);
}
