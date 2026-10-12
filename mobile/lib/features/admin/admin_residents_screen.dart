import 'package:flutter/material.dart';

import '../../models/session_models.dart';
import 'core/admin_module.dart';
import 'people/people_legacy_host.dart';

/// Legacy entry point — now the full-parity `AdminResidentsModule`.
class AdminResidentsScreen extends StatelessWidget {
  const AdminResidentsScreen({super.key, required this.session});

  final SessionAdmin session;

  @override
  Widget build(BuildContext context) => PeopleModulePage(session: session, tab: AdminTab.residents);
}
