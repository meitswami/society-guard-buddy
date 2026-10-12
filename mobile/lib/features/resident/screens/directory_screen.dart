import 'package:flutter/material.dart';

import '../../../models/session_models.dart';
import '../../shared/directory/directory_view.dart';

/// Resident directory tab — wrapper around the shared [DirectoryView].
class DirectoryScreen extends StatelessWidget {
  const DirectoryScreen(
      {super.key,
      required this.session,
      this.onOpenFamily,
      this.onOpenVehicles});

  final SessionResident session;
  final VoidCallback? onOpenFamily;
  final VoidCallback? onOpenVehicles;

  @override
  Widget build(BuildContext context) => DirectoryView(
        societyId: session.societyId,
        viewerRole: 'resident',
        viewerName: session.resident.name,
        viewerFlatId: session.resident.flatId,
        onOpenFamily: onOpenFamily,
        onOpenVehicles: onOpenVehicles,
      );
}
