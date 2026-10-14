import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/ui/ui.dart';
import '../../../services/firebase_otp_service.dart';
import '../data/login_logic.dart';
import 'otp_code_input.dart';

/// Port of web `OTPLoginFlow`: phone step (+91 box, Send OTP) → code step (6 boxes,
/// Verify & Login, Change Number, Resend countdown). Firebase only verifies the number;
/// [onVerified] resolves the app login and shows its own errors.
class OtpLoginFlow extends StatefulWidget {
  const OtpLoginFlow({
    super.key,
    required this.onVerified,
    this.onBack,
    this.title,
    this.subtitle,
    this.embedded = false,
    this.initialPhone = '',
    this.onPhoneChange,
    this.service,
  });

  /// Called with the verified 10-digit phone; the flow stays busy until it completes.
  final Future<void> Function(String phone) onVerified;
  final VoidCallback? onBack;

  /// Heading of the phone step when not [embedded] (web default "Login with OTP").
  final String? title;
  final String? subtitle;

  /// Skip the icon / title / subtitle on the phone step (the parent page shows them).
  final bool embedded;

  /// Prefill from remembered login; the field stays editable.
  final String initialPhone;
  final ValueChanged<String>? onPhoneChange;
  final FirebaseOtpService? service;

  @override
  State<OtpLoginFlow> createState() => _OtpLoginFlowState();
}

enum _Step { phone, otp }

class _OtpLoginFlowState extends State<OtpLoginFlow> {
  late final FirebaseOtpService _otp = widget.service ?? FirebaseOtpService();
  late final TextEditingController _phone = TextEditingController(text: phoneInputDigits(widget.initialPhone));
  final _code = TextEditingController();
  final _codeFocus = FocusNode();

  _Step _step = _Step.phone;
  bool _loading = false;
  BiText? _error;
  int _countdown = 0;
  Timer? _timer;
  bool _finishing = false;

