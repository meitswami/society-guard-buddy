import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../../../models/session_models.dart';
import '../core/admin_module.dart';
import 'admin_directory_module.dart';
import 'admin_guards_module.dart';
import 'admin_parking_module.dart';
import 'admin_residents_module.dart';

/// Hosts a people module as a pushed page (legacy `Admin*Screen(session:)` entry points
/// used by older screens). `goTo` between people modules replaces the page.
class PeopleModulePage extends StatelessWidget {
  const PeopleModulePage(
      {super.key,
      required this.session,
      required this.tab,
      this.query,
      this.subTab});

  final SessionAdmin session;
  final AdminTab tab;
  final String? query;
  final String? subTab;

  static bool handles(AdminTab tab) =>
      tab == AdminTab.residents ||
      tab == AdminTab.guards ||
      tab == AdminTab.directory ||
      tab == AdminTab.parking;

  @override
  Widget build(BuildContext context) {
    final ctx = AdminModuleContext(
      session: session,
      initialQuery: query,
      subTab: subTab,
      goTo: (t, {String? query, String? subTab}) {
        final nav = Navigator.of(context);
        if (handles(t)) {
          nav.pushReplacement(MaterialPageRoute(
            builder: (_) => PeopleModulePage(
                session: session, tab: t, query: query, subTab: subTab),
          ));
        } else {
          nav.maybePop();
        }
      },
    );
    final (title, body) = switch (tab) {
      AdminTab.guards => (
          context.t('admin.manageGuards'),
          AdminGuardsModule(ctx: ctx) as Widget
        ),
      AdminTab.directory => (
          context.t('directory.title'),
          AdminDirectoryModule(ctx: ctx) as Widget
        ),
      AdminTab.parking => (
          context.tr('Parking', 'पार्किंग'),
          AdminParkingModule(ctx: ctx) as Widget
        ),
      _ => (
          context.t('admin.manageResidents'),
          AdminResidentsModule(ctx: ctx) as Widget
        ),
    };
    return Scaffold(appBar: AppBar(title: Text(title)), body: body);
  }
}
