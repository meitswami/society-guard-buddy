import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/ui/ui.dart';
import '../../models/session_models.dart';
import '../../providers/session_provider.dart';
import 'data/superadmin_audit.dart';
import 'data/superadmin_biometric.dart';
import 'data/superadmin_models.dart';
import 'data/superadmin_repository.dart';
import 'logic/js_compat.dart';
import 'logic/totp.dart';
import 'superadmin_i18n.dart';
import 'widgets/sa_widgets.dart';
import 'widgets/totp_qr.dart';

enum _Step { password, totp, setupQr, setupTotpVerify, setupRecovery, recoveryRequest, recoveryVerify }

/// Superadmin sign-in — port of `SuperadminLoginForm.tsx` (+ the `SuperadminLoginPage`
/// wrapper): username / password, optional fingerprint, Microsoft Authenticator (TOTP)
/// verification and first-time enrollment (QR → code → recovery e-mail), and the
/// lock-out recovery via the `superadmin-recovery-send` / `-verify` edge functions.
///
/// On success it persists the session (`sessionProvider.notifier.loginSuperadmin`, web
/// `writePersistedSession`) and then calls [onLoggedIn].
///
/// Layout: inside a scroll view (unbounded height) it renders the compact "embedded"
/// variant (web `variant="embedded"` in the unified login); given a bounded page it renders
/// the full page (crown header, language / theme toggles) like `SuperadminLoginPage`.
class SuperadminLoginView extends ConsumerStatefulWidget {
  const SuperadminLoginView({super.key, required this.onLoggedIn, this.onBack});

  final void Function(SessionSuperadmin) onLoggedIn;
  final VoidCallback? onBack;

  @override
  ConsumerState<SuperadminLoginView> createState() => _SuperadminLoginViewState();
}

class _SuperadminLoginViewState extends ConsumerState<SuperadminLoginView> {
  final _repo = const SuperadminRepository();
  final _bio = SuperadminBiometric();

  final _username = TextEditingController();
  final _password = TextEditingController();
  final _totpCode = TextEditingController();
  final _recoveryEmailInput = TextEditingController();
  final _recoveryUsername = TextEditingController();
  final _recoveryEmailRequest = TextEditingController();
  final _recoveryCode = TextEditingController();

