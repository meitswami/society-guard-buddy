import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../../comms/admin_biometric_module.dart';
import '../../comms/admin_geofence_module.dart';
import '../../comms/admin_notifications_module.dart';
import '../../comms/admin_password_module.dart';
import '../../comms/admin_settings_module.dart';
import '../../comms/tour/tour_guide_hub_view.dart';
import '../../gate/blacklist_view.dart';
import '../../gate/delivery_entry_view.dart';
import '../../gate/quick_entry_view.dart';
import '../../gate/vehicle_view.dart';
import '../../gate/visitor_entry_view.dart';
import '../../governance/admin_committee_module.dart';
import '../../governance/admin_documents_module.dart';
import '../../governance/admin_meetings_module.dart';
import '../../governance/admin_polls_module.dart';
import '../audit/admin_audit_module.dart';
import '../events/admin_donations_module.dart';
import '../events/admin_events_module.dart';
import '../events/admin_splits_module.dart';
import '../finance/admin_finance_module.dart';
import '../fixed_assets/admin_fixed_assets_module.dart';
import '../people/admin_directory_module.dart';
import '../people/admin_guards_module.dart';
import '../people/admin_parking_module.dart';
import '../people/admin_residents_module.dart';
import '../reports/admin_logs_module.dart';
import '../reports/admin_reports_module.dart';
import 'admin_module.dart';

/// Maps each admin tab to its module screen (web `AdminPage.tsx` tab switch).
/// The overview tab is built by `AdminShell` itself (it needs logout + visible tabs).
Widget buildAdminModule(AdminTab tab, AdminModuleContext ctx) {
  switch (tab) {
    case AdminTab.overview:
      return _PendingModule(tab: tab);
    case AdminTab.guards:
      return AdminGuardsModule(ctx: ctx);
    case AdminTab.residents:
      return AdminResidentsModule(ctx: ctx);
    case AdminTab.geofence:
      return AdminGeofenceModule(ctx: ctx);
    case AdminTab.password:
      return AdminPasswordModule(ctx: ctx);
    case AdminTab.biometric:
      return AdminBiometricModule(ctx: ctx);
    case AdminTab.audit:
      return AdminAuditModule(ctx: ctx);
    case AdminTab.finance:
      return AdminFinanceModule(ctx: ctx);
    case AdminTab.fixedAssets:
      return AdminFixedAssetsModule(ctx: ctx);
    case AdminTab.donations:
      return AdminDonationsModule(ctx: ctx);
    case AdminTab.events:
      return AdminEventsModule(ctx: ctx);
    case AdminTab.meetings:
      return AdminMeetingsModule(ctx: ctx);
    case AdminTab.documents:
      return AdminDocumentsModule(ctx: ctx);
    case AdminTab.committee:
      return AdminCommitteeModule(ctx: ctx);
    case AdminTab.polls:
      return AdminPollsModule(ctx: ctx);
    case AdminTab.parking:
      return AdminParkingModule(ctx: ctx);
    case AdminTab.splits:
      return AdminSplitsModule(ctx: ctx);
    case AdminTab.notifications:
      return AdminNotificationsModule(ctx: ctx);
    case AdminTab.visitor:
      return VisitorEntryView(actor: ctx.gateActor);
    case AdminTab.delivery:
      return DeliveryEntryView(actor: ctx.gateActor);
    case AdminTab.vehicle:
      return VehicleView(actor: ctx.gateActor, initialSearchQuery: ctx.initialQuery);
    case AdminTab.blacklist:
      return BlacklistView(actor: ctx.gateActor, initialSearchQuery: ctx.initialQuery);
    case AdminTab.directory:
      return AdminDirectoryModule(ctx: ctx);
    case AdminTab.quick:
      return QuickEntryView(actor: ctx.gateActor, initialSearchQuery: ctx.initialQuery);
    case AdminTab.report:
      return AdminReportsModule(ctx: ctx);
    case AdminTab.logs:
      return AdminLogsModule(ctx: ctx);
    case AdminTab.settings:
      return AdminSettingsModule(ctx: ctx);
    case AdminTab.tour:
      return TourGuideHubView(role: 'admin', userId: ctx.adminId);
  }
}

class _PendingModule extends StatelessWidget {
  const _PendingModule({required this.tab});

  final AdminTab tab;

  @override
  Widget build(BuildContext context) {
    return PageContainer(children: [
      PageHeader(title: tab.name, icon: Icons.construction_outlined),
      EmptyView(message: context.tr('This module is being prepared.', 'यह खंड तैयार किया जा रहा है।')),
    ]);
  }
}
