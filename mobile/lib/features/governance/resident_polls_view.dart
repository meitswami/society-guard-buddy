import 'package:flutter/material.dart';

import '../../models/session_models.dart';
import 'data/gov_backend.dart';
import 'models/poll_models.dart';
import 'polls/polls_page.dart';

/// Resident "Polls" tab (web `PollManager isResident voterId voterPhone memberId memberName flatNumber flatId`).
class ResidentPollsView extends StatelessWidget {
  const ResidentPollsView({super.key, required this.session});

  final SessionResident session;

  PollViewer _viewer({String memberId = '', String? memberName}) => PollViewer(
        isResident: true,
        voterId: session.resident.id,
        voterPhone: session.resident.phone,
        memberId: memberId,
        memberName: (memberName == null || memberName.isEmpty)
            ? session.resident.name
            : memberName,
        flatNumber: session.resident.flatNumber,
        flatId: session.resident.flatId,
      );

  @override
  Widget build(BuildContext context) => PollsPage(
        societyId: session.societyId,
        societyName: session.societyName,
        viewer: _viewer(),
        resolveViewer: () async {
          final me = await GovBackend.residentMember(session);
          return _viewer(memberId: me?.id ?? '', memberName: me?.name);
        },
      );
}
