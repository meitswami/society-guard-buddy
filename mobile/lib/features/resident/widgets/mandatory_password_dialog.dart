import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../../../models/session_models.dart';
import '../../../services/biometric_login_service.dart';
import '../../../services/biometric_service.dart';
import '../data/resident_repository.dart';

/// Web mandatory flat-password overlay (`must_change_password`), followed by the
/// fingerprint-login offer (`resident.mandatoryBioTitle`). Not dismissible.
Future<void> showMandatoryPasswordDialog(BuildContext context, SessionResident session) async {
  final saved = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: AppTokens.tint(context.tokens.background, 0.95),
    pageBuilder: (ctx, _, __) => PopScope(canPop: false, child: _MandatoryPasswordForm(session: session)),
  );
  if (saved != true || !context.mounted) return;
  try {
    if (!await BiometricService().isDeviceSupported()) return;
  } catch (_) {
    return;
  }
  if (!context.mounted) return;
  final enroll = await AppFeedback.confirm(
    context,
    title: context.t('resident.mandatoryBioTitle'),
    message: context.t('resident.mandatoryBioBody'),
    confirmLabel: context.t('swal.yes'),
    cancelLabel: context.t('swal.no'),
  );
  if (!enroll || !context.mounted) return;
  try {
    await BiometricLoginService().enrollFromSession(session);
    if (context.mounted) AppFeedback.toast(context, context.t('biometric.registered'), tone: BadgeTone.success);
  } catch (_) {
    if (context.mounted) AppFeedback.toast(context, context.t('biometric.registerFailed'), tone: BadgeTone.alert);
  }
}

class _MandatoryPasswordForm extends StatefulWidget {
  const _MandatoryPasswordForm({required this.session});

  final SessionResident session;

  @override
  State<_MandatoryPasswordForm> createState() => _MandatoryPasswordFormState();
}

class _MandatoryPasswordFormState extends State<_MandatoryPasswordForm> {
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // Inline: a toast would sit behind the opaque barrier.
    void err(String m) => setState(() => _error = m);
    if (_new.text.isEmpty || _confirm.text.isEmpty) {
      return err(context.tr('Enter new password and confirmation', 'नया कूटशब्द और पुष्टि दर्ज करें'));
    }
    if (_new.text != _confirm.text) return err(context.tr('Passwords do not match', 'कूटशब्द मेल नहीं खाते'));
    if (_new.text.length < 4) return err(context.tr('Password must be at least 4 characters', 'कूटशब्द कम से कम 4 अक्षर का होना चाहिए'));
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await const ResidentRepository().setFlatPassword(flatId: widget.session.resident.flatId, password: _new.text);
      if (!mounted) return;
      AppFeedback.toast(context, context.tr('Password set for all flatmates', 'सभी फ्लैट सदस्यों के लिए कूटशब्द सेट हुआ'), tone: BadgeTone.success);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 384),
            child: CardSection(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                Text(context.t('resident.mandatoryPasswordTitle'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(context.t('resident.mandatoryPasswordSubtitle'), style: AppText.caption(context)),
                const SizedBox(height: 8),
                Text(context.t('resident.mandatoryPasswordNoCurrent'), style: AppText.tiny(context).copyWith(fontSize: 11)),
                const SizedBox(height: 4),
                Text(context.t('resident.mandatoryPasswordBioHint'), style: AppText.tiny(context).copyWith(fontSize: 11)),
                const SizedBox(height: 16),
                AppTextField(controller: _new, label: context.t('resident.mandatoryPasswordNew'), obscure: true),
                const SizedBox(height: 12),
                AppTextField(controller: _confirm, label: context.t('resident.mandatoryPasswordConfirm'), obscure: true, onSubmitted: (_) => _save()),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(fontSize: 12, color: context.tokens.destructive)),
                ],
                const SizedBox(height: 16),
                AppButton(
                  label: _saving ? context.tr('Saving…', 'सहेज रहे हैं…') : context.t('resident.mandatoryPasswordSave'),
                  loading: _saving,
                  onPressed: _save,
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
