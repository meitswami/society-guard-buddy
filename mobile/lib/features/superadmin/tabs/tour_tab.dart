import 'package:flutter/material.dart';

import '../../comms/tour/tour_guide_first_login.dart';
import '../../comms/tour/tour_guide_hub_view.dart';
import '../widgets/sa_widgets.dart';
import 'tab_page.dart';

/// Web Tour tab: `<TourGuideHub role="superadmin" />` (COMMS module widget) under the
/// dashboard header.
class SuperadminTourTab extends StatelessWidget {
  const SuperadminTourTab({super.key, required this.ctx});

  final SuperadminTabContext ctx;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 512),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: SuperadminHeader(name: ctx.session.name, onLogout: ctx.onLogout, bottomSpacing: 0),
            ),
          ),
        ),
        Expanded(child: TourGuideHubView(role: 'superadmin', userId: ctx.session.id)),
      ],
    );
  }
}

/// Web `<TourGuideFirstLogin role="superadmin" userId={superadmin.id} />`.
Future<void> maybeShowSuperadminFirstTour(BuildContext context, String superadminId) =>
    TourGuideFirstLogin.maybeShow(context, role: 'superadmin', userId: superadminId);
