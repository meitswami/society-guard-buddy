import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../core/comms_i18n.dart';
import '../data/comms_audit.dart';
import '../data/notification_media_storage.dart';
import '../data/settings_repository.dart';

/// Port of web `AdminPasswordChange` form (current / new / confirm, show toggle,
/// min 4 characters, current password verified against `admins`, audit `password_change`).
class AdminPasswordForm extends StatefulWidget {
  const AdminPasswordForm(
      {super.key, required this.adminId, required this.societyId});

  final String adminId;
  final String societyId;

  @override
  State<AdminPasswordForm> createState() => _AdminPasswordFormState();
}

class _AdminPasswordFormState extends State<AdminPasswordForm> {
  final _repo = const SettingsRepository();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _show = false;
  bool _loading = false;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _change() async {
    final current = _current.text;
    final next = _new.text;
    final confirm = _confirm.text;
    if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
      AppFeedback.toast(context, context.t('admin.fillAllFields'),
          tone: BadgeTone.alert);
      return;
    }
    if (next != confirm) {
      AppFeedback.toast(context, context.t('admin.passwordMismatch'),
          tone: BadgeTone.alert);
      return;
    }
    if (next.length < 4) {
      AppFeedback.toast(context, context.t('admin.passwordTooShort'),
          tone: BadgeTone.alert);
      return;
    }
    setState(() => _loading = true);
    try {
      final ok = await _repo.currentPasswordMatches(widget.adminId, current);
      if (!mounted) return;
      if (!ok) {
        AppFeedback.toast(context, context.t('admin.currentPasswordWrong'),
            tone: BadgeTone.alert);
        return;
      }
      await _repo.setAdminPassword(widget.adminId, next);
      // Web: auditPasswordChange('admin', adminId, 'admin').
      await auditPasswordChange(
          societyId: widget.societyId,
          userType: 'admin',
          userId: widget.adminId,
          userName: 'admin');
      if (!mounted) return;
      AppFeedback.toast(context, context.t('admin.passwordChanged'),
          tone: BadgeTone.success);
      _current.clear();
      _new.clear();
      _confirm.clear();
    } catch (e) {
      if (mounted) {
        AppFeedback.toast(context, commsErrorMessage(e), tone: BadgeTone.alert);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _current,
          obscureText: !_show,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: context.t('admin.currentPassword'),
            suffixIcon: IconButton(
              tooltip: context
                  .ct(_show ? 'comms.password.hide' : 'comms.password.show'),
              icon: Icon(
                  _show
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                  color: t.mutedForeground),
              onPressed: () => setState(() => _show = !_show),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _new,
          obscureText: !_show,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(hintText: context.t('admin.newPassword')),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirm,
          obscureText: !_show,
          style: const TextStyle(fontSize: 14),
          onSubmitted: (_) => _change(),
          decoration:
              InputDecoration(hintText: context.t('admin.confirmPassword')),
        ),
        const SizedBox(height: 12),
        AppButton(
          loading: _loading,
          label: _loading
              ? context.t('login.loggingIn')
              : context.t('admin.changePassword'),
          onPressed: _loading ? null : _change,
        ),
      ],
    );
  }
}
