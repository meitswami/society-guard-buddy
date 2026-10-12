import 'package:flutter/material.dart';

import '../../shared/directory/directory_view.dart';
import '../core/admin_module.dart';

/// Admin → Directory — web `DirectoryPage` mounted in `AdminDashboard` with
/// `canEditResidents={admin.permissions.residents_rw}`; Edit opens Residents with that
/// flat expanded (`subTab: 'flat:<id>'`).
class AdminDirectoryModule extends StatelessWidget {
  const AdminDirectoryModule({super.key, required this.ctx});

  final AdminModuleContext ctx;

  @override
  Widget build(BuildContext context) {
    final canEdit = ctx.session.admin.permissions.residentsRw;
    return DirectoryView(
      societyId: ctx.societyId,
      viewerRole: 'admin',
      viewerName: ctx.adminName,
      initialQuery: ctx.initialQuery,
      canEditResidents: canEdit,
      onEditFlat: canEdit ? (flatId) => ctx.goTo(AdminTab.residents, subTab: 'flat:$flatId') : null,
    );
  }
}
