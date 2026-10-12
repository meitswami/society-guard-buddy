import 'package:flutter/material.dart';

import '../../models/session_models.dart';
import 'core/admin_module.dart';
import 'people/people_legacy_host.dart';

/// Legacy entry point — opens Residents with this flat expanded.
class AdminFlatDetailScreen extends StatelessWidget {
  const AdminFlatDetailScreen({super.key, required this.session, required this.flatId, required this.flatNumber});

  final SessionAdmin session;
  final String flatId;
  final String flatNumber;

  @override
  Widget build(BuildContext context) =>
      PeopleModulePage(session: session, tab: AdminTab.residents, query: flatNumber, subTab: 'flat:$flatId');
}
