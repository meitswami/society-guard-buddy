import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../../../services/biometric_login_service.dart';
import '../../../services/biometric_service.dart';
import '../core/comms_i18n.dart';
import '../data/comms_audit.dart';
import '../data/settings_repository.dart';

/// Port of web `SensitiveAdminVerifyModal` (+ `adminVerify.ts`): re-authentication before
/// sensitive changes — admin password or device biometric (only when this admin enrolled
/// fingerprint login on this device); SMS OTP is a stub like on the web. Every attempt is
/// written to `audit_logs` (`sensitive_action_verified` / `sensitive_action_denied`).
///
/// `final ok = await SensitiveAdminVerifySheet.show(context, title: …, adminId: …, adminName: …, actionLabel: 'edit resident phone', societyId: …);`
class SensitiveAdminVerifySheet extends StatefulWidget {
  const SensitiveAdminVerifySheet({
    super.key,
    required this.title,
    required this.adminId,
    required this.adminName,
    required this.actionLabel,
    required this.societyId,
  });

  final String title;
  final String adminId;
  final String adminName;
  final String actionLabel;
  final String societyId;

  /// True when the admin verified successfully.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String adminId,
    required String adminName,
    required String actionLabel,
    required String societyId,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => SensitiveAdminVerifySheet(
        title: title,
        adminId: adminId,
        adminName: adminName,
        actionLabel: actionLabel,
        societyId: societyId,
      ),
    );
    return ok ?? false;
  }

  @override
  State<SensitiveAdminVerifySheet> createState() =>
      _SensitiveAdminVerifySheetState();
}

class _SensitiveAdminVerifySheetState extends State<SensitiveAdminVerifySheet> {
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _audit(bool ok, String method) => logCommsAuditEvent(
        societyId: widget.societyId,
        eventType: ok ? 'sensitive_action_verified' : 'sensitive_action_denied',
        userType: 'admin',
        userId: widget.adminId,
        userName: widget.adminName,
        details: {'action': widget.actionLabel, 'method': method},
        severity: ok ? 'info' : 'warning',
      );

  Future<void> _withPassword() async {
    setState(() => _busy = true);
    final ok = await const SettingsRepository()
        .verifyAdminPassword(widget.adminId, _password.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      AppFeedback.toast(context, context.ct('comms.verify.wrongPassword'),
          tone: BadgeTone.alert);
      await _audit(false, 'password');
      return;
    }
    await _audit(true, 'password');
    _password.clear();
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _withBiometric() async {
    setState(() => _busy = true);
    var ok = false;
    try {
      final enrolled = await BiometricLoginService()
          .hasEnrollment(role: 'admin', userDbId: widget.adminId);
      if (enrolled && mounted) {
        ok = await BiometricService().authenticate(
            reason: context.ct('comms.verify.reason'), biometricOnly: false);
      }
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      AppFeedback.toast(context, context.ct('comms.verify.bioFailed'),
          tone: BadgeTone.alert);
      await _audit(false, 'biometric');
      return;
    }
    await _audit(true, 'biometric');
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Dialog(
      backgroundColor: t.card,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radius),
          side: BorderSide(color: t.border)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.lock_outline, size: 20, color: t.primary),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(widget.title,
                        style: AppText.sectionTitle(context))),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close, size: 18, color: t.mutedForeground),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
                context.ct('comms.verify.text', {'action': widget.actionLabel}),
                style: AppText.caption(context)),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              autofocus: true,
              onSubmitted: (_) => _withPassword(),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                  hintText: context.ct('comms.verify.passwordPh')),
            ),
            const SizedBox(height: 8),
            AppButton(
                label: context.ct('comms.verify.withPassword'),
                loading: _busy,
                onPressed: _busy ? null : _withPassword),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppButton.secondary(
                    dense: true,
                    icon: Icons.fingerprint,
                    label: context.ct('comms.verify.biometric'),
                    onPressed: _busy ? null : _withBiometric,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Opacity(
                    opacity: 0.8,
                    child: AppButton.secondary(
                      dense: true,
                      icon: Icons.smartphone,
                      label: context.ct('comms.verify.sms'),
                      onPressed: () => AppFeedback.toast(
                          context, context.ct('comms.verify.smsStub')),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(context.ct('comms.verify.note'),
                textAlign: TextAlign.center, style: AppText.tiny(context)),
          ],
        ),
      ),
    );
  }
}
