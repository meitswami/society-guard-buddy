import 'package:flutter/material.dart';

import '../../models/session_models.dart';
import '../admin/people/flat360/flat360_profile_sheet.dart';
import '../comms/emergency_alert_view.dart';
import '../comms/notifications_inbox_view.dart';
import '../comms/tour/tour_guide_first_login.dart';
import '../comms/tour/tour_guide_hub_view.dart';
import '../governance/resident_committee_view.dart';
import '../governance/resident_documents_view.dart';
import '../governance/resident_meetings_view.dart';
import '../governance/resident_polls_view.dart';
import '../shared/directory/directory_view.dart';

/// Views owned by other modules, mounted by contract (AGENT_BRIEF contract table).
/// Kept in one file so a not-yet-delivered view only affects this import list.
abstract final class ResidentExternalViews {
  static Widget directory(SessionResident s, {VoidCallback? onOpenFamily, VoidCallback? onOpenVehicles}) => DirectoryView(
        societyId: s.societyId,
        viewerRole: 'resident',
        viewerName: s.resident.name,
        viewerFlatId: s.resident.flatId,
        onOpenFamily: onOpenFamily,
        onOpenVehicles: onOpenVehicles,
      );

  static Widget notifications(SessionResident s) => NotificationsInboxView(session: s);

  static Widget emergency(SessionResident s) => EmergencyAlertView(
        societyId: s.societyId,
        senderName: s.resident.name,
        senderRole: 'resident',
        flatNumber: s.resident.flatNumber,
      );

  static Widget polls(SessionResident s) => ResidentPollsView(session: s);

  static Widget meetings(SessionResident s) => ResidentMeetingsView(session: s);

  static Widget documents(SessionResident s) => ResidentDocumentsView(session: s);

  static Widget committee(SessionResident s) => ResidentCommitteeView(session: s);

  static Widget tour(SessionResident s) => TourGuideHubView(role: 'resident', userId: s.resident.id);

  static Future<void> maybeShowFirstLoginTour(BuildContext context, SessionResident s) async {
    await TourGuideFirstLogin.maybeShow(context, role: 'resident', userId: s.resident.id);
  }

  static Future<void> showFlat360(BuildContext context, SessionResident s) async {
    await Flat360ProfileSheet.show(context, societyId: s.societyId, flatId: s.resident.flatId);
  }
}
