import 'package:flutter/material.dart';

import '../admin/core/admin_module.dart';
import 'models/poll_models.dart';
import 'polls/polls_page.dart';

/// Admin "Polls & Elections" module (web `PollManager adminName={admin.name}`).
/// `ctx.subTab` = `polls` opens the General Polls section.
class AdminPollsModule extends StatelessWidget {
  const AdminPollsModule({super.key, required this.ctx});

  final AdminModuleContext ctx;

  @override
  Widget build(BuildContext context) => PollsPage(
        societyId: ctx.societyId,
        societyName: ctx.societyName,
        initialSection: ctx.subTab == 'polls' ? PollsSection.polls : PollsSection.elections,
        viewer: PollViewer(isResident: false, adminName: ctx.adminName),
      );
}
