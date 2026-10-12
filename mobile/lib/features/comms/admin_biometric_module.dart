import 'package:flutter/material.dart';

import '../../core/ui/ui.dart';
import '../../services/biometric_service.dart';
import '../admin/core/admin_module.dart';
import '../shared/widgets/biometric_settings_tile.dart';
import 'core/comms_i18n.dart';

/// Admin → Biometric. Web renders `BiometricSetup userType="admin"`; mobile uses the native
/// biometric quick-login enrollments + device app lock.
class AdminBiometricModule extends StatefulWidget {
  const AdminBiometricModule({super.key, required this.ctx});

  final AdminModuleContext ctx;

  @override
  State<AdminBiometricModule> createState() => _AdminBiometricModuleState();
}

class _AdminBiometricModuleState extends State<AdminBiometricModule> {
  bool? _supported;

  @override
  void initState() {
    super.initState();
    BiometricService().isDeviceSupported().then((v) {
      if (mounted) setState(() => _supported = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PageContainer(
      children: [
        PageHeader(title: context.t('biometric.title'), subtitle: context.t('biometric.subtitle'), icon: Icons.fingerprint),
        if (_supported == null)
          const LoadingView()
        else if (_supported == false)
          NoticeBanner(message: context.ct('comms.bio.unavailable'), tone: BadgeTone.warning, icon: Icons.fingerprint)
        else
          CardSection(child: BiometricSettingsTile(session: widget.ctx.session)),
      ],
    );
  }
}
