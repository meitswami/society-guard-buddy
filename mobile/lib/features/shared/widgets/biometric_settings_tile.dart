import 'package:flutter/material.dart';

import '../../../core/theme/kutumbika_colors.dart';
import '../../../models/biometric_enrollment.dart';
import '../../../models/session_models.dart';
import '../../../services/biometric_login_service.dart';
import '../../../services/biometric_service.dart';

/// App lock + fingerprint quick-login setup (native: local_auth + secure storage).
class BiometricSettingsTile extends StatefulWidget {
  const BiometricSettingsTile({
    super.key,
    this.session,
    this.quickLoginEnabled = true,
  });

  final AppSessionState? session;
  final bool quickLoginEnabled;

  @override
  State<BiometricSettingsTile> createState() => _BiometricSettingsTileState();
}

class _BiometricSettingsTileState extends State<BiometricSettingsTile> {
  final _device = BiometricService();
  final _login = BiometricLoginService();

  bool? _supported;
  bool _appLock = false;
  bool _loading = true;
  bool _enrolling = false;
  List<BiometricEnrollment> _userEnrollments = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(BiometricSettingsTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final supported = await _device.isDeviceSupported();
    final appLock = supported ? await _device.isEnabled() : false;

    List<BiometricEnrollment> enrollments = const [];
    final user = widget.session == null
        ? null
        : await _login.userContextFromSession(widget.session!);
    if (supported && user != null && user.allowed && widget.quickLoginEnabled) {
      final all = await _login.listEnrollments();
      enrollments =
          all.where((e) => e.role == user.role && e.userDbId == user.userDbId).toList();
    }

    if (!mounted) return;
    setState(() {
      _supported = supported;
      _appLock = appLock;
      _userEnrollments = enrollments;
      _loading = false;
    });
  }

  Future<void> _toggleAppLock(bool value) async {
    if (value) {
      final ok = await _device.authenticate(
        reason: 'Confirm to enable biometric unlock',
        biometricOnly: false,
      );
      if (!ok) return;
    }
    await _device.setEnabled(value);
    if (!mounted) return;
    setState(() => _appLock = value);
  }

  Future<void> _enrollQuickLogin() async {
    final session = widget.session;
    if (session == null) return;

    setState(() => _enrolling = true);
    try {
      await _login.enrollFromSession(session);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fingerprint login enabled')),
      );
      await _load();
    } on BiometricLoginFailure catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _enrolling = false);
    }
  }

  Future<void> _removeEnrollment(BiometricEnrollment e) async {
    await _login.removeEnrollment(e.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Device removed')),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    if (_supported != true) return const SizedBox.shrink();

    final showQuickLogin =
        widget.session != null && widget.quickLoginEnabled;
    final enrolled = _userEnrollments.isNotEmpty;

    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.lock_outline),
          title: const Text('Biometric app lock'),
          subtitle: const Text('Require fingerprint or Face ID when opening the app'),
          value: _appLock,
          onChanged: _toggleAppLock,
        ),
        if (showQuickLogin) ...[
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.fingerprint),
            title: const Text('Fingerprint login'),
            subtitle: Text(
              enrolled
                  ? '${_userEnrollments.length}/${BiometricLoginService.maxEnrollmentsPerUser} devices enrolled'
                  : 'Sign in faster from the login screen',
              style: const TextStyle(fontSize: 12, color: KutumbikaColors.textMuted),
            ),
            trailing: _enrolling
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : FilledButton(
                    onPressed: _enrolling ? null : _enrollQuickLogin,
                    child: Text(enrolled ? 'Add device' : 'Enable'),
                  ),
          ),
          if (_userEnrollments.isNotEmpty)
            ..._userEnrollments.map(
              (e) => ListTile(
                dense: true,
                title: Text(e.displayName),
                subtitle: Text(
                  'Enrolled ${e.createdAt.toLocal().toString().substring(0, 16)}',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => _removeEnrollment(e),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
