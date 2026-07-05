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
  });

  final Future<void> Function(String normalizedPhone) onVerified;
  final bool enabled;

  @override
  State<OtpLoginPanel> createState() => _OtpLoginPanelState();
}

class _OtpLoginPanelState extends State<OtpLoginPanel> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _otpService = FirebaseOtpService();

  bool _codeSent = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
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
