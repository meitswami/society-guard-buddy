import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui/ui.dart';
import '../../models/session_models.dart';
import '../../providers/session_provider.dart';
import '../shared/widgets/biometric_settings_tile.dart';
import 'core/comms_i18n.dart';
import 'settings/appearance_card.dart';
import 'settings/data_summary_card.dart';

/// Guard → Settings. Port of web `SettingsPage` without admin config (appearance + data
/// summary), plus the native biometric quick-login / app lock and "End shift".
class GuardSettingsView extends ConsumerStatefulWidget {
  const GuardSettingsView({super.key, required this.session});

  final SessionGuard session;

  @override
  ConsumerState<GuardSettingsView> createState() => _GuardSettingsViewState();
}

class _GuardSettingsViewState extends ConsumerState<GuardSettingsView> {
  int _gen = 0;
  bool _ending = false;

  Future<void> _endShift() async {
    final ok = await AppFeedback.confirm(
      context,
      title: context.t('swal.confirmLogoutGuard'),
      message: context.t('swal.confirmLogoutGuardText'),
      confirmLabel: context.t('swal.yes'),
      cancelLabel: context.t('swal.no'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _ending = true);
    try {
      await ref
          .read(sessionProvider.notifier)
          .logout(guardShiftId: widget.session.shiftId);
    } finally {
      if (mounted) setState(() => _ending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    return PageContainer(
      onRefresh: () async => setState(() => _gen++),
      children: [
        PageHeader(
            title: context.t('settings.title'),
            subtitle: context.t('settings.subtitle'),
            icon: Icons.settings_outlined),
        const AppearanceCard(),
        CardSection(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(context.ct('comms.settings.security'),
                  icon: Icons.fingerprint,
                  padding: const EdgeInsets.only(bottom: 4)),
              Text(
                  context
                      .ct('comms.settings.signedInAs', {'name': s.guard.name}),
                  style: AppText.caption(context)),
              Text(
                  context.ct(
                      'comms.settings.guardRole', {'society': s.societyName}),
                  style: AppText.tiny(context)),
              const SizedBox(height: 12),
              BiometricSettingsTile(key: ValueKey('bio-$_gen'), session: s),
            ],
          ),
        ),
        DataSummaryCard(key: ValueKey('summary-$_gen'), societyId: s.societyId),
        AppButton.destructive(
          icon: Icons.logout,
          loading: _ending,
          label: context.t('swal.confirmLogoutGuard'),
          onPressed: _ending ? null : _endShift,
        ),
        const SizedBox(height: 24),
        Text(context.t('app.footer'),
            textAlign: TextAlign.center, style: AppText.tiny(context)),
      ],
    );
  }
}
