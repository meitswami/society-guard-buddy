import 'package:flutter/material.dart';

import '../../../services/biometric_service.dart';

/// Blocks the app until biometric unlock when enabled and user is logged in.
class BiometricGate extends StatefulWidget {
  const BiometricGate({super.key, required this.child, required this.locked});

  final Widget child;
  final bool locked;

  @override
  State<BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends State<BiometricGate> {
  final _biometric = BiometricService();
  bool _unlocked = false;
  bool _checking = true;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(BiometricGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.locked) {
      setState(() => _unlocked = true);
    } else if (!oldWidget.locked && widget.locked) {
      setState(() => _unlocked = false);
      _tryUnlock();
    }
  }

  Future<void> _init() async {
    if (!widget.locked) {
      setState(() {
        _unlocked = true;
        _checking = false;
      });
      return;
    }

    _biometricEnabled = await _biometric.isEnabled();
    if (!_biometricEnabled) {
      setState(() {
        _unlocked = true;
        _checking = false;
      });
      return;
    }

    setState(() => _checking = false);
    await _tryUnlock();
  }

  Future<void> _tryUnlock() async {
    final ok = await _biometric.authenticate();
    if (!mounted) return;
    setState(() => _unlocked = ok);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.locked || !_biometricEnabled) return widget.child;

    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_unlocked) return widget.child;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.fingerprint, size: 72),
              const SizedBox(height: 16),
              const Text('Unlock Kutumbika', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _tryUnlock,
                icon: const Icon(Icons.lock_open),
                label: const Text('Use biometrics'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
