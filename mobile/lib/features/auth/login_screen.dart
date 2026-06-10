import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/kutumbika_brand_theme.dart';
import '../../core/theme/kutumbika_colors.dart';
import '../../models/flat_row.dart';
import '../../models/resident_user.dart';
import '../../providers/session_provider.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_login_service.dart';
import '../../services/geofence_service.dart';
import '../../services/flat_service.dart';
import '../../services/resident_login_service.dart';
import '../../services/society_service.dart';
import '../shared/widgets/branded_background.dart';
import '../shared/widgets/branding_logo.dart';
import '../shared/widgets/biometric_login_button.dart';
import 'widgets/otp_login_panel.dart';
import 'widgets/resident_otp_onboarding.dart';

enum LoginRole { guard, admin, resident }
enum LoginMode { otp, credentials }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  List<SocietyRow> _societies = const [];
  List<FlatRow> _flats = const [];
  String? _societyId;
  String? _flatId;
  LoginRole? _role;
  LoginMode _loginMode = LoginMode.otp;
  bool _loading = false;
  bool _obscure = true;
  String? _error;
  final _residentLogin = ResidentLoginService();
  final _geofence = GeofenceService();

  @override
  void initState() {
    super.initState();
    _loadSocieties();
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSocieties() async {
    final rows = await ref.read(societyServiceProvider).fetchActiveSocieties();
    if (!mounted) return;
    setState(() => _societies = rows);
  }

  Future<void> _loadFlats() async {
    if (_societyId == null || _role != LoginRole.resident) {
      setState(() => _flats = const []);
      return;
    }
    final rows = await FlatService().fetchFlatsForSociety(_societyId!);
    if (!mounted) return;
    setState(() {
      _flats = rows;
      _flatId = null;
    });
  }

  String get _societyName =>
      _societies.where((s) => s.id == _societyId).map((s) => s.name).firstOrNull ??
      '';

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      if (_societyId == null) throw AuthFailure('Select your society');
      if (_role == null) throw AuthFailure('Select your role');
      final id = _identifierController.text.trim();
      final password = _passwordController.text;
      if (id.isEmpty || password.isEmpty) {
        throw AuthFailure('Enter ID and password');
      }

      final auth = ref.read(authServiceProvider);
      final session = ref.read(sessionProvider.notifier);

      switch (_role!) {
        case LoginRole.resident:
          if (_flatId == null) throw AuthFailure('Select your flat');
          final resident = await auth.loginResident(
            societyId: _societyId!,
            flatId: _flatId!,
            identifier: id,
            password: password,
          );
          await session.loginResident(
            societyId: _societyId!,
            societyName: _societyName,
            resident: resident,
          );
        case LoginRole.guard:
          await _geofence.isWithinGeofence(_societyId!);
          final guard = await auth.loginGuard(
            societyId: _societyId!,
            guardId: id,
            password: password,
          );
          final shiftId = await ref.read(guardSessionServiceProvider).startShift(
                societyId: _societyId!,
                guard: guard,
              );
          if (shiftId == null) throw AuthFailure('Could not start guard shift');
          await session.loginGuard(
            societyId: _societyId!,
            societyName: _societyName,
            guard: guard,
            shiftId: shiftId,
          );
        case LoginRole.admin:
          final admin = await auth.loginAdmin(
            societyId: _societyId!,
            adminId: id,
            password: password,
          );
          await session.loginAdmin(
            societyId: _societyId!,
            societyName: _societyName,
            admin: admin,
          );
      }
    } on AuthFailure catch (e) {
      setState(() => _error = e.message);
    } on GeofenceFailure catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Login failed. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onOtpVerified(String phone) async {
    if (_societyId == null) throw AuthFailure('Select your society');
    if (_role == null) throw AuthFailure('Select your role');
    if (_role == LoginRole.admin) {
      throw AuthFailure('Admin must use ID & password');
    }

    final session = ref.read(sessionProvider.notifier);

    if (_role == LoginRole.guard) {
      await _geofence.isWithinGeofence(_societyId!);
      final guard = await _residentLogin.findGuardForOtp(
        phone: phone,
        societyId: _societyId!,
      );
      final shiftId = await ref.read(guardSessionServiceProvider).startShift(
            societyId: _societyId!,
            guard: guard,
          );
      if (shiftId == null) throw AuthFailure('Could not start guard shift');
      await session.loginGuard(
        societyId: _societyId!,
        societyName: _societyName,
        guard: guard,
        shiftId: shiftId,
      );
      return;
    }

    if (_flatId == null) throw AuthFailure('Select your flat');
    final flatNumber = _flats.where((f) => f.id == _flatId).map((f) => f.flatNumber).firstOrNull ?? '';

    ResidentUser residentUser;
    try {
      residentUser = await _residentLogin.findResidentForOtp(
        phone: phone,
        societyId: _societyId!,
        flatId: _flatId!,
      );
    } on ResidentLoginFailure {
      if (!mounted) throw AuthFailure('Setup cancelled');
      final onboarded = await ResidentOtpOnboarding.run(
        context,
        phone: phone,
        flatId: _flatId!,
        flatNumber: flatNumber,
      );
      if (onboarded == null) throw AuthFailure('Setup cancelled');
      residentUser = onboarded;
    }

    await session.loginResident(
      societyId: _societyId!,
      societyName: _societyName,
      resident: residentUser,
    );
  }

  String? get _biometricRole {
    return switch (_role) {
      LoginRole.resident => 'resident',
      LoginRole.guard => 'guard',
      _ => null,
    };
  }

  bool get _showBiometricLogin =>
      _societyId != null &&
      _biometricRole != null &&
      (_role != LoginRole.resident || _flatId != null);

  Future<void> _biometricLogin() async {
    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      if (_societyId == null || _biometricRole == null) {
        throw BiometricLoginFailure('Select society and role first');
      }
      if (_role == LoginRole.resident && _flatId == null) {
        throw BiometricLoginFailure('Select your flat');
      }

      final result = await BiometricLoginService().loginWithBiometric(
        societyId: _societyId!,
        role: _biometricRole!,
        flatId: _flatId,
      );

      final session = ref.read(sessionProvider.notifier);
      switch (result) {
        case BiometricLoginResident(
            :final societyId,
            :final societyName,
            :final resident,
          ):
          await session.loginResident(
            societyId: societyId,
            societyName: societyName,
            resident: resident,
          );
        case BiometricLoginGuard(
            :final societyId,
            :final societyName,
            :final guard,
            :final shiftId,
          ):
          await session.loginGuard(
            societyId: societyId,
            societyName: societyName,
            guard: guard,
            shiftId: shiftId,
          );
        case BiometricLoginAdmin():
          throw BiometricLoginFailure('Admin must use ID and password');
      }
    } on BiometricLoginFailure catch (e) {
      setState(() => _error = e.message);
    } on GeofenceFailure catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Biometric login failed');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = KutumbikaBrandTheme.of(context);

    return Scaffold(
      body: BrandedBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  const BrandingLogo(size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          brand.appName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: brand.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          brand.tagline,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: KutumbikaColors.textMuted,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                'Sign in',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _societyId,
                decoration: const InputDecoration(
                  labelText: 'Society',
                  border: OutlineInputBorder(),
                ),
                items: _societies
                    .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                    .toList(),
                onChanged: (v) {
                  setState(() => _societyId = v);
                  _loadFlats();
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<LoginRole>(
                value: _role,
                decoration: const InputDecoration(
                  labelText: 'I am a',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: LoginRole.resident, child: Text('Resident')),
                  DropdownMenuItem(value: LoginRole.guard, child: Text('Guard')),
                  DropdownMenuItem(value: LoginRole.admin, child: Text('Admin')),
                ],
                onChanged: (v) {
                  setState(() {
                    _role = v;
                    if (v == LoginRole.admin) _loginMode = LoginMode.credentials;
                  });
                  _loadFlats();
                },
              ),
              if (_role != null && _role != LoginRole.admin) ...[
                const SizedBox(height: 12),
                SegmentedButton<LoginMode>(
                  segments: const [
                    ButtonSegment(value: LoginMode.otp, label: Text('OTP')),
                    ButtonSegment(value: LoginMode.credentials, label: Text('Password')),
                  ],
                  selected: {_loginMode},
                  onSelectionChanged: (s) => setState(() => _loginMode = s.first),
                ),
              ],
              if (_role == LoginRole.resident) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _flatId,
                  decoration: const InputDecoration(
                    labelText: 'Flat',
                    border: OutlineInputBorder(),
                  ),
                  items: _flats
                      .map((f) => DropdownMenuItem(
                            value: f.id,
                            child: Text(f.flatNumber),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _flatId = v),
                ),
              ],
              const SizedBox(height: 16),
              if (_showBiometricLogin)
                BiometricLoginButton(
                  enabled: !_loading,
                  loading: _loading,
                  onPressed: _biometricLogin,
                ),
              if (_error != null && _showBiometricLogin) ...[
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                const SizedBox(height: 12),
              ],
              if (_role != null &&
                  _loginMode == LoginMode.otp &&
                  _role != LoginRole.admin)
                OtpLoginPanel(
                  enabled: _societyId != null &&
                      (_role != LoginRole.resident || _flatId != null),
                  onVerified: (phone) async {
                    setState(() {
                      _error = null;
                      _loading = true;
                    });
                    try {
                      await _onOtpVerified(phone);
                    } on AuthFailure catch (e) {
                      setState(() => _error = e.message);
                    } on ResidentLoginFailure catch (e) {
                      setState(() => _error = e.message);
                    } catch (e) {
                      setState(() => _error = 'OTP login failed');
                    } finally {
                      if (mounted) setState(() => _loading = false);
                    }
                  },
                )
              else if (_role != null) ...[
                TextField(
                  controller: _identifierController,
                  decoration: InputDecoration(
                    labelText: _role == LoginRole.resident
                        ? 'Phone number'
                        : _role == LoginRole.guard
                            ? 'Guard ID'
                            : 'Admin ID',
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: _role == LoginRole.resident
                      ? TextInputType.phone
                      : TextInputType.text,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: brand.primary,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Sign in'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
