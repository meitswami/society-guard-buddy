import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/ui/ui.dart';
import 'data/login_logic.dart';
import 'data/password_reset_service.dart';

/// Port of web `PasswordResetFlow` (full-screen overlay on the login page):
/// find account by phone / ID or email → 6-digit code by e-mail → new password;
/// accounts without e-mail can ask the society admin (notification).
class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({super.key, required this.userType, this.societyId, this.service});

  final ResetUserType userType;

  /// Account lookup is limited to this society (recommended for multi-society installs).
  final String? societyId;
  final PasswordResetService? service;

  static Future<void> open(BuildContext context, {required ResetUserType userType, String? societyId}) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => PasswordResetScreen(userType: userType, societyId: societyId)),
      );

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

enum _Step { input, token, done, noEmail }

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  late final PasswordResetService _svc = widget.service ?? PasswordResetService();
  final _identifier = TextEditingController();
  final _token = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();

  _Step _step = _Step.input;
  ResetMethod _method = ResetMethod.phone;
  bool _loading = false;
  bool _askAdminLoading = false;
  String _resetToken = '';
  ResetAccount? _account;

  ResetUserType get _type => widget.userType;

  @override
  void dispose() {
    _identifier.dispose();
    _token.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _toastError(String en, String hi) => AppFeedback.toast(context, context.tr(en, hi), tone: BadgeTone.alert);
  void _toastOk(String en, String hi) => AppFeedback.toast(context, context.tr(en, hi), tone: BadgeTone.success);

  Future<void> _requestReset() async {
    final identifier = _identifier.text;
    if (identifier.isEmpty) {
      _method == ResetMethod.email
          ? _toastError('Enter your email', 'अपना ई-मेल दर्ज करें')
          : _toastError('Enter your phone number', 'अपना फोन नंबर दर्ज करें');
      return;
    }
    setState(() => _loading = true);
    try {
      final account = await _svc.findAccount(userType: _type, method: _method, identifier: identifier, societyId: widget.societyId);
      if (!mounted) return;
      if (account == null) {
        _toastError('Account not found', 'खाता नहीं मिला');
        return;
      }
      _account = account;
      if (!account.hasEmail) {
        setState(() => _step = _Step.noEmail);
        return;
      }
      _resetToken = await _svc.createResetToken(userType: _type, account: account);
      if (!mounted) return;
      _toastOk('Reset code sent to your email', 'रीसेट कोड आपके ई-मेल पर भेजा गया');
      setState(() => _step = _Step.token);
    } catch (_) {
      if (mounted) AppFeedback.toast(context, context.t('login.connectionProblem'), tone: BadgeTone.alert);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyAndReset() async {
    final problem = validateResetInput(
      token: _token.text,
      expectedToken: _resetToken,
      newPassword: _newPassword.text,
      confirmPassword: _confirmPassword.text,
    );
    switch (problem) {
      case ResetPasswordProblem.invalidCode:
        return _toastError('Invalid code', 'गलत कोड');
      case ResetPasswordProblem.tooShort:
        return _toastError('Password must be at least 4 characters', 'कूटशब्द कम से कम 4 अक्षरों का होना चाहिए');
      case ResetPasswordProblem.mismatch:
        return _toastError('Passwords do not match', 'कूटशब्द मेल नहीं खाते');
      case null:
        break;
    }
    final account = _account;
    if (account == null) return;
    setState(() => _loading = true);
    try {
      final failed = await _svc.resetPassword(
        userType: _type,
        userId: account.id,
        token: _token.text,
        newPassword: _newPassword.text,
        identifier: _identifier.text,
        societyId: widget.societyId,
      );
      if (!mounted) return;
      if (failed != null) {
        _toastError('Token expired or invalid', 'कोड की समय-सीमा समाप्त या अमान्य');
        return;
      }
      _toastOk('Password reset successfully!', 'कूटशब्द सफलतापूर्वक रीसेट हुआ!');
      setState(() => _step = _Step.done);
    } catch (_) {
      if (mounted) AppFeedback.toast(context, context.t('login.connectionProblem'), tone: BadgeTone.alert);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _askAdmin() async {
    final account = _account;
    if (account == null) return;
    setState(() => _askAdminLoading = true);
    try {
      await _svc.askAdminToReset(userType: _type, account: account, identifier: _identifier.text, societyId: widget.societyId);
      if (!mounted) return;
      _toastOk('Request sent to admin! They will reset your password.', 'अनुरोध प्रशासक को भेजा गया! वे आपका कूटशब्द रीसेट करेंगे।');
      setState(() => _step = _Step.done);
    } catch (_) {
      if (mounted) AppFeedback.toast(context, context.t('login.connectionProblem'), tone: BadgeTone.alert);
    } finally {
      if (mounted) setState(() => _askAdminLoading = false);
    }
  }

  (IconData, String, String) _header(BuildContext c) => switch (_step) {
        _Step.input => (
            Icons.mail_outline,
            c.tr('Reset Password', 'कूटशब्द रीसेट करें'),
            c.tr('Find your account by email or phone', 'ई-मेल या फोन से अपना खाता खोजें'),
          ),
        _Step.token => (
            Icons.vpn_key_outlined,
            c.tr('Enter Reset Code', 'रीसेट कोड दर्ज करें'),
            c.tr('Check your email for the code', 'कोड के लिए अपना ई-मेल देखें'),
          ),
        _Step.noEmail => (
            Icons.warning_amber_rounded,
            c.tr('No Email Found', 'कोई ई-मेल नहीं मिला'),
            c.tr('Your account has no email attached', 'आपके खाते से कोई ई-मेल जुड़ा नहीं है'),
          ),
        _Step.done => (
            Icons.vpn_key_outlined,
            c.tr('Done!', 'हो गया!'),
            c.tr('Password has been reset', 'कूटशब्द रीसेट हो गया है'),
          ),
      };

  String get _phoneTabLabel => switch (_type) {
        ResetUserType.admin => context.t('admin.adminId'),
        ResetUserType.guard => context.tr('Guard ID / Phone', 'गार्ड पहचान / फोन'),
        ResetUserType.resident => context.t('common.phone'),
      };

  String get _placeholder {
    if (_method == ResetMethod.email) return context.tr('Email address', 'ई-मेल पता');
    return switch (_type) {
      ResetUserType.admin => context.t('admin.adminId'),
      ResetUserType.guard => context.tr('Guard ID or 10-digit phone', 'गार्ड पहचान या 10 अंकों का फोन'),
      ResetUserType.resident => context.tr('10-digit phone number', '10 अंकों का फोन नंबर'),
    };
  }

  Widget _methodButton(ResetMethod m, IconData icon, String label) {
    final t = context.tokens;
    final active = _method == m;
    return Expanded(
      child: Material(
        color: active ? t.primary : t.secondary,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          onTap: () => setState(() {
            _method = m;
            _identifier.clear();
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: active ? t.primaryForeground : t.secondaryForeground),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: active ? t.primaryForeground : t.secondaryForeground),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _inputStep() {
    final residentPhone = _method == ResetMethod.phone && _type == ResetUserType.resident;
    return [
      Row(
        children: [
          _methodButton(ResetMethod.phone, Icons.phone_outlined, _phoneTabLabel),
          const SizedBox(width: 8),
          _methodButton(ResetMethod.email, Icons.mail_outline, context.tr('Email', 'ई-मेल')),
        ],
      ),
      const SizedBox(height: 16),
      AppTextField(
        controller: _identifier,
        hint: _placeholder,
        caps: false,
        keyboardType:
            _method == ResetMethod.email ? TextInputType.emailAddress : (residentPhone ? TextInputType.phone : TextInputType.text),
        maxLength: residentPhone ? 10 : null,
        inputFormatters: [_ResetIdentifierFormatter(method: _method, userType: _type)],
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _requestReset(),
      ),
      const SizedBox(height: 16),
      AppButton(
        label: _loading
            ? context.tr('Finding account...', 'खाता खोजा जा रहा है...')
            : context.tr('Find Account & Send Code', 'खाता खोजें और कोड भेजें'),
        loading: _loading,
        onPressed: _requestReset,
      ),
    ];
  }

  List<Widget> _noEmailStep() {
    final t = context.tokens;
    final account = _account;
    final flat = account?.flatNumber ?? '';
    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTokens.tint(t.warning, 0.10),
          border: Border.all(color: AppTokens.tint(t.warning, 0.3)),
          borderRadius: BorderRadius.circular(AppTokens.radius),
        ),
        child: Column(
          children: [
            Text.rich(
              TextSpan(children: [
                TextSpan(text: account?.name ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                if (flat.isNotEmpty) TextSpan(text: context.tr(' (Flat $flat)', ' (फ्लैट $flat)')),
              ]),
              textAlign: TextAlign.center,
              style: AppText.body(context),
            ),
            const SizedBox(height: 4),
            Text(
              context.tr(
                'No email is linked to this account. You can ask your admin to reset your password.',
                'इस खाते से कोई ई-मेल जुड़ा नहीं है। आप प्रशासक से अपना कूटशब्द रीसेट करने का अनुरोध कर सकते हैं।',
              ),
              textAlign: TextAlign.center,
              style: AppText.caption(context),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      AppButton(
        icon: Icons.mail_outline,
        label: _askAdminLoading
            ? context.tr('Sending request...', 'अनुरोध भेजा जा रहा है...')
            : context.tr('Ask Admin to Change Password', 'प्रशासक से कूटशब्द बदलने को कहें'),
        loading: _askAdminLoading,
        onPressed: _askAdmin,
      ),
      const SizedBox(height: 8),
      Center(
        child: TextButton(
          onPressed: () => setState(() {
            _step = _Step.input;
            _identifier.clear();
          }),
          style: TextButton.styleFrom(foregroundColor: t.mutedForeground, textStyle: const TextStyle(fontSize: 12)),
          child: Text(context.tr('Try a different account', 'दूसरा खाता आज़माएँ'),
              style: const TextStyle(decoration: TextDecoration.underline)),
        ),
      ),
    ];
  }

  List<Widget> _tokenStep() => [
        TextField(
          controller: _token,
          maxLength: 6,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          style: AppText.mono(context, size: 18).copyWith(letterSpacing: 6),
          decoration: InputDecoration(counterText: '', hintText: context.tr('6-digit code', '6 अंकों का कोड')),
        ),
        const SizedBox(height: 16),
        AppTextField(controller: _newPassword, obscure: true, hint: context.tr('New Password', 'नया कूटशब्द')),
        const SizedBox(height: 16),
        AppTextField(
          controller: _confirmPassword,
          obscure: true,
          hint: context.tr('Confirm Password', 'कूटशब्द की पुष्टि करें'),
          onSubmitted: (_) => _verifyAndReset(),
        ),
        const SizedBox(height: 16),
        AppButton(
          label: _loading ? context.tr('Resetting...', 'रीसेट हो रहा है...') : context.tr('Reset Password', 'कूटशब्द रीसेट करें'),
          loading: _loading,
          onPressed: _verifyAndReset,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (icon, title, subtitle) = _header(context);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight - 48),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 384),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => Navigator.of(context).maybePop(),
                          style: TextButton.styleFrom(
                            foregroundColor: t.mutedForeground,
                            padding: EdgeInsets.zero,
                            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
                          ),
                          icon: const Icon(Icons.arrow_back, size: 16),
                          label: Text(context.tr('Back to Login', 'प्रवेश पर वापस')),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppTokens.tint(t.primary, 0.10),
                            borderRadius: BorderRadius.circular(AppTokens.radiusXl),
                          ),
                          child: Icon(icon, size: 32, color: _step == _Step.noEmail ? t.warning : t.primary),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(title, textAlign: TextAlign.center, style: AppText.pageTitle(context)),
                      const SizedBox(height: 4),
                      Text(subtitle, textAlign: TextAlign.center, style: AppText.body(context).copyWith(color: t.mutedForeground)),
                      const SizedBox(height: 32),
                      ...switch (_step) {
                        _Step.input => _inputStep(),
                        _Step.noEmail => _noEmailStep(),
                        _Step.token => _tokenStep(),
                        _Step.done => [
                            AppButton(
                              label: context.tr('Back to Login', 'प्रवेश पर वापस'),
                              onPressed: () => Navigator.of(context).maybePop(),
                            ),
                          ],
                      },
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Applies web `PasswordResetFlow` identifier rules while typing.
class _ResetIdentifierFormatter extends TextInputFormatter {
  const _ResetIdentifierFormatter({required this.method, required this.userType});

  final ResetMethod method;
  final ResetUserType userType;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final next = sanitizeResetIdentifier(method: method, userType: userType, input: newValue.text);
    if (next == newValue.text) return newValue;
    // Web guard input ignores non-matching edits only for digits > 10; otherwise uppercases.
    return TextEditingValue(text: next, selection: TextSelection.collapsed(offset: next.length));
  }
}
