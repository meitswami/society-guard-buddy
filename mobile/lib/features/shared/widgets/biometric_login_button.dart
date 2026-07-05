import 'package:flutter/material.dart';

import '../../../core/theme/kutumbika_brand_theme.dart';
import '../../../services/biometric_service.dart';

class BiometricLoginButton extends StatefulWidget {
  const BiometricLoginButton({
    super.key,
    required this.enabled,
    required this.onPressed,
    this.loading = false,
  });

  final bool enabled;
  final VoidCallback onPressed;
  final bool loading;

  @override
  State<BiometricLoginButton> createState() => _BiometricLoginButtonState();
}

class _BiometricLoginButtonState extends State<BiometricLoginButton> {
  final _biometric = BiometricService();
  bool? _supported;

  @override
  void initState() {
    super.initState();
    _biometric.isDeviceSupported().then((v) {
      if (mounted) setState(() => _supported = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_supported != true || !widget.enabled) return const SizedBox.shrink();

    final brand = KutumbikaBrandTheme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: OutlinedButton(
        onPressed: widget.loading ? null : widget.onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(72),
          side: BorderSide(color: brand.primary.withValues(alpha: 0.35), width: 2),
          backgroundColor: brand.primary.withValues(alpha: 0.05),
        ),
        child: widget.loading
            ? SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: brand.primary),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.fingerprint, size: 32, color: brand.primary),
                  const SizedBox(height: 4),
                  Text(
                    'Login with fingerprint',
                    style: TextStyle(
                      color: brand.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
