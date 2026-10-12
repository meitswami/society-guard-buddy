import 'package:flutter/material.dart';

import '../admin/core/admin_module.dart';
import 'documents/documents_page.dart';

/// Admin "Documents" module (web `SocietyDocumentsManager adminName={admin.name}`).
class AdminDocumentsModule extends StatelessWidget {
  const AdminDocumentsModule({super.key, required this.ctx});

  final AdminModuleContext ctx;

  @override
  Widget build(BuildContext context) => DocumentsPage(
      societyId: ctx.societyId, isResident: false, adminName: ctx.adminName);
}
