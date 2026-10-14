import 'package:flutter/material.dart';

import '../../core/ui/ui.dart';
import '../admin/core/admin_module.dart';
import 'widgets/admin_password_form.dart';

/// Admin → Password. Port of web `AdminPasswordChange` (stand-alone page).
class AdminPasswordModule extends StatelessWidget {
  const AdminPasswordModule({super.key, required this.ctx});

  final AdminModuleContext ctx;

  @override
  Widget build(BuildContext context) {
    return PageContainer(
      children: [
        PageHeader(
            title: context.t('admin.changePassword'),
            icon: Icons.lock_outline,
            subtitle: ctx.adminName),
        CardSection(
            child: AdminPasswordForm(
                adminId: ctx.adminId, societyId: ctx.societyId)),
      ],
    );
  }
}
