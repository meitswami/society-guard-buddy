import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../../../models/biometric_enrollment.dart';
import '../../../models/session_models.dart';
import '../../../services/biometric_login_service.dart';
import '../../../services/biometric_service.dart';
import '../gate_i18n.dart';

/// Web `BiometricSetup` card (guard home): enable fingerprint quick-login, list / remove the
/// enrolled devices (max 3; adding another replaces the oldest). Hidden when the device has
/// no biometrics. Native enrollments live in secure storage (`BiometricLoginService`).
class BiometricSetupCard extends StatefulWidget {
  const BiometricSetupCard({super.key, required this.session, required this.role, required this.userDbId});

  final AppSessionState session;

  /// `guard` | `resident` | `admin`
  final String role;

  /// `guards.id` / `resident_users.id` / `admins.id`.
  final String userDbId;

  @override
  State<BiometricSetupCard> createState() => _BiometricSetupCardState();
}

class _BiometricSetupCardState extends State<BiometricSetupCard> {
  final _device = BiometricService();
  final _login = BiometricLoginService();

  bool _available = false;
  bool _registering = false;
  String? _removingId;
  List<BiometricEnrollment> _mine = const [];

  int get _max => BiometricLoginService.maxEnrollmentsPerUser;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final available = await _device.isDeviceSupported();
    var mine = const <BiometricEnrollment>[];
    if (available) {
      try {
        final all = await _login.listEnrollments();
        mine = all.where((e) => e.role == widget.role && e.userDbId == widget.userDbId).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _available = available;
      _mine = mine;
    });
  }

  Future<void> _register() async {
    setState(() => _registering = true);
    try {
      await _login.enrollFromSession(widget.session);
      await _refresh();
      if (mounted) AppFeedback.toast(context, context.t('biometric.registered'), tone: BadgeTone.success);
    } catch (_) {
      if (mounted) AppFeedback.toast(context, context.t('biometric.registerFailed'), tone: BadgeTone.alert);
    } finally {
      if (mounted) setState(() => _registering = false);
    }
  }

  Future<void> _remove(BiometricEnrollment e) async {
    setState(() => _removingId = e.id);
    try {
      await _login.removeEnrollment(e.id);
      await _refresh();
      if (mounted) AppFeedback.toast(context, context.gt('gate.bio.removed'), tone: BadgeTone.success);
    } catch (_) {
      if (mounted) AppFeedback.toast(context, context.gt('gate.bio.removeFailed'), tone: BadgeTone.alert);
    } finally {
      if (mounted) setState(() => _removingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) return const SizedBox.shrink();
    final t = context.tokens;
    final count = _mine.length;
    final registered = count > 0;
    return CardSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.fingerprint, size: 20, color: t.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.t('biometric.title'), style: AppText.bodyMedium(context)),
                    Text(
                      '${context.t('biometric.subtitle')} ${context.gt('gate.bio.devices', {'count': count, 'max': _max})}',
                      style: AppText.caption(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!registered)
            AppButton(
              label: _registering ? context.t('biometric.registering') : context.t('biometric.enable'),
              loading: _registering,
              onPressed: _register,
            )
          else ...[
            Row(
              children: [
                Icon(Icons.check, size: 16, color: t.success),
                const SizedBox(width: 8),
                Expanded(child: Text(context.t('biometric.enabled'), style: TextStyle(fontSize: 14, color: t.success))),
              ],
            ),
            const SizedBox(height: 8),
            AppButton.secondary(
              label: _registering
                  ? context.t('biometric.registering')
                  : context.gt('gate.bio.addAnother', {'count': count, 'max': _max}),
              loading: _registering,
              onPressed: _register,
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: t.border),
                borderRadius: BorderRadius.circular(AppTokens.radiusSm),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < _mine.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: t.border),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.gt('gate.bio.device', {
                                    'n': i + 1,
                                    'id': _mine[i].id.length > 8 ? _mine[i].id.substring(0, 8) : _mine[i].id,
                                  }),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  context.gt('gate.bio.added', {'date': Fmt.dateTimeFull(_mine[i].createdAt)}),
                                  style: AppText.tiny(context),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: _removingId == _mine[i].id ? null : () => _remove(_mine[i]),
                            child: Text(
                              _removingId == _mine[i].id ? context.gt('gate.bio.removing') : context.gt('gate.bio.remove'),
                              style: TextStyle(
                                fontSize: 12,
                                color: t.destructive,
                                decoration: TextDecoration.underline,
                                decorationColor: t.destructive,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (count >= _max) ...[
              const SizedBox(height: 8),
              Text(context.gt('gate.bio.maxReached', {'max': _max}), style: AppText.tiny(context).copyWith(fontSize: 11)),
            ],
          ],
        ],
      ),
    );
  }
}