  _Step _step = _Step.password;
  String _recoveryInfo = '';
  bool _showPassword = false;
  String _error = '';
  bool _loading = false;
  bool _bioLoading = false;
  bool _bioAvailable = false;
  bool _finishing = false;
  SuperAdminRow? _pending;
  String? _setupSecret;
  bool _cameFromBiometric = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final ok = await _bio.isAvailable() && await _bio.hasLocalCredential();
    if (mounted) setState(() => _bioAvailable = ok);
  }

  @override
  void dispose() {
    for (final c in [
      _username,
      _password,
      _totpCode,
      _recoveryEmailInput,
      _recoveryUsername,
      _recoveryEmailRequest,
      _recoveryCode,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _setError(String key) => setState(() => _error = context.t(key));

  // ---------------------------------------------------------------------------
  // Flow (same order and messages as the web form)

  Future<void> _finishLogin({required String id, required String name, required String username, required String method}) async {
    if (_finishing) return;
    _finishing = true;
    SuperadminAudit.loginSuccess(id, name, method);
    final session = SessionSuperadmin(id: id, name: name, username: username);
    final onLoggedIn = widget.onLoggedIn;
    try {
      await ref.read(sessionProvider.notifier).loginSuperadmin(id: id, name: name, username: username);
    } catch (_) {
      // The host still receives the session through [onLoggedIn].
    }
    onLoggedIn(session);
    _finishing = false;
  }

  void _afterPasswordOk(SuperAdminRow row, bool fromBio) {
    setState(() {
      _pending = row;
      _cameFromBiometric = fromBio;
      _totpCode.clear();
      _error = '';
    });
    if (row.totpEnabled && !row.hasTotpSecret) {
      setState(() {
        _setupSecret = generateTotpSecret();
        _recoveryEmailInput.text = row.recoveryEmail?.trim() ?? '';
        _step = _Step.setupQr;
      });
      return;
    }
    if (!row.totpEnabled) {
      _finishLogin(id: row.id, name: row.name, username: row.username, method: fromBio ? 'biometric' : 'password');
      return;
    }
    setState(() => _step = _Step.totp);
  }

  bool _looksLikeNetwork(Object e) {
    if (e is SocketException || e is HttpException) return true;
    final msg = (e is PostgrestException ? e.message : '$e').toLowerCase();
    return msg.contains('failed to fetch') ||
        msg.contains('network') ||
        msg.contains('load failed') ||
        msg.contains('err_network') ||
        msg.contains('socket') ||
        msg.contains('failed host lookup') ||
        msg.contains('clientexception') ||
        msg.contains('connection');
  }

  Future<void> _submitPassword() async {
    setState(() => _error = '');
    final rawUser = _username.text;
    final rawPass = _password.text;
    if (rawUser.isEmpty || rawPass.isEmpty) {
      _setError('login.enterBoth');
      return;
    }
    setState(() => _loading = true);
    final u = rawUser.trim().toUpperCase();
    Map<String, dynamic>? data;
    Object? queryError;
    try {
      data = await _repo.fetchSuperAdminByUsername(u);
    } catch (e) {
      queryError = e;
    }
    if (!mounted) return;
    setState(() => _loading = false);
    if (queryError != null) {
      final reason = queryError is PostgrestException ? (queryError.code ?? queryError.message) : '$queryError';
      SuperadminAudit.loginFailed(u, reason);
      _setError(_looksLikeNetwork(queryError) ? 'login.connectionProblem' : 'login.invalidCredentials');
      return;
    }
    if (data == null) {
      SuperadminAudit.loginFailed(u);
      _setError('login.invalidCredentials');
      return;
    }
    final row = SuperAdminRow.fromJson(data);
    if (row.password.trim() != rawPass.trim()) {
      SuperadminAudit.loginFailed(u);
      _setError('login.invalidCredentials');
      return;
    }
    _afterPasswordOk(row, false);
  }

  Future<void> _biometricLogin() async {
    setState(() {
      _error = '';
      _bioLoading = true;
    });
    final userId = await _bio.authenticate();
    if (!mounted) return;
    if (userId == null) {
      setState(() => _bioLoading = false);
      _setError('biometric.notRegistered');
      return;
    }
    Map<String, dynamic>? data;
    try {
      data = await _repo.fetchSuperAdminById(userId);
    } catch (_) {
      data = null;
    }
    if (!mounted) return;
    setState(() => _bioLoading = false);
    if (data == null) {
      SuperadminAudit.loginFailed(userId, 'biometric_user_not_found');
      _setError('login.invalidCredentials');
      return;
    }
    final row = SuperAdminRow.fromJson(data);
    if (row.totpEnabled && !row.hasTotpSecret) {
      _setError('superadmin.completeMfaWithPassword');
      return;
    }
    _afterPasswordOk(row, true);
  }

  void _submitTotp() {
    setState(() => _error = '');
    final row = _pending;
    final secret = row?.totpSecret;
    if (row == null || secret == null || secret.isEmpty || !verifyTotpCode(secret, _totpCode.text)) {
      _setError('superadmin.invalidAuthenticatorCode');
      return;
    }
    _finishLogin(
      id: row.id,
      name: row.name,
      username: row.username,
      method: _cameFromBiometric ? 'biometric_totp' : 'password_totp',
    );
  }

  Future<void> _submitSetupTotp() async {
    setState(() => _error = '');
    final row = _pending;
    final secret = _setupSecret;
    if (row == null || secret == null || !verifyTotpCode(secret, _totpCode.text)) {
      _setError('superadmin.invalidAuthenticatorCode');
      return;
    }
    setState(() => _loading = true);
    var ok = true;
    try {
      await _repo.updateSuperAdmin(row.id, {'totp_secret': secret, 'totp_enabled': true});
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() => _loading = false);
    if (!ok) {
      _setError('superadmin.couldNotSaveMfa');
      return;
    }
    final next = row.copyWith(totpSecret: secret, totpEnabled: true);
    setState(() {
      _pending = next;
      _recoveryEmailInput.text = next.recoveryEmail?.trim() ?? '';
      _step = _Step.setupRecovery;
    });
  }

  Future<void> _saveRecoveryAndEnter() async {
    setState(() => _error = '');
    final email = _recoveryEmailInput.text.trim().toLowerCase();
    if (email.isEmpty || !isValidEmail(email)) {
      _setError('superadmin.invalidRecoveryEmail');
      return;
    }
    final row = _pending;
    if (row == null) return;
    setState(() => _loading = true);
    var ok = true;
    try {
      await _repo.updateSuperAdmin(row.id, {'recovery_email': email});
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() => _loading = false);
    if (!ok) {
      _setError('superadmin.couldNotSaveRecovery');
      return;
    }
    _finishLogin(id: row.id, name: row.name, username: row.username, method: 'mfa_enrollment');
  }

  Future<void> _sendRecovery() async {
    setState(() => _error = '');
    final u = _recoveryUsername.text.trim().toUpperCase();
    final em = _recoveryEmailRequest.text.trim().toLowerCase();
    if (u.isEmpty || em.isEmpty) {
      _setError('login.enterBoth');
      return;
    }
    setState(() => _loading = true);
    final res = await _repo.sendRecoveryCode(u, em);
    if (!mounted) return;
    setState(() => _loading = false);
    if (res.failed) {
      final msg = res.errorMessage ?? '';
      setState(() => _error = msg.isNotEmpty ? msg : context.t('superadmin.recoverySendFailed'));
      return;
    }
    final data = res.data;
    if (data != null && data['ok'] == false && data['error'] != null && '${data['error']}'.isNotEmpty) {
      setState(() => _error = '${data['error']}');
      return;
    }
    final devCode = data?['dev_code'];
    setState(() {
      _recoveryInfo = (devCode != null && '$devCode'.isNotEmpty) ? '${context.t('superadmin.devRecoveryCode')}: $devCode' : '';
      _recoveryUsername.text = u;
      _step = _Step.recoveryVerify;
    });
  }

  Future<void> _verifyRecovery() async {
    setState(() => _error = '');
    final code = digitsOnly(_recoveryCode.text);
    if (code.length != 6) {
      _setError('superadmin.enterSixDigitRecovery');
      return;
    }
    setState(() => _loading = true);
    final res = await _repo.verifyRecoveryCode(_recoveryUsername.text.trim().toUpperCase(), code);
    if (!mounted) return;
    setState(() => _loading = false);
    final data = res.data;
    final profile = data?['profile'];
    if (res.failed || data?['ok'] != true || profile is! Map) {
      _setError('superadmin.invalidRecoveryCode');
      return;
    }
    _finishLogin(
      id: '${profile['id']}',
      name: '${profile['name'] ?? ''}',
      username: '${profile['username'] ?? ''}',
      method: 'recovery_email',
    );
  }

  Future<void> _openAuthenticator(String uri) async {
    var opened = false;
    try {
      opened = await launchUrl(Uri.parse(uri), mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) AppFeedback.toast(context, context.st('sa.login.noAuthenticator'), tone: BadgeTone.warning);
  }

  // ---------------------------------------------------------------------------
  // UI

  Widget _primaryButton(String label, VoidCallback onPressed, {String? loadingLabel}) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: AppButton(
          label: _loading && loadingLabel != null ? loadingLabel : label,
          loading: _loading && loadingLabel == null,
          onPressed: _loading ? null : onPressed,
        ),
      );

  Widget _caption(String text, {bool strong = false}) => Text(
        text,
        textAlign: TextAlign.center,
        style: strong ? AppText.sectionTitle(context) : AppText.body(context).copyWith(color: context.tokens.mutedForeground),
      );

  List<Widget> _gap(List<Widget> items, [double h = 16]) => [
        for (var i = 0; i < items.length; i++) ...[if (i > 0) SizedBox(height: h), items[i]],
      ];

  Widget _passwordStep() {
    final t = context.tokens;
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_bioAvailable) ...[
            Material(
              color: AppTokens.tint(t.primary, 0.05),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTokens.radius),
                side: BorderSide(color: AppTokens.tint(t.primary, 0.3), width: 2),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppTokens.radius),
                onTap: _bioLoading ? null : _biometricLogin,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      _bioLoading
                          ? SizedBox(width: 32, height: 32, child: CircularProgressIndicator(color: t.primary, strokeWidth: 3))
                          : Icon(Icons.fingerprint, size: 32, color: t.primary),
                      const SizedBox(height: 8),
                      Text(
                        context.t('biometric.loginButton'),
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: t.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          ..._gap([
            AppTextField(
              label: context.t('superadmin.username'),
              hint: 'SUPERADMIN',
              controller: _username,
              mono: true,
              caps: false,
              inputFormatters: const [UpperCaseTextFormatter()],
              textInputAction: TextInputAction.next,
            ),
            AppTextField(
              label: context.t('login.password'),
              hint: context.t('login.passwordPlaceholder'),
              controller: _password,
              obscure: !_showPassword,
              caps: false,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submitPassword(),
              suffix: IconButton(
                icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                color: t.mutedForeground,
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
            ),
            if (_error.isNotEmpty) SaErrorText(_error),
            _primaryButton(context.t('superadmin.loginButton'), _submitPassword, loadingLabel: context.t('login.loggingIn')),
          ]),
          const SizedBox(height: 8),
          SaLinkButton(
            label: context.t('superadmin.lockedOutRecovery'),
            onTap: () => setState(() {
              _error = '';
              _recoveryInfo = '';
              _step = _Step.recoveryRequest;
            }),
          ),
          if (widget.onBack != null) ...[
            const SizedBox(height: 4),
            SaLinkButton(label: '← ${context.t('admin.backToMain')}', onTap: widget.onBack),
          ],
        ],
      ),
    );
  }

  Widget _totpStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _gap([
          _caption(context.t('superadmin.enterAuthenticatorCode')),
          OtpCodeField(controller: _totpCode, onSubmitted: (_) => _submitTotp()),
          if (_error.isNotEmpty) SaErrorText(_error),
          _primaryButton(context.t('superadmin.verifyAndContinue'), _submitTotp),
          SaLinkButton(
            label: context.t('superadmin.backToLogin'),
            onTap: () => setState(() {
              _step = _Step.password;
              _pending = null;
              _totpCode.clear();
              _error = '';
            }),
          ),
        ]),
      );

  Widget _setupQrStep() {
    final row = _pending!;
    final secret = _setupSecret!;
    final uri = buildTotpKeyUri(secret, row.username);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: _gap([
        _caption(context.t('superadmin.mfaSetupTitle'), strong: true),
        Text(context.t('superadmin.mfaSetupSubtitle'), textAlign: TextAlign.center, style: AppText.caption(context)),
        TotpQrCode(data: uri),
        SelectableText(
          secret,
          textAlign: TextAlign.center,
          style: AppText.mono(context, size: 11, color: context.tokens.mutedForeground),
        ),
        Text(context.st('sa.login.sameDeviceHint'), textAlign: TextAlign.center, style: AppText.tiny(context)),
        Row(
          children: [
            Expanded(
              child: AppButton.secondary(
                label: context.st('sa.login.openAuthenticator'),
                icon: Icons.open_in_new,
                dense: true,
                onPressed: () => _openAuthenticator(uri),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppButton.secondary(
                label: context.st('sa.login.copyKey'),
                icon: Icons.content_copy,
                dense: true,
                onPressed: () => saCopy(context, secret),
              ),
            ),
          ],
        ),
        SizedBox(
          width: double.infinity,
          child: AppButton(
            label: context.t('superadmin.iHaveAddedApp'),
            onPressed: () => setState(() {
              _error = '';
              _step = _Step.setupTotpVerify;
            }),
          ),
        ),
      ]),
    );
  }

  Widget _setupVerifyStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _gap([
          _caption(context.t('superadmin.enterCodeFromApp')),
          OtpCodeField(controller: _totpCode, onSubmitted: (_) => _submitSetupTotp()),
          if (_error.isNotEmpty) SaErrorText(_error),
          _primaryButton(context.t('superadmin.verifyAndContinue'), _submitSetupTotp),
          SaLinkButton(
            label: context.t('superadmin.backToQr'),
            onTap: () => setState(() {
              _error = '';
              _step = _Step.setupQr;
            }),
          ),
        ]),
      );

  Widget _setupRecoveryStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _gap([
          _caption(context.t('superadmin.recoveryEmailStepTitle'), strong: true),
          Text(context.t('superadmin.recoveryEmailStepHelp'), textAlign: TextAlign.center, style: AppText.caption(context)),
          AppTextField(
            controller: _recoveryEmailInput,
            hint: 'you@example.com',
            keyboardType: TextInputType.emailAddress,
            caps: false,
            onSubmitted: (_) => _saveRecoveryAndEnter(),
          ),
          if (_error.isNotEmpty) SaErrorText(_error),
          _primaryButton(context.t('superadmin.finishAndEnter'), _saveRecoveryAndEnter),
        ]),
      );

  Widget _recoveryRequestStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _gap([
          _caption(context.t('superadmin.recoveryRequestHelp')),
          AppTextField(
            label: context.t('superadmin.username'),
            controller: _recoveryUsername,
            mono: true,
            caps: false,
            inputFormatters: const [UpperCaseTextFormatter()],
            textInputAction: TextInputAction.next,
          ),
          AppTextField(
            label: context.t('superadmin.recoveryEmailLabel'),
            controller: _recoveryEmailRequest,
            keyboardType: TextInputType.emailAddress,
            caps: false,
            onSubmitted: (_) => _sendRecovery(),
          ),
          if (_error.isNotEmpty) SaErrorText(_error),
          _primaryButton(context.t('superadmin.sendRecoveryCode'), _sendRecovery),
          SaLinkButton(
            label: context.t('superadmin.backToLogin'),
            onTap: () => setState(() {
              _error = '';
              _step = _Step.password;
            }),
          ),
        ]),
      );

  Widget _recoveryVerifyStep() {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _gap([
        if (_recoveryInfo.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTokens.tint(t.warning, 0.10),
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            ),
            child: SelectableText(
              _recoveryInfo,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: t.warning),
            ),
          ),
        _caption(context.t('superadmin.enterRecoveryCode')),
        OtpCodeField(controller: _recoveryCode, onSubmitted: (_) => _verifyRecovery()),
        if (_error.isNotEmpty) SaErrorText(_error),
        _primaryButton(context.t('superadmin.verifyAndContinue'), _verifyRecovery),
        SaLinkButton(
          label: context.t('superadmin.resendRecovery'),
          onTap: () => setState(() {
            _error = '';
            _recoveryCode.clear();
            _step = _Step.recoveryRequest;
          }),
        ),
      ]),
    );
  }

  Widget _fullHeader() {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTokens.tint(t.primary, 0.10),
              borderRadius: BorderRadius.circular(AppTokens.radiusXl),
            ),
            child: Icon(Icons.workspace_premium_outlined, size: 40, color: t.primary),
          ),
          const SizedBox(height: 16),
          Text(
            context.t('app.name'),
            textAlign: TextAlign.center,
            style: AppText.pageTitle(context).copyWith(fontSize: 24),
          ),
          const SizedBox(height: 4),
          Text(context.t('app.subtitle'), textAlign: TextAlign.center, style: AppText.caption(context)),
          const SizedBox(height: 2),
          Text(
            context.t('app.tagline'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AppTokens.tint(t.mutedForeground, 0.8)),
          ),
          const SizedBox(height: 16),
          Text(context.t('superadmin.login'), style: AppText.pageTitle(context)),
          const SizedBox(height: 4),
          Text(
            context.t('superadmin.loginSubtitle'),
            style: AppText.body(context).copyWith(color: t.mutedForeground),
          ),
        ],
      ),
    );
  }

  Widget _embeddedHeader() {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(Icons.shield_outlined, size: 20, color: t.primary),
          const SizedBox(width: 8),
          Text(
            context.t('superadmin.login'),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: t.primary),
          ),
        ],
      ),
    );
  }

  Widget _form({required bool embedded}) {
    final body = switch (_step) {
      _Step.password => _passwordStep(),
      _Step.totp => _pending == null ? _passwordStep() : _totpStep(),
      _Step.setupQr => (_pending == null || _setupSecret == null) ? _passwordStep() : _setupQrStep(),
      _Step.setupTotpVerify => (_pending == null || _setupSecret == null) ? _passwordStep() : _setupVerifyStep(),
      _Step.setupRecovery => _pending == null ? _passwordStep() : _setupRecoveryStep(),
      _Step.recoveryRequest => _recoveryRequestStep(),
      _Step.recoveryVerify => _recoveryVerifyStep(),
    };
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 384),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_step == _Step.password) embedded ? _embeddedHeader() : _fullHeader(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: KeyedSubtree(key: ValueKey(_step), child: body),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == _Step.password,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        setState(() {
          _error = '';
          _pending = null;
          _totpCode.clear();
          _step = _Step.password;
        });
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final embedded = !constraints.hasBoundedHeight;
          if (embedded) return Center(child: _form(embedded: true));
          return Material(
            color: context.tokens.background,
            child: SafeArea(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(24, 56, 24, 48),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: (constraints.maxHeight - 104).clamp(0, double.infinity)),
                        child: Center(child: _form(embedded: false)),
                      ),
                    ),
                  ),
                  const Positioned(
                    top: 12,
                    right: 12,
                    child: Row(children: [LanguageToggle(), SizedBox(width: 8), ThemeToggle()]),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Keeps `services.dart` referenced for the formatter types used above.
typedef _Formatter = TextInputFormatter;
