import 'package:flutter/material.dart';

import '../../core/ui/ui.dart';
import '../admin/core/admin_module.dart';
import '../shared/widgets/biometric_settings_tile.dart';
import 'settings/app_features_panel.dart';
import 'settings/appearance_card.dart';
import 'settings/bank_account_panel.dart';
import 'settings/banners_panel.dart';
import 'settings/data_summary_card.dart';
import 'settings/report_settings_panel.dart';
import 'settings/society_address_panel.dart';
import 'settings/society_content_editor.dart';
import 'widgets/admin_password_form.dart';

/// Admin → Settings. Port of web `SettingsPage allowContentEdit adminId adminName`:
/// appearance, account security (password + biometric), app features, member content
/// editor, society address, report settings, bank account, data summary, login banners.
class AdminSettingsModule extends StatefulWidget {
  const AdminSettingsModule({super.key, required this.ctx});

  final AdminModuleContext ctx;

  @override
  State<AdminSettingsModule> createState() => _AdminSettingsModuleState();
}

class _AdminSettingsModuleState extends State<AdminSettingsModule> {
  int _gen = 0;

  @override
  Widget build(BuildContext context) {
    final sid = widget.ctx.societyId;
    Key k(String name) => ValueKey('$name-$_gen');
    return PageContainer(
      onRefresh: () async => setState(() => _gen++),
      children: [
        PageHeader(title: context.t('settings.title'), subtitle: context.t('settings.subtitle'), icon: Icons.settings_outlined),
        const AppearanceCard(),
        CardSection(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(context.t('settings.account'), icon: Icons.lock_outline, padding: const EdgeInsets.only(bottom: 12)),
              AdminPasswordForm(key: k('pw'), adminId: widget.ctx.adminId, societyId: sid),
              if (widget.ctx.adminName.isNotEmpty) ...[
                const SizedBox(height: 16),
                BiometricSettingsTile(key: k('bio'), session: widget.ctx.session),
              ],
            ],
          ),
        ),
        AppFeaturesPanel(key: k('features'), societyId: sid),
        SocietyContentEditor(key: k('content'), societyId: sid),
        SocietyAddressPanel(key: k('address'), societyId: sid),
        ReportSettingsPanel(key: k('report'), societyId: sid),
        BankAccountPanel(key: k('bank'), societyId: sid),
        DataSummaryCard(key: k('summary'), societyId: sid),
        BannersPanel(key: k('banners'), societyId: sid),
        const SizedBox(height: 8),
        Text(context.t('app.footer'), textAlign: TextAlign.center, style: AppText.tiny(context)),
      ],
    );
  }
}
