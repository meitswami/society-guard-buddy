import 'package:flutter/material.dart';

import '../../models/session_models.dart';
import 'data/gov_backend.dart';
import 'meetings/meetings_page.dart';

/// Resident "Meetings" tab (web `MeetingManager isResident residentMemberId residentName residentFlatNumber`).
class ResidentMeetingsView extends StatelessWidget {
  const ResidentMeetingsView({super.key, required this.session});

  final SessionResident session;

  MeetingViewer _viewer({String? memberId, String? memberName}) => MeetingViewer(
        societyId: session.societyId,
        isResident: true,
        residentMemberId: memberId,
        residentName: (memberName == null || memberName.isEmpty) ? session.resident.name : memberName,
        residentFlatNumber: session.resident.flatNumber,
      );

  @override
  Widget build(BuildContext context) => MeetingsPage(
        viewer: _viewer(),
        resolveViewer: () async {
          final me = await GovBackend.residentMember(session);
          return _viewer(memberId: me?.id, memberName: me?.name);
        },
      );
}
