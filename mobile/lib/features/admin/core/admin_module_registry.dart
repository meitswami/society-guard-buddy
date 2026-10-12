import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import 'admin_module.dart';

/// Maps each admin tab to its module screen. Filled in as parity modules land.
Widget buildAdminModule(AdminTab tab, AdminModuleContext ctx) {
  switch (tab) {
    default:
      return _PendingModule(tab: tab);
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
