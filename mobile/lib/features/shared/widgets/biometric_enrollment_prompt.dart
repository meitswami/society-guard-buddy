import 'package:flutter/material.dart';

import '../../../models/session_models.dart';
import '../../../services/biometric_login_service.dart';
import '../../../services/biometric_service.dart';

/// One-time prompt after login to enable fingerprint quick-login (matches web onboarding).
class BiometricEnrollmentPrompt extends StatefulWidget {
  const BiometricEnrollmentPrompt({
    super.key,
    required this.session,
    required this.child,
  });

  final AppSessionState session;
  final Widget child;

  @override
  State<BiometricEnrollmentPrompt> createState() => _BiometricEnrollmentPromptState();
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

    final has = await login.hasEnrollment(role: user.role, userDbId: user.userDbId);
    if (has || !mounted) return;

    final enable = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.fingerprint),
            SizedBox(width: 8),
            Expanded(child: Text('Enable fingerprint login?')),
          ],
        ),
        content: const Text(
          'Use your device fingerprint or Face ID to sign in faster next time. '
          'You can also set this later under Profile or Settings.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enable')),
        ],
      ),
    );

    if (enable != true || !mounted) return;

    try {
      await login.enrollFromSession(widget.session);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fingerprint login enabled')),
      );
    } on BiometricLoginFailure catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
