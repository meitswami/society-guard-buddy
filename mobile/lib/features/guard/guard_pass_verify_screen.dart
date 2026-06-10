import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/kutumbika_brand_theme.dart';
import '../../models/session_models.dart';
import '../../services/visitor_entry_service.dart';
import '../../services/visitor_pass_verify_service.dart';

class GuardPassVerifyScreen extends StatefulWidget {
  const GuardPassVerifyScreen({super.key, required this.session});

  final SessionGuard session;

  @override
  State<GuardPassVerifyScreen> createState() => _GuardPassVerifyScreenState();
}

class _GuardPassVerifyScreenState extends State<GuardPassVerifyScreen> {
  final _verifyService = VisitorPassVerifyService();
  final _entryService = VisitorEntryService();
  final _otpCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  VerifiedPass? _verified;

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    setState(() {
      _loading = true;
      _error = null;
      _verified = null;
    });
    try {
      final pass = await _verifyService.verifyAndUse(
        societyId: widget.session.societyId,
        otp: _otpCtrl.text.trim(),
      );
      setState(() => _verified = pass);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _registerEntry() async {
    final pass = _verified;
    if (pass == null) return;

    try {
      await _entryService.registerVisitor(
        societyId: widget.session.societyId,
        guardId: widget.session.guard.guardId,
        guardName: widget.session.guard.name,
        name: pass.guestName,
        phone: pass.guestPhone.isNotEmpty ? pass.guestPhone : '0000000000',
        flatNumber: pass.flatNumber,
        purpose: 'Visitor pass (OTP verified)',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${pass.guestName} registered')),
      );
      setState(() {
        _verified = null;
        _otpCtrl.clear();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not register entry')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = KutumbikaBrandTheme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Verify visitor pass')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Enter the 6-digit OTP from the resident\'s visitor pass.'),
            const SizedBox(height: 16),
            TextField(
              controller: _otpCtrl,
              decoration: const InputDecoration(
                labelText: 'OTP',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            if (_verified != null) ...[
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  title: Text(_verified!.guestName),
                  subtitle: Text('Flat ${_verified!.flatNumber}'),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _registerEntry,
                style: FilledButton.styleFrom(backgroundColor: brand.primary),
                child: const Text('Register gate entry'),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loading ? null : _verify,
              style: FilledButton.styleFrom(backgroundColor: brand.primary, minimumSize: const Size.fromHeight(48)),
              child: _loading
                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Verify OTP'),
            ),
          ],
        ),
      ),
    );
  }
}
