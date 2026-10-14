import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/ui/ui.dart';
import '../../../services/visitor_pass_verify_service.dart';
import '../gate_i18n.dart';

/// Web `OTPVerifyModal`: 6-digit resident pass code → returns the verified pass (marked used).
class OtpVerifyDialog extends StatefulWidget {
  const OtpVerifyDialog({super.key, required this.societyId});

  final String societyId;

  static Future<VerifiedPass?> show(BuildContext context,
          {required String societyId}) =>
      showDialog<VerifiedPass>(
        context: context,
        barrierDismissible: false,
        builder: (_) => OtpVerifyDialog(societyId: societyId),
      );

  @override
  State<OtpVerifyDialog> createState() => _OtpVerifyDialogState();
}

class _OtpVerifyDialogState extends State<OtpVerifyDialog> {
  final _ctrl = TextEditingController();
  final _service = VisitorPassVerifyService();
  bool _loading = false;
  String _error = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final otp = _ctrl.text;
    if (otp.length != 6) {
      setState(() => _error = context.t('otp.enterSixDigit'));
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final res = await _service.verify(societyId: widget.societyId, otp: otp);
      if (!mounted) return;
      if (res.pass != null) {
        Navigator.of(context).pop(res.pass);
        return;
      }
      setState(() {
        _loading = false;
        _error = context.t(res.errorKey ?? 'otp.invalid');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = context.gt('gate.otp.failed');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusXl),
          side: BorderSide(color: t.border)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 384),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                    color: AppTokens.tint(t.primary, 0.1),
                    shape: BoxShape.circle),
                child: Icon(Icons.key_rounded, size: 28, color: t.primary),
              ),
              const SizedBox(height: 16),
              Text(context.t('otp.verifyTitle'),
                  style: AppText.sectionTitle(context).copyWith(fontSize: 16),
                  textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(context.t('otp.verifySubtitle'),
                  style: AppText.caption(context), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              TextField(
                controller: _ctrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6)
                ],
                style: AppText.mono(context, size: 24, weight: FontWeight.w700)
                    .copyWith(letterSpacing: 12),
                decoration: InputDecoration(
                  hintText: '000000',
                  counterText: '',
                  hintStyle: AppText.mono(context,
                          size: 24,
                          weight: FontWeight.w700,
                          color: t.mutedForeground)
                      .copyWith(letterSpacing: 12),
                ),
                onSubmitted: (_) => _verify(),
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(_error,
                    style: TextStyle(fontSize: 14, color: t.destructive),
                    textAlign: TextAlign.center),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: AppButton.secondary(
                      label: context.t('common.cancel'),
                      onPressed:
                          _loading ? null : () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      label: context.t('otp.verify'),
                      icon: Icons.check_rounded,
                      loading: _loading,
                      onPressed: _verify,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
