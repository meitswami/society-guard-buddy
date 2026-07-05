import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/config/env.dart';
import '../core/firebase/firebase_bootstrap.dart';

class FirebaseOtpFailure implements Exception {
  FirebaseOtpFailure(this.message);
  final String message;
}

/// Firebase phone verification only — app session uses Supabase tables (same as web).
class FirebaseOtpService {
  String? _verificationId;
  ConfirmationResult? _webConfirmation;

  bool get isAvailable => Env.isFirebaseConfigured;

  Future<void> sendOtp(String phone10Digits) async {
    if (!isAvailable) {
      throw FirebaseOtpFailure('Firebase not configured in mobile/.env');
    }
    await FirebaseBootstrap.init();

    final digits = phone10Digits.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) {
      throw FirebaseOtpFailure('Enter a valid 10-digit phone number');
    }
    final e164 = '+91${digits.length > 10 ? digits.substring(digits.length - 10) : digits}';

    if (kIsWeb) {
      // SDK creates an invisible reCAPTCHA verifier when none is passed.
      _webConfirmation = await FirebaseAuth.instance.signInWithPhoneNumber(e164);
      return;
    }

    final completer = Completer<void>();
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: e164,
      verificationCompleted: (credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
        await FirebaseAuth.instance.signOut();
        if (!completer.isCompleted) completer.complete();
      },
      verificationFailed: (e) {
        if (!completer.isCompleted) {
          completer.completeError(FirebaseOtpFailure(e.message ?? 'SMS failed'));
        }
      },
      codeSent: (verificationId, _) {
        _verificationId = verificationId;
        if (!completer.isCompleted) completer.complete();
      },
      codeAutoRetrievalTimeout: (verificationId) {
        _verificationId = verificationId;
      },
    );
    return completer.future;
  }

  Future<String> verifyOtp(String code) async {
    if (kIsWeb) {
      final confirmation = _webConfirmation;
      if (confirmation == null) {
        throw FirebaseOtpFailure('Request OTP first');
      }
      await confirmation.confirm(code);
      final phone = FirebaseAuth.instance.currentUser?.phoneNumber ?? '';
      await FirebaseAuth.instance.signOut();
      return _normalizeVerifiedPhone(phone);
    }

    final verificationId = _verificationId;
    if (verificationId == null) {
      throw FirebaseOtpFailure('Request OTP first');
    }
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: code,
    );
    await FirebaseAuth.instance.signInWithCredential(credential);
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber ?? '';
    await FirebaseAuth.instance.signOut();
    return _normalizeVerifiedPhone(phone);
  }

  String _normalizeVerifiedPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length <= 10) return digits;
    return digits.substring(digits.length - 10);
  }
}
