import 'package:flutter/material.dart';

import '../admin/core/admin_module.dart';
import 'meetings/meetings_page.dart';

/// Admin "Meetings" module (web `MeetingManager adminName={admin.name}`): notices,
/// agenda, documents, attendance, minutes, recording, decisions, signatures, publish.
class AdminMeetingsModule extends StatelessWidget {
  const AdminMeetingsModule({super.key, required this.ctx});

  final AdminModuleContext ctx;

  @override
  Widget build(BuildContext context) => MeetingsPage(
        viewer: MeetingViewer(
            societyId: ctx.societyId,
            isResident: false,
            adminName: ctx.adminName),
      );
}