  @override
  void didUpdateWidget(covariant OtpLoginFlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final digits = phoneInputDigits(widget.initialPhone);
    if (digits.isNotEmpty && digits != phoneInputDigits(oldWidget.initialPhone) && _phone.text.isEmpty) {
      _phone.text = digits;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _countdown = _countdown > 0 ? _countdown - 1 : 0);
      if (_countdown <= 0) timer.cancel();
    });
  }

  Future<void> _send() async {
    final phone = _phone.text;
    if (phone.isEmpty || phone.length < 10) {
      setState(() => _error = (en: 'Enter a valid 10-digit phone number', hi: 'मान्य 10 अंकों का फोन नंबर दर्ज करें'));
      return;
    }
    if (!_otp.isAvailable) {
      setState(() => _error = describeOtpError('not-configured'));
      return;
    }
    final resend = _step == _Step.otp;
    setState(() {
      _loading = true;
      _error = null;
    });
    var autoVerified = false;
    try {
      await _otp.sendOtp(phone, resend: resend, onAutoVerified: (smsCode) {
        autoVerified = true;
        if (!mounted) return;
        if (smsCode != null && smsCode.length == 6) _code.text = smsCode;
        unawaited(_finish(phone));
      });
      if (!mounted || autoVerified) return;
      setState(() {
        _step = _Step.otp;
        _code.clear();
      });
      _startCountdown();
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _codeFocus.requestFocus();
      });
    } on FirebaseOtpFailure catch (e) {
      if (mounted) setState(() => _error = describeOtpError(e.code, message: e.message));
    } catch (_) {
      if (mounted) setState(() => _error = describeOtpError(null));
    } finally {
      if (mounted && !_finishing) setState(() => _loading = false);
    }
  }

  Future<void> _verify(String code) async {
    if (_loading || _finishing) return;
    if (code.length != 6) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _otp.verifyOtp(code);
    } on FirebaseOtpFailure catch (e) {
      if (mounted) {
        setState(() {
          _error = describeOtpError(e.code, message: e.message);
          _loading = false;
        });
      }
      return;
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = describeOtpError(null);
          _loading = false;
        });
      }
      return;
    }
    await _finish(_phone.text);
  }

  /// Number verified (typed code or Android auto-verification) → app login.
  Future<void> _finish(String phone) async {
    if (_finishing) return;
    _finishing = true;
    if (mounted) setState(() => _loading = true);
    try {
      await widget.onVerified(phone);
    } catch (_) {
      if (mounted) setState(() => _error = describeOtpError(null));
    } finally {
      _finishing = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeNumber() {
    _timer?.cancel();
    setState(() {
      _step = _Step.phone;
      _code.clear();
      _error = null;
      _countdown = 0;
    });
    unawaited(_otp.reset());
  }

  Widget _errorText(BuildContext context) {
    final e = _error;
    if (e == null) return const SizedBox.shrink();
    return Text(
      context.tr(e.en, e.hi),
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 14, color: context.tokens.destructive),
    );
  }

  Widget _iconTile(BuildContext context, IconData icon) {
    final t = context.tokens;
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(color: AppTokens.tint(t.primary, 0.10), borderRadius: BorderRadius.circular(AppTokens.radiusXl)),
      child: Icon(icon, size: 32, color: t.primary),
    );
  }

  Widget _phoneStep(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.embedded) ...[
          Center(child: _iconTile(context, Icons.phone_outlined)),
          const SizedBox(height: 12),
          Text(
            widget.title ?? context.tr('Login with OTP', 'ओटीपी से प्रवेश'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: t.foreground),
          ),
          const SizedBox(height: 4),
          Text(
            widget.subtitle ?? context.tr('Enter your registered phone number', 'अपना पंजीकृत फोन नंबर दर्ज करें'),
            textAlign: TextAlign.center,
            style: AppText.caption(context),
          ),
          const SizedBox(height: 32),
        ],
        FieldLabel(context.tr('Phone Number', 'फोन नंबर')),
        Row(
          children: [
            Container(
              width: 64,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: t.input,
                border: Border.all(color: t.border),
                borderRadius: BorderRadius.circular(AppTokens.radiusSm),
              ),
              child: Text('+91', style: AppText.mono(context, size: 14, color: t.mutedForeground)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _phone,
                enabled: !_loading,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumberNational],
                maxLength: 10,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                style: AppText.mono(context, size: 14),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                onChanged: (v) => widget.onPhoneChange?.call(phoneInputDigits(v)),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: context.tr('10-digit number', '10 अंकों का नंबर'),
                ),
              ),
            ),
          ],
        ),
        if (_error != null) ...[const SizedBox(height: 16), _errorText(context)],
        const SizedBox(height: 16),
        AppButton(
          label: context.tr('Send OTP', 'ओटीपी भेजें'),
          loading: _loading,
          onPressed: _send,
        ),
        if (widget.onBack != null) ...[
          const SizedBox(height: 4),
          Center(
            child: TextButton.icon(
              onPressed: widget.onBack,
              style: TextButton.styleFrom(foregroundColor: t.mutedForeground, textStyle: const TextStyle(fontSize: 12)),
              icon: const Icon(Icons.arrow_back, size: 12),
              label: Text(context.tr('Back', 'वापस'), style: const TextStyle(decoration: TextDecoration.underline)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _otpStep(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: _iconTile(context, Icons.sms_outlined)),
        const SizedBox(height: 12),
        Text(
          context.tr('Verify OTP', 'ओटीपी सत्यापित करें'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: t.foreground),
        ),
        const SizedBox(height: 4),
        Text(
          context.tr('Enter the 6-digit code sent to +91 ${_phone.text}', '+91 ${_phone.text} पर भेजा गया 6 अंकों का कोड दर्ज करें'),
          textAlign: TextAlign.center,
          style: AppText.caption(context),
        ),
        const SizedBox(height: 32),
        OtpCodeInput(
          controller: _code,
          focusNode: _codeFocus,
          enabled: !_loading,
          onCompleted: _verify,
        ),
        if (_error != null) ...[const SizedBox(height: 16), _errorText(context)],
        const SizedBox(height: 16),
        ListenableBuilder(
          listenable: _code,
          builder: (context, _) => AppButton(
            label: context.tr('Verify & Login', 'सत्यापित करें और प्रवेश करें'),
            loading: _loading,
            onPressed: _code.text.length == 6 ? () => _verify(_code.text) : null,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InkWell(
              onTap: _loading ? null : _changeNumber,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back, size: 12, color: t.mutedForeground),
                    const SizedBox(width: 4),
                    Text(
                      context.tr('Change Number', 'नंबर बदलें'),
                      style: TextStyle(fontSize: 12, color: t.mutedForeground, decoration: TextDecoration.underline),
                    ),
                  ],
                ),
              ),
            ),
            InkWell(
              onTap: _countdown > 0 || _loading ? null : _send,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  _countdown > 0
                      ? context.tr('Resend in ${_countdown}s', '$_countdown सेकंड में फिर से भेजें')
                      : context.tr('Resend OTP', 'ओटीपी फिर से भेजें'),
                  style: TextStyle(
                    fontSize: 12,
                    color: _countdown > 0 ? t.mutedForeground : t.primary,
                    decoration: _countdown > 0 ? null : TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: KeyedSubtree(
        key: ValueKey(_step),
        child: _step == _Step.phone ? _phoneStep(context) : _otpStep(context),
      ),
    );
  }
}
