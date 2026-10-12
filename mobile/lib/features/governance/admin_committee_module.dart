import 'package:flutter/material.dart';

import '../admin/core/admin_module.dart';
import 'committee/committee_page.dart';

/// Admin "Committee" module (web `CommitteeManager` + `CommitteeDutiesChart`).
class AdminCommitteeModule extends StatelessWidget {
  const AdminCommitteeModule({super.key, required this.ctx});

  final AdminModuleContext ctx;

  @override
  Widget build(BuildContext context) => CommitteePage(societyId: ctx.societyId, isResident: false);
}
