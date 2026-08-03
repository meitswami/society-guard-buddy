import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/kutumbika_brand_theme.dart';
import '../../../services/auth_service.dart';
import '../../../services/firebase_otp_service.dart';
import '../../../services/geofence_service.dart';
import '../../../services/resident_login_service.dart';

class OtpLoginPanel extends StatefulWidget {
  const OtpLoginPanel({
    super.key,
    required this.onVerified,
    this.enabled = true,
    this.initialPhone = '',
    this.onPhoneChanged,
  });

  final Future<void> Function(String normalizedPhone) onVerified;
  final bool enabled;
  final String initialPhone;
  final ValueChanged<String>? onPhoneChanged;

  @override
  State<OtpLoginPanel> createState() => _OtpLoginPanelState();
}

class _OtpLoginPanelState extends State<OtpLoginPanel> {
  late final TextEditingController _phoneController;
  final _otpController = TextEditingController();
  final _otpService = FirebaseOtpService();

  bool _codeSent = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final digits = widget.initialPhone.replaceAll(RegExp(r'\D'), '');
    _phoneController = TextEditingController(
      text: digits.length > 10 ? digits.substring(digits.length - 10) : digits,
    );
    _phoneController.addListener(_emitPhone);
  }

  void _emitPhone() {
    widget.onPhoneChanged?.call(_phoneController.text.trim());
  }

  @override
  void didUpdateWidget(covariant OtpLoginPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPhone != oldWidget.initialPhone &&
        _phoneController.text.isEmpty &&
        widget.initialPhone.isNotEmpty) {
      final digits = widget.initialPhone.replaceAll(RegExp(r'\D'), '');
      _phoneController.text =
          digits.length > 10 ? digits.substring(digits.length - 10) : digits;
    }
  }

  @override
  void dispose() {
    _phoneController.removeListener(_emitPhone);
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      await _otpService.sendOtp(_phoneController.text.trim());
      setState(() => _codeSent = true);
    } on FirebaseOtpFailure catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Could not send OTP');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verify() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final phone = await _otpService.verifyOtp(_otpController.text.trim());
      await widget.onVerified(phone);
    } on FirebaseOtpFailure catch (e) {
      setState(() => _error = e.message);
    } on AuthFailure catch (e) {
      setState(() => _error = e.message);
    } on GeofenceFailure catch (e) {
      setState(() => _error = e.message);
    } on ResidentLoginFailure catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Invalid OTP');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = KutumbikaBrandTheme.of(context);

    if (!_otpService.isAvailable) {
      return Text(
        'Add FIREBASE_* keys to mobile/.env for OTP login.',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _phoneController,
          enabled: widget.enabled && !_codeSent,
          decoration: const InputDecoration(
            labelText: 'Phone (+91)',
            border: OutlineInputBorder(),
            prefixText: '+91 ',
          ),
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 10,
          // Autofilled value stays editable until OTP is sent (then use Change phone).
          autofillHints: const [AutofillHints.telephoneNumber],
        ),
        if (_codeSent) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _otpController,
            decoration: const InputDecoration(
              labelText: '6-digit OTP',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            maxLength: 6,
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 12),
        FilledButton(
          onPressed: !widget.enabled || _loading
              ? null
              : (_codeSent ? _verify : _send),
          style: FilledButton.styleFrom(
            backgroundColor: brand.primary,
            minimumSize: const Size.fromHeight(48),
          ),
          child: _loading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(_codeSent ? 'Verify OTP' : 'Send OTP'),
        ),
        if (_codeSent)
          TextButton(
            onPressed: _loading
                ? null
                : () => setState(() {
                      _codeSent = false;
                      _otpController.clear();
                    }),
            child: const Text('Change phone number'),
          ),
      ],
    );
  }
}
