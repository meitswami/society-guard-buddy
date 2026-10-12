import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../../../models/biometric_enrollment.dart';
import '../../../models/session_models.dart';
import '../../../services/biometric_login_service.dart';
import '../../../services/biometric_service.dart';
import '../../comms/core/comms_i18n.dart';
import '../../comms/widgets/comms_ui.dart';

/// Native counterpart of web `BiometricSetup` (WebAuthn on the web; `local_auth` + secure
/// storage here): fingerprint quick-login enrollments (max 3, oldest replaced) plus the
/// device app-lock switch. Renders nothing when the device has no biometrics.
///
/// The widget has no outer card — place it inside a `CardSection` / `Card`.
class BiometricSettingsTile extends StatefulWidget {
  const BiometricSettingsTile(
      {super.key,
      this.session,
      this.quickLoginEnabled = true,
      this.showAppLock = true});

  final AppSessionState? session;
  final bool quickLoginEnabled;
  final bool showAppLock;

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
  bool _allowed = true;
  String? _removingId;
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
    final supported = await _device.isDeviceSupported();
    final appLock = supported ? await _device.isEnabled() : false;
    var allowed = true;
    List<BiometricEnrollment> enrollments = const [];
    final session = widget.session;
    if (supported && session != null && widget.quickLoginEnabled) {
      final user = await _login.userContextFromSession(session);
      allowed = user?.allowed ?? false;
      if (user != null && user.allowed) {
        final all = await _login.listEnrollments();
        enrollments = all
            .where((e) => e.role == user.role && e.userDbId == user.userDbId)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      }
    }
    if (!mounted) return;
    setState(() {
      _supported = supported;
      _appLock = appLock;
      _allowed = allowed;
      _userEnrollments = enrollments;
      _loading = false;
    });
  }

  Future<void> _toggleAppLock(bool value) async {
    if (value) {
      final ok = await _device.authenticate(
          reason: context.ct('comms.bio.confirmLock'), biometricOnly: false);
      if (!ok) return;
    }
    await _device.setEnabled(value);
    if (mounted) setState(() => _appLock = value);
  }

  Future<void> _register() async {
    final session = widget.session;
    if (session == null) return;
    setState(() => _enrolling = true);
    try {
      await _login.enrollFromSession(session);
      if (!mounted) return;
      await _load();
      if (mounted)
        AppFeedback.toast(context, context.t('biometric.registered'),
            tone: BadgeTone.success);
    } on BiometricLoginFailure catch (e) {
      if (mounted)
        AppFeedback.toast(
            context, '${context.t('biometric.registerFailed')}: ${e.message}',
            tone: BadgeTone.alert);
    } catch (_) {
      if (mounted)
        AppFeedback.toast(context, context.t('biometric.registerFailed'),
            tone: BadgeTone.alert);
    } finally {
      if (mounted) setState(() => _enrolling = false);
    }
  }

  Future<void> _remove(BiometricEnrollment e) async {
    setState(() => _removingId = e.id);
    try {
      await _login.removeEnrollment(e.id);
      if (!mounted) return;
      await _load();
      if (mounted)
        AppFeedback.toast(context, context.ct('comms.bio.removed'),
            tone: BadgeTone.success);
    } catch (_) {
      if (mounted)
        AppFeedback.toast(context, context.ct('comms.bio.removeFailed'),
            tone: BadgeTone.alert);
    } finally {
      if (mounted) setState(() => _removingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _supported != true) return const SizedBox.shrink();
    final t = context.tokens;
    const max = BiometricLoginService.maxEnrollmentsPerUser;
    final count = _userEnrollments.length;
    final registered = count > 0;
    final showQuickLogin = widget.session != null && widget.quickLoginEnabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showQuickLogin) ...[
          Row(
            children: [
              Icon(Icons.fingerprint, size: 20, color: t.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.t('biometric.title'),
                        style: AppText.bodyMedium(context)),
                    Text(
                        '${context.t('biometric.subtitle')} ${context.ct('comms.bio.devices', {
                              'count': count,
                              'max': max
                            })}',
                        style: AppText.caption(context)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!_allowed)
            NoticeBanner(
                message: context.ct('comms.bio.notAllowed'),
                tone: BadgeTone.warning,
                icon: Icons.info_outline)
          else if (registered) ...[
            Row(
              children: [
                Icon(Icons.check, size: 16, color: t.success),
                const SizedBox(width: 6),
                Text(context.t('biometric.enabled'),
                    style: TextStyle(fontSize: 14, color: t.success)),
              ],
            ),
            const SizedBox(height: 8),
            AppButton.secondary(
              loading: _enrolling,
              label: _enrolling
                  ? context.t('biometric.registering')
                  : context
                      .ct('comms.bio.addAnother', {'count': count, 'max': max}),
              onPressed: _enrolling ? null : _register,
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                  border: Border.all(color: t.border),
                  borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
              child: Column(
                children: [
                  for (var i = 0; i < _userEnrollments.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: t.border),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.ct('comms.bio.device', {
                                    'n': i + 1,
                                    'id': _userEnrollments[i].id.length > 8
                                        ? _userEnrollments[i].id.substring(0, 8)
                                        : _userEnrollments[i].id,
                                  }),
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500),
                                ),
                                Text(
                                    context.ct('comms.bio.added', {
                                      'date': Fmt.dateTimeFull(
                                          _userEnrollments[i].createdAt)
                                    }),
                                    style: AppText.tiny(context)),
                              ],
                            ),
                          ),
                          LinkText(
                            _removingId == _userEnrollments[i].id
                                ? context.ct('comms.bio.removing')
                                : context.ct('comms.bio.remove'),
                            color: t.destructive,
                            onTap: _removingId == null
                                ? () => _remove(_userEnrollments[i])
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (count >= max) ...[
              const SizedBox(height: 6),
              Text(context.ct('comms.bio.maxReached', {'max': max}),
                  style: AppText.caption(context).copyWith(fontSize: 11)),
            ],
          ] else
            AppButton(
              loading: _enrolling,
              label: _enrolling
                  ? context.t('biometric.registering')
                  : context.t('biometric.enable'),
              onPressed: _enrolling ? null : _register,
            ),
        ],
        if (widget.showAppLock) ...[
          if (showQuickLogin) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: t.border),
            const SizedBox(height: 8)
          ],
          Row(
            children: [
              Icon(Icons.lock_outline, size: 18, color: t.mutedForeground),
              const SizedBox(width: 12),
              Expanded(
                child: ToggleRow(
                  label: context.ct('comms.bio.appLock'),
                  subtitle: context.ct('comms.bio.appLockHint'),
                  value: _appLock,
                  onChanged: _toggleAppLock,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
