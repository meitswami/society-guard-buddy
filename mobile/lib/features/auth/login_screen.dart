import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui/ui.dart';
import '../../models/biometric_enrollment.dart';
import '../../models/flat_row.dart';
import '../../models/guard_session.dart';
import '../../models/resident_user.dart';
import '../../models/session_models.dart';
import '../../providers/session_provider.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_login_service.dart';
import '../../services/biometric_service.dart';
import '../../services/guard_session_service.dart';
import '../../services/login_remember.dart';
import '../../services/resident_login_service.dart';
import '../../services/society_service.dart';
import '../public/data/society_signup_service.dart';
import '../public/public_nav.dart';
import '../superadmin/superadmin_login_view.dart';
import 'data/auth_audit.dart';
import 'data/login_geofence.dart';
import 'data/login_logic.dart';
import 'data/login_societies_controller.dart';
import 'password_reset_screen.dart';
import 'widgets/guard_login_preview.dart';
import 'widgets/login_footer.dart';
import 'widgets/login_widgets.dart';
import 'widgets/otp_login_flow.dart';
import 'widgets/resident_otp_onboarding.dart';

/// Unified login — port of web `UnifiedLoginPage` (phones & tablets):
/// society picker (retry / reload on reconnect) → role → flat (residents) →
/// OTP (resident / guard) or ID & password, fingerprint quick login, guard preview,
/// password reset, "Register a new society", legal footer, language / theme toggles.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _societyService = SocietyService();
  final _auth = AuthService();
  final _residentLogin = ResidentLoginService();
  final _guardSessions = GuardSessionService();
  late final LoginSocietiesController _societies = LoginSocietiesController(service: _societyService);
  AppLifecycleListener? _lifecycle;

  final _identifier = TextEditingController();
  final _password = TextEditingController();

  String _societyId = '';
  LoginRole? _role;
  List<FlatRow> _flats = const [];
  bool _flatsLoading = false;
  String _flatId = '';
  int _flatsRequest = 0;
  bool _superadminMode = false;
  LoginMode _loginMode = LoginMode.otp;
  bool _showPassword = false;
  String _error = '';
  bool _loading = false;
  bool _bioAvailable = false;
  bool _bioLoading = false;
  String _rememberedPhone = '';
  bool _prefsRestored = false;
  PendingSocietySignup? _pendingSignup;

  @override
  void initState() {
    super.initState();
    _societies.addListener(_onSocietiesChanged);
    _societies.start();
    _lifecycle = AppLifecycleListener(onResume: _societies.retryIfEmpty);
    BiometricService().isDeviceSupported().then((v) {
      if (mounted) setState(() => _bioAvailable = v);
    });
    SocietySignupStore.readPending().then((p) {
      if (mounted) setState(() => _pendingSignup = p);
    });
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    _societies.removeListener(_onSocietiesChanged);
    _societies.dispose();
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Remembered society / role / flat / phone (web `readLoginRemember` effect)
  // ---------------------------------------------------------------------------

  void _onSocietiesChanged() {
    if (!mounted) return;
    setState(() {});
    if (_societies.societies.isEmpty || _prefsRestored) return;
    _prefsRestored = true;
    unawaited(_restoreRemembered());
  }

  Future<void> _restoreRemembered() async {
    final rem = await LoginRemember.read();
    if (rem == null || !mounted) return;
    setState(() {
      final sid = rem.societyId;
      if (sid != null && _societies.societies.any((s) => s.id == sid)) _societyId = sid;
      final role = loginRoleFromKey(rem.validRole);
      if (role != null) {
        _role = role;
        if (role == LoginRole.admin) _loginMode = LoginMode.credentials;
      }
      final phone = rem.phone;
      if (phone != null && phone.isNotEmpty) {
        _identifier.text = phone;
        _rememberedPhone = phone;
      }
    });
    _reloadFlats();
  }

  void _persist(Map<String, String?> patch) => unawaited(LoginRemember.patch(patch));

  /// Web flats effect on `[selectedSocietyId, loginRole]`.
  void _reloadFlats() {
    final request = ++_flatsRequest;
    if (_societyId.isEmpty || _role != LoginRole.resident) {
      setState(() {
        _flats = const [];
        _flatsLoading = false;
        _flatId = '';
      });
      return;
    }
    setState(() => _flatsLoading = true);
    final sid = _societyId;
    () async {
      List<FlatRow> flats;
      try {
        flats = await _societyService.fetchLoginFlats(sid);
      } catch (_) {
        flats = const [];
      }
      final rem = await LoginRemember.read();
      if (!mounted || request != _flatsRequest) return;
      setState(() {
        _flats = flats;
        _flatsLoading = false;
        final remFlat = rem?.flatId;
        _flatId = rem?.societyId == sid && remFlat != null && flats.any((f) => f.id == remFlat) ? remFlat : '';
      });
    }();
  }

  // ---------------------------------------------------------------------------
  // Selections
  // ---------------------------------------------------------------------------

  String get _societyName => _societies.societies.where((s) => s.id == _societyId).map((s) => s.name).firstOrNull ?? '';

  void _onSociety(String? next) {
    setState(() {
      _societyId = next ?? '';
      _role = null;
      _flatId = '';
      _error = '';
    });
    _persist({'societyId': next, 'role': null, 'flatId': null});
    _reloadFlats();
  }

  void _onRole(LoginRole? next) {
    setState(() {
      _role = next;
      _flatId = '';
      _error = '';
      if (next == LoginRole.admin) _loginMode = LoginMode.credentials;
    });
    _persist({'societyId': _societyId, 'role': next?.name, 'flatId': null});
    _reloadFlats();
  }

  void _onFlat(FlatRow? next) {
    setState(() {
      _flatId = next?.id ?? '';
      _error = '';
    });
    _persist({'societyId': _societyId, 'role': 'resident', 'flatId': next?.id});
  }

  void _onOtpPhoneChange(String phone) {
    _rememberedPhone = phone;
    _persist({
      'phone': phone,
      if (_societyId.isNotEmpty) 'societyId': _societyId,
      if (_role != null) 'role': _role!.name,
      if (_flatId.isNotEmpty) 'flatId': _flatId,
    });
  }

  void _onIdentifierChanged(String next) {
    if (_role != LoginRole.resident) return;
    final digits = phoneInputDigits(next);
    _rememberedPhone = digits;
    _persist({
      'role': 'resident',
      'phone': digits,
      if (_societyId.isNotEmpty) 'societyId': _societyId,
      if (_flatId.isNotEmpty) 'flatId': _flatId,
    });
  }

  void _fail(String message) {
    if (mounted) setState(() => _error = message);
  }

  /// Error from a web translation key (safe after async gaps).
  void _failKey(String key) {
    if (!mounted) return;
    setState(() => _error = context.t(key));
  }

  Future<bool> _withinFence() async {
    final result = await checkSocietyGeofence(_societyId, GeofencePolicy.permissive);
    return result.ok;
  }

  // ---------------------------------------------------------------------------
  // Session hand-off (router redirects on session change)
  // ---------------------------------------------------------------------------

  Future<void> _enterResident(ResidentUser resident) async {
    try {
      await ref.read(sessionProvider.notifier).loginResident(societyId: _societyId, societyName: _societyName, resident: resident);
    } catch (_) {}
  }

  Future<void> _enterGuard(GuardSession guard, String shiftId) async {
    try {
      await ref.read(sessionProvider.notifier).loginGuard(societyId: _societyId, societyName: _societyName, guard: guard, shiftId: shiftId);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // OTP verified (web `handleOtpVerified`)
  // ---------------------------------------------------------------------------

  Future<void> _handleOtpVerified(String phone) async {
    _fail('');
    if (_societyId.isEmpty) return _failKey('login.pickSocietyFirst');
    final role = _role;
    if (role == null) return _failKey('login.pickRoleFirst');
    if (role == LoginRole.admin) return _failKey('login.adminUsePassword');
    final normalized = normalizeLoginPhone(phone);

    try {
      if (role == LoginRole.guard) {
        final lookup = await _residentLogin.lookupGuardForOtp(normalized, _societyId);
        if (!mounted) return;
        switch (lookup) {
          case GuardOtpNotFound(:final reason):
            return _fail(context
                .t(reason == GuardOtpFailureReason.passwordMode ? 'login.guardOtpPasswordMode' : 'login.guardOtpPhoneNotRegistered'));
          case GuardOtpFound(:final guard):
            if (!await _withinFence()) {
              if (mounted) _failKey('admin.geofenceBlocked');
              return;
            }
            final session = guard.toSession();
            final shiftId = await _guardSessions.establishGuardSession(societyId: _societyId, guard: session);
            if (!mounted) return;
            if (shiftId == null) return _failKey('login.invalidCredentials');
            AuthAudit.loginSuccess('guard', guard.guardId, guard.name, method: 'otp', societyId: _societyId);
            _persist({'societyId': _societyId, 'role': 'guard', 'phone': normalized});
            await _enterGuard(session, shiftId);
            return;
        }
      }

      if (_flatId.isEmpty) return _failKey('login.pickFlatFirst');

      final otherFlat = await _residentLogin.otherFlatForPhone(phone: normalized, societyId: _societyId);
      if (!mounted) return;
      if (otherFlat != null && otherFlat != _flatId) return _failKey('login.onboard.phoneOtherFlat');

      final row = await _societyService.getResidentByPhoneInSociety(normalized, _societyId);
      if (!mounted) return;
      if (row != null) {
        final resident = ResidentUser.fromRow(row);
        if (resident.flatId != _flatId) return _failKey('login.onboard.phoneOtherFlat');
        AuthAudit.loginSuccess('resident', resident.id, resident.name, method: 'otp', societyId: _societyId);
        _persist({'societyId': _societyId, 'role': 'resident', 'flatId': _flatId, 'phone': normalized});
        await _enterResident(resident);
        return;
      }

      final flat = _flats.where((f) => f.id == _flatId).firstOrNull;
      if (flat == null) return _failKey('login.pickFlatFirst');
      await _onboardAndEnter(phone: normalized, flatNumber: flat.flatNumber, method: 'otp');
    } catch (_) {
      _failKey('login.connectionProblem');
    }
  }

  /// First-time login for the flat (web `completeResidentOtpOnboarding` + session).
  Future<void> _onboardAndEnter({required String phone, required String flatNumber, required String method}) async {
    final flatId = _flatId;
    final onboarded = await ResidentOtpOnboarding.run(context, phone: phone, flatId: flatId, flatNumber: flatNumber);
    if (onboarded == null || !mounted) return;
    if (onboarded.openFamilyTab) await LoginRemember.setOpenFamilyTab();
    final user = onboarded.user;
    AuthAudit.loginSuccess('resident', user.id, user.name, method: method, societyId: _societyId);
    _persist({'societyId': _societyId, 'role': 'resident', 'flatId': flatId, 'phone': phone});
    await _enterResident(user);
  }

  // ---------------------------------------------------------------------------
  // ID & password (web `handleCredentialLogin`)
  // ---------------------------------------------------------------------------

  Future<void> _handleCredentialLogin() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = '');
    if (_societyId.isEmpty) return _failKey('login.pickSocietyFirst');
    final role = _role;
    if (role == null) return _failKey('login.pickRoleFirst');
    final password = _password.text;
    if (_identifier.text.isEmpty || password.isEmpty) return _failKey('login.enterBoth');

    setState(() => _loading = true);
    final idRaw = _identifier.text.trim();
    final id = credentialIdentifier(role, idRaw);
    try {
      switch (role) {
        case LoginRole.admin:
          final admin = await _auth.findAdminForLogin(societyId: _societyId, adminId: idRaw, password: password);
          if (!mounted) return;
          if (admin == null) {
            AuthAudit.loginFailed('admin', idRaw, societyId: _societyId);
            return _failKey('login.invalidCredentials');
          }
          AuthAudit.loginSuccess('admin', admin.id, admin.name, societyId: _societyId);
          try {
            await ref.read(sessionProvider.notifier).loginAdmin(
                  societyId: admin.societyId ?? _societyId,
                  societyName: _societyName,
                  admin: admin,
                );
          } catch (_) {}
          return;

        case LoginRole.guard:
          final guard = await _auth.findGuardForLogin(societyId: _societyId, guardId: idRaw, password: password);
          if (!mounted) return;
          if (guard == null) {
            AuthAudit.loginFailed('guard', idRaw, societyId: _societyId);
            return _failKey('login.invalidCredentials');
          }
          if (!await _withinFence()) {
            if (mounted) _failKey('admin.geofenceBlocked');
            return;
          }
          final shiftId = await _guardSessions.establishGuardSession(societyId: _societyId, guard: guard.session);
          if (!mounted) return;
          if (shiftId == null) return _failKey('login.invalidCredentials');
          AuthAudit.loginSuccess('guard', guard.session.guardId, guard.session.name, societyId: _societyId);
          await _enterGuard(guard.session, shiftId);
          return;

        case LoginRole.resident:
          if (_flatId.isEmpty) return _failKey('login.pickFlatFirst');
          var flatNumber = _flats.where((f) => f.id == _flatId).map((f) => f.flatNumber).firstOrNull ?? '';
          if (flatNumber.isEmpty) flatNumber = await _auth.fetchFlatNumber(_flatId);

          final otherFlat = await _residentLogin.otherFlatForPhone(phone: id, societyId: _societyId);
          if (!mounted) return;
          if (otherFlat != null && otherFlat != _flatId) return _failKey('login.onboard.phoneOtherFlat');

          final resident = await _auth.findResidentForPassword(flatId: _flatId, phone: id, password: password);
          if (!mounted) return;
          if (resident != null) {
            AuthAudit.loginSuccess('resident', resident.id, resident.name, societyId: _societyId);
            _persist({'societyId': _societyId, 'role': 'resident', 'flatId': _flatId, 'phone': id});
            await _enterResident(resident);
            return;
          }

          final onFlat = await _auth.residentLoginOnFlat(flatId: _flatId, phone: id);
          if (!mounted) return;
          if (onFlat != null && onFlat.password != password) {
            AuthAudit.loginFailed('resident', idRaw, societyId: _societyId);
            return _failKey('login.invalidCredentials');
          }
          if (!await _auth.flatPasswordMatches(flatId: _flatId, password: password)) {
            AuthAudit.loginFailed('resident', idRaw, societyId: _societyId);
            if (mounted) _failKey('login.invalidCredentials');
            return;
          }
          if (!mounted) return;
          // Flat password is right but this phone has no login yet → same steps as OTP.
          await _onboardAndEnter(phone: id, flatNumber: flatNumber, method: 'password');
          return;
      }
    } catch (_) {
      _failKey('login.connectionProblem');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Fingerprint (web `handleUnifiedBiometricLogin`; native enrollments instead of passkeys)
  // ---------------------------------------------------------------------------

  Future<BiometricEnrollment?> _pickEnrollment(List<BiometricEnrollment> options) async {
    if (options.length == 1) return options.first;
    return showModalBottomSheet<BiometricEnrollment>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(ctx.tr('Choose account', 'खाता चुनें'), style: AppText.sectionTitle(ctx)),
            ),
            for (final e in options)
              ListTile(
                leading: Icon(Icons.fingerprint, color: ctx.tokens.primary),
                title: Text(e.displayName),
                subtitle: Text([e.guardId, e.flatNumber, e.societyName].whereType<String>().where((s) => s.isNotEmpty).join(' · ')),
                onTap: () => Navigator.pop(ctx, e),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleBiometricLogin() async {
    setState(() => _error = '');
    if (_societyId.isEmpty) return _failKey('login.pickSocietyFirst');
    final role = _role;
    if (role == null) return _failKey('login.pickRoleFirst');
    if (role == LoginRole.admin) return _failKey('login.adminUsePassword');
    if (role == LoginRole.resident && _flatId.isEmpty) return _failKey('login.pickFlatFirst');

    setState(() => _bioLoading = true);
    try {
      final roleKey = role.name;
      final all = (await BiometricLoginService().listEnrollments()).where((e) => e.role == roleKey && e.societyId == _societyId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!mounted) return;
      final usable = role == LoginRole.resident ? all.where((e) => e.flatId == _flatId).toList() : all;
      if (usable.isEmpty) {
        return _failKey(all.isNotEmpty ? 'login.onboard.phoneOtherFlat' : 'biometric.notRegistered');
      }
      final picked = await _pickEnrollment(usable);
      if (picked == null || !mounted) return;

      final ok = await BiometricService().authenticate(reason: context.t('biometric.loginButton'), biometricOnly: false);
      if (!mounted) return;
      if (!ok) return _fail(context.tr('Fingerprint sign-in cancelled', 'फ़िंगरप्रिंट प्रवेश रद्द किया गया'));

      if (role == LoginRole.guard) {
        final guard = await _auth.fetchGuardByDbId(picked.userDbId);
        if (!mounted) return;
        if (guard == null || guard.societyId != _societyId) return _failKey('login.invalidCredentials');
        if (!await _withinFence()) {
          if (mounted) _failKey('admin.geofenceBlocked');
          return;
        }
        final shiftId = await _guardSessions.establishGuardSession(societyId: _societyId, guard: guard.session);
        if (!mounted) return;
        if (shiftId == null) return _failKey('login.invalidCredentials');
        AuthAudit.biometricLogin('guard', guard.dbId, guard.session.name, societyId: _societyId);
        await _enterGuard(guard.session, shiftId);
        return;
      }

      final resident = await _auth.fetchResidentById(picked.userDbId);
      if (!mounted) return;
      if (resident == null) return _failKey('login.invalidCredentials');
      final flatSociety = await _auth.fetchFlatSocietyId(resident.flatId);
      if (!mounted) return;
      if (flatSociety != _societyId) return _failKey('login.invalidCredentials');
      if (resident.flatId != _flatId) return _failKey('login.onboard.phoneOtherFlat');
      AuthAudit.biometricLogin('resident', resident.id, resident.name, societyId: _societyId);
      await _enterResident(resident);
    } catch (_) {
      _failKey('login.connectionProblem');
    } finally {
      if (mounted) setState(() => _bioLoading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Superadmin (web `superadminMode` + `SuperadminLoginForm variant="embedded"`)
  // ---------------------------------------------------------------------------

  void _exitSuperadmin() {
    setState(() {
      _superadminMode = false;
      _error = '';
      _identifier.clear();
      _password.clear();
      _role = null;
      _flatId = '';
    });
    _reloadFlats();
  }

  void _onSuperadminLoggedIn(SessionSuperadmin session) {
    // SuperadminLoginView already persisted the session (sessionProvider.loginSuperadmin);
    // the router leaves the login screen on the session change.
    if (mounted) setState(() => _superadminMode = false);
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  Future<void> _openSignup() async {
    await PublicNav.open(context, PublicPage.societySignup);
    final pending = await SocietySignupStore.readPending();
    if (mounted) setState(() => _pendingSignup = pending);
  }

  Future<void> _openSignupStatus() async {
    await PublicNav.open(context, PublicPage.societySignupStatus);
    final pending = await SocietySignupStore.readPending();
    if (mounted) setState(() => _pendingSignup = pending);
    _societies.retryIfEmpty();
  }

  Widget _errorText(String text) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: context.tokens.destructive)),
      );

  List<Widget> _societySection(bool showSuperadmin) {
    final t = context.tokens;
    final selected = _societies.societies.where((s) => s.id == _societyId).firstOrNull;
    return [
      FieldLabel(context.t('login.selectSociety')),
      SelectSheetField<SocietyRow>(
        value: selected,
        options: _societies.societies,
        labelOf: (s) => s.name,
        placeholder: _societies.loading && _societies.societies.isEmpty ? context.t('app.loading') : context.t('login.societyPlaceholder'),
        sheetTitle: context.t('login.selectSociety'),
        leadingIcon: Icons.apartment_outlined,
        onChanged: (s) => _onSociety(s?.id),
      ),
      const SizedBox(height: 8),
      SocietyListStatus(
        loading: _societies.loading,
        error: _societies.error,
        count: _societies.societies.length,
        onRetry: () => unawaited(_societies.reload()),
      ),
      if (_societyId.isEmpty) ...[
        const SizedBox(height: 8),
        RegisterSocietyCta(onTap: _openSignup),
        const SizedBox(height: 8),
        LoginHint(context.t('login.createSocietyCta'), size: 10, bottom: 0),
        if (_pendingSignup != null)
          Center(
            child: TextButton(
              onPressed: _openSignupStatus,
              style: TextButton.styleFrom(foregroundColor: t.primary, textStyle: const TextStyle(fontSize: 11)),
              child: Text(
                context.tr('Check society signup status', 'सोसाइटी पंजीकरण स्थिति देखें'),
                style: const TextStyle(decoration: TextDecoration.underline),
              ),
            ),
          ),
      ],
      if (showSuperadmin)
        Center(
          child: TextButton(
            onPressed: () => setState(() => _superadminMode = true),
            style: TextButton.styleFrom(foregroundColor: t.mutedForeground, textStyle: const TextStyle(fontSize: 11)),
            child: Text(context.t('login.superadminPlatform'), style: const TextStyle(decoration: TextDecoration.underline)),
          ),
        ),
      const SizedBox(height: 16),
    ];
  }

  List<Widget> _roleSection() {
    final t = context.tokens;
    final role = _role;
    final selectedFlat = _flats.where((f) => f.id == _flatId).firstOrNull;
    return [
      FieldLabel(context.t('login.roleLabel')),
      SelectSheetField<LoginRole>(
        value: role,
        options: const [LoginRole.guard, LoginRole.admin, LoginRole.resident],
        labelOf: (r) => context.t(switch (r) {
          LoginRole.guard => 'login.roleGuard',
          LoginRole.admin => 'login.roleAdmin',
          LoginRole.resident => 'login.roleResident',
        }),
        placeholder: context.t('login.rolePlaceholder'),
        sheetTitle: context.t('login.roleLabel'),
        onChanged: _onRole,
      ),
      const SizedBox(height: 12),
      if (role == null) LoginHint(context.t('login.pickRoleFirst')),
      if (role == LoginRole.resident) ...[
        FieldLabel(context.t('login.flatLabel')),
        SelectSheetField<FlatRow>(
          value: selectedFlat,
          options: _flats,
          labelOf: (f) => f.flatNumber,
          placeholder: _flatsLoading ? context.t('login.flatsLoading') : context.t('login.flatPlaceholder'),
          sheetTitle: context.t('login.flatLabel'),
          enabled: !_flatsLoading && _flats.isNotEmpty,
          leadingIcon: Icons.home_outlined,
          onChanged: _onFlat,
        ),
        const SizedBox(height: 8),
        if (_flatsLoading) Text(context.t('login.flatsLoading'), style: TextStyle(fontSize: 11, color: t.mutedForeground)),
        if (!_flatsLoading && _flats.isEmpty)
          Text(context.t('login.noFlatsForSociety'), style: TextStyle(fontSize: 11, height: 1.5, color: t.warning)),
        if (!_flatsLoading && _flats.isNotEmpty && _flatId.isEmpty)
          Text(context.t('login.pickFlatFirst'), style: TextStyle(fontSize: 11, color: t.mutedForeground)),
        const SizedBox(height: 12),
      ],
      if (role == LoginRole.admin) LoginHint(context.t('login.adminUsePassword')),
      if (role == LoginRole.guard) const GuardLoginPreview(),
      if (role != null) ...[
        LoginModeToggle(
          mode: _loginMode,
          otpDisabled: role == LoginRole.admin,
          onChanged: (m) => setState(() {
            _loginMode = m;
            _error = '';
          }),
        ),
        const SizedBox(height: 16),
      ],
    ];
  }

  Widget _biometricButton() => BiometricQuickButton(onPressed: _handleBiometricLogin, loading: _bioLoading);

  List<Widget> _credentialsForm(bool showBio) {
    final t = context.tokens;
    final role = _role!;
    final label = switch (role) {
      LoginRole.resident => context.t('common.phone'),
      LoginRole.admin => context.t('admin.adminId'),
      LoginRole.guard => context.t('login.guardId'),
    };
    final placeholder = switch (role) {
      LoginRole.resident => context.t('resident.loginSubtitle'),
      LoginRole.admin => context.t('admin.adminId'),
      LoginRole.guard => context.t('login.guardIdPlaceholder'),
    };
    return [
      if (showBio && role != LoginRole.admin) _biometricButton(),
      AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FieldLabel(label),
            TextField(
              controller: _identifier,
              style: AppText.mono(context, size: 14),
              keyboardType: role == LoginRole.resident ? TextInputType.phone : TextInputType.text,
              autofillHints: [role == LoginRole.resident ? AutofillHints.telephoneNumber : AutofillHints.username],
              textCapitalization: role == LoginRole.resident ? TextCapitalization.none : TextCapitalization.characters,
              inputFormatters: role == LoginRole.resident ? null : [_UpperCaseFormatter()],
              textInputAction: TextInputAction.next,
              onChanged: _onIdentifierChanged,
              decoration: InputDecoration(hintText: placeholder),
            ),
            const SizedBox(height: 12),
            FieldLabel(context.t('login.password')),
            TextField(
              controller: _password,
              obscureText: !_showPassword,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _handleCredentialLogin(),
              style: TextStyle(fontSize: 14, color: t.foreground),
              decoration: InputDecoration(
                hintText: context.t('login.passwordPlaceholder'),
                suffixIcon: IconButton(
                  icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                  color: t.mutedForeground,
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      LoginHint(context.t(role == LoginRole.resident ? 'resident.enterBoth' : 'login.enterBoth'), size: 10, bottom: 4),
      if (role == LoginRole.resident)
        LoginHint(context.t('login.passwordSameHouseholdFlow'), size: 10, color: AppTokens.tint(t.mutedForeground, 0.9), bottom: 4),
      if (_error.isNotEmpty) _errorText(_error),
      const SizedBox(height: 12),
      AppButton(
        label: _loading ? context.t('login.loggingIn') : context.t('resident.login'),
        loading: _loading,
        onPressed: _handleCredentialLogin,
      ),
      const SizedBox(height: 4),
      Center(
        child: TextButton(
          onPressed: () => PasswordResetScreen.open(context, userType: resetUserTypeFor(role), societyId: _societyId),
          style: TextButton.styleFrom(foregroundColor: t.primary, textStyle: const TextStyle(fontSize: 12)),
          child: Text(context.t('login.forgotPassword'), style: const TextStyle(decoration: TextDecoration.underline)),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final showSuperadmin = showSuperadminEntryForWidth(width);
    final role = _role;
    final showBio = showBiometricLogin(
      deviceSupported: _bioAvailable,
      societyId: _societyId,
      superadminMode: _superadminMode,
      role: role,
      flatId: _flatId,
    );

    final content = <Widget>[
      const LoginBrandHeader(),
      if (_superadminMode) ...[
        SuperadminLoginView(onLoggedIn: _onSuperadminLoggedIn, onBack: _exitSuperadmin),
      ] else ...[
        ..._societySection(showSuperadmin),
        if (_societyId.isEmpty) LoginHint(context.t('login.pickSocietyFirst')),
        if (_societyId.isNotEmpty) ...[
          ..._roleSection(),
          if (role != null && _loginMode == LoginMode.otp && role != LoginRole.admin) ...[
            if (showBio) _biometricButton(),
            OtpLoginFlow(
              key: ValueKey('otp-$_societyId-${role.name}'),
              embedded: true,
              initialPhone: _rememberedPhone,
              onPhoneChange: _onOtpPhoneChange,
              onVerified: _handleOtpVerified,
              title: context.tr('Login with OTP', 'ओटीपी से प्रवेश'),
              subtitle: role == LoginRole.resident ? context.t('resident.loginSubtitle') : context.t('login.guardLogin'),
            ),
          ],
          if (role != null && (_loginMode == LoginMode.credentials || role == LoginRole.admin)) ..._credentialsForm(showBio),
          if (_loginMode == LoginMode.otp && _error.isNotEmpty) _errorText(_error),
        ],
      ],
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        // Web: content centred in a min-h-screen column, toggles top-right, footer at the end.
        child: LayoutBuilder(
          builder: (context, viewport) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: viewport.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [LanguageToggle(), SizedBox(width: 8), ThemeToggle()],
                    ),
                  ),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 384 + 48),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: content,
                        ),
                      ),
                    ),
                  ),
                  const LoginFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
