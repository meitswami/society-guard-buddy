import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/ui/ui.dart';
import '../../../../services/biometric_login_service.dart';
import '../../../../services/biometric_service.dart';
import '../data/people_audit.dart';

/// Re-authentication before sensitive resident-directory changes — port of web
/// `SensitiveAdminVerifyModal.tsx` (password re-entry or device biometric if registered;
/// SMS OTP reserved). Every attempt is written to `audit_logs`.
abstract final class SensitiveVerify {
  /// Returns true once the admin is verified (web `runSensitive`).
  static Future<bool> confirm(
    BuildContext context, {
    required String societyId,
    required String adminId,
    required String adminName,
    required String title,
    required String actionLabel,
  }) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _VerifySheet(
        societyId: societyId,
        adminId: adminId,
        adminName: adminName,
        title: title,
        actionLabel: actionLabel,
      ),
    );
    return ok ?? false;
  }
}

class _VerifySheet extends StatefulWidget {
  const _VerifySheet({
    required this.societyId,
    required this.adminId,
    required this.adminName,
    required this.title,
    required this.actionLabel,
  });

  final String societyId;
  final String adminId;
  final String adminName;
  final String title;
  final String actionLabel;

  @override
  State<_VerifySheet> createState() => _VerifySheetState();
}

class _VerifySheetState extends State<_VerifySheet> {
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _audit(bool ok, String method) => PeopleAudit.log(
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
    final ok = await verifyAdminPassword(widget.adminId, _password.text);
    if (!mounted) return;
    setState(() => _busy = false);
    await _audit(ok, 'password');
    if (!mounted) return;
    if (!ok) {
      AppFeedback.toast(
          context, context.tr('Incorrect password', 'गलत पासवर्ड'),
          tone: BadgeTone.alert);
      return;
    }
    Navigator.pop(context, true);
  }

  Future<void> _withBiometric() async {
    setState(() => _busy = true);
    var ok = false;
    try {
      final enrolled = await BiometricLoginService()
          .hasEnrollment(role: 'admin', userDbId: widget.adminId);
      if (enrolled) {
        ok = await BiometricService()
            .authenticate(reason: widget.title, biometricOnly: false);
      }
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await _audit(ok, 'biometric');
    if (!mounted) return;
    if (!ok) {
      AppFeedback.toast(
          context,
          context.tr(
              'Biometric verification failed', 'बायोमेट्रिक सत्यापन विफल'),
          tone: BadgeTone.alert);
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final action = widget.actionLabel.replaceAll('_', ' ');
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Icon(Icons.lock_outline, size: 20, color: t.primary),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(widget.title,
                        style: AppText.sectionTitle(context))),
                IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.pop(context, false)),
              ]),
              Text(
                context.tr(
                  'Confirm your identity to $action. This is logged for security.',
                  '$action के लिए अपनी पहचान की पुष्टि करें। सुरक्षा हेतु यह दर्ज किया जाता है।',
                ),
                style: AppText.caption(context),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _password,
                hint: context.tr('Admin password', 'एडमिन पासवर्ड'),
                obscure: true,
                autofocus: true,
                onSubmitted: (_) => _busy ? null : _withPassword(),
              ),
              const SizedBox(height: 8),
              AppButton(
                label: context.tr(
                    'Continue with password', 'पासवर्ड से जारी रखें'),
                loading: _busy,
                onPressed: _withPassword,
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: AppButton.secondary(
                    label: context.tr('Biometric', 'बायोमेट्रिक'),
                    icon: Icons.fingerprint,
                    dense: true,
                    onPressed: _busy ? null : _withBiometric,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Opacity(
                    opacity: 0.8,
                    child: AppButton.secondary(
                      label: context.tr('SMS OTP', 'SMS OTP'),
                      icon: Icons.smartphone,
                      dense: true,
                      onPressed: () => AppFeedback.toast(
                        context,
                        context.tr(
                          'SMS OTP requires admin phone on file and SMS setup (not enabled in this build). Use password or biometric.',
                          'SMS OTP के लिए एडमिन फ़ोन और SMS सेटअप आवश्यक है (इस बिल्ड में सक्षम नहीं)। पासवर्ड या बायोमेट्रिक उपयोग करें।',
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Text(
                context.tr(
                  'Biometric only works if you registered it in Admin → Biometric.',
                  'बायोमेट्रिक तभी काम करेगा जब आपने इसे एडमिन → बायोमेट्रिक में पंजीकृत किया हो।',
                ),
                textAlign: TextAlign.center,
                style: AppText.tiny(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog that keeps a generated password on screen with a copy action.
Future<void> showPasswordDialog(BuildContext context,
    {required String title, required String password}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon:
          Icon(Icons.check_circle_rounded, color: ctx.tokens.success, size: 44),
      title: Text(title, textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(ctx.tr('New password:', 'नया पासवर्ड:'),
              style: AppText.caption(ctx)),
          const SizedBox(height: 6),
          SelectableText(password,
              style: AppText.mono(ctx, size: 18, weight: FontWeight.w600)),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.copy, size: 16),
          label: Text(ctx.tr('Copy', 'कॉपी')),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: password));
            if (ctx.mounted) {
              AppFeedback.toast(ctx, ctx.tr('Copied', 'कॉपी हुआ'));
            }
          },
        ),
        FilledButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
      ],
    ),
  );
}
