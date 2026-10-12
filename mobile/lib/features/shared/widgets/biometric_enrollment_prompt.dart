import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../../../models/session_models.dart';
import '../../../services/biometric_login_service.dart';
import '../../../services/biometric_service.dart';
import '../../comms/core/comms_i18n.dart';

/// One-time prompt after login to enable fingerprint quick-login (web onboarding nudge).
class BiometricEnrollmentPrompt extends StatefulWidget {
  const BiometricEnrollmentPrompt(
      {super.key, required this.session, required this.child});

  final AppSessionState session;
  final Widget child;

  @override
  State<BiometricEnrollmentPrompt> createState() =>
      _BiometricEnrollmentPromptState();
}

class _BiometricEnrollmentPromptState extends State<BiometricEnrollmentPrompt> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePrompt());
  }

  Future<void> _maybePrompt() async {
    if (_checked) return;
    _checked = true;
    if (!await BiometricService().isDeviceSupported()) return;

    final login = BiometricLoginService();
    final user = await login.userContextFromSession(widget.session);
    if (user == null || !user.allowed) return;
    final has =
        await login.hasEnrollment(role: user.role, userDbId: user.userDbId);
    if (has || !mounted) return;

    final t = context.tokens;
    final enable = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.fingerprint, size: 40, color: t.primary),
        title:
            Text(ctx.ct('comms.bio.promptTitle'), textAlign: TextAlign.center),
        content:
            Text(ctx.ct('comms.bio.promptText'), textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.ct('comms.bio.notNow'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.ct('comms.bio.enableShort'))),
        ],
      ),
    );
    if (enable != true || !mounted) return;

    try {
      await login.enrollFromSession(widget.session);
      if (mounted)
        AppFeedback.toast(context, context.t('biometric.registered'),
            tone: BadgeTone.success);
    } on BiometricLoginFailure catch (e) {
      if (mounted)
        AppFeedback.toast(
            context, '${context.t('biometric.registerFailed')}: ${e.message}',
            tone: BadgeTone.alert);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
