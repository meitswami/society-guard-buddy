import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/firebase/firebase_bootstrap.dart';

class FirebaseOtpFailure implements Exception {
  FirebaseOtpFailure(this.message, {this.code});

  final String message;

  /// Firebase error code without the `auth/` prefix (e.g. `invalid-verification-code`),
  /// or one of the local codes `not-configured`, `invalid-phone`, `session-missing`.
  final String? code;

  @override
  String toString() => code == null ? message : '$message ($code)';
}

/// Firebase phone verification only — the app session uses Supabase tables (same as web
/// `OTPLoginFlow`, which signs out of Firebase right after the code is confirmed).
///
/// Android may verify the number without the user typing the code (instant verification or
/// SMS auto-retrieval, the native counterpart of the web WebOTP auto-read). Pass
/// [sendOtp]'s `onAutoVerified` to be told when that happens.
class FirebaseOtpService {
  String? _verificationId;
  int? _resendToken;
  ConfirmationResult? _webConfirmation;
  String? _phone;

  /// Bumped on every send / reset so callbacks from an older request are ignored.
  int _generation = 0;
  bool _consumed = false;

  bool get isAvailable => FirebaseBootstrap.isReady;

  /// True after a code was sent and before it was used.
  bool get hasPendingCode => !_consumed && (_verificationId != null || _webConfirmation != null);

  /// The 10-digit number the last code was sent to.
  String? get phone => _phone;

  static String _last10(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }

  /// Sends the SMS code to `+91<phone>`. Completes once the code was sent — or once Android
  /// verified the number by itself, in which case [onAutoVerified] is also called with the
  /// auto-read SMS code (null for instant verification without SMS).
  /// [resend] re-uses Firebase's resend token for the same number.
  Future<void> sendOtp(
    String phone10Digits, {
    void Function(String? smsCode)? onAutoVerified,
    bool resend = false,
  }) async {
    if (!isAvailable) {
      throw FirebaseOtpFailure('Firebase not configured in mobile/.env', code: 'not-configured');
    }
    await FirebaseBootstrap.init();

    final digits = _last10(phone10Digits);
    if (digits.length < 10) {
      throw FirebaseOtpFailure('Enter a valid 10-digit phone number', code: 'invalid-phone');
    }
    final e164 = '+91$digits';
    final sameNumber = _phone == digits;
    _phone = digits;
    final generation = ++_generation;
    _consumed = false;
    _verificationId = null;
    _webConfirmation = null;

    if (kIsWeb) {
      try {
        // The SDK creates an invisible reCAPTCHA verifier when none is passed.
        _webConfirmation = await FirebaseAuth.instance.signInWithPhoneNumber(e164);
      } on FirebaseAuthException catch (e) {
        throw FirebaseOtpFailure(e.message ?? 'SMS failed', code: e.code);
      }
      return;
    }

    final completer = Completer<void>();
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: e164,
        timeout: const Duration(seconds: 60),
        forceResendingToken: resend && sameNumber ? _resendToken : null,
        verificationCompleted: (credential) async {
          if (generation != _generation || _consumed) return;
          try {
            await FirebaseAuth.instance.signInWithCredential(credential);
            await FirebaseAuth.instance.signOut();
          } on FirebaseAuthException catch (e) {
            if (!completer.isCompleted) {
              completer.completeError(FirebaseOtpFailure(e.message ?? 'Verification failed', code: e.code));
            }
            return;
          }
          if (generation != _generation || _consumed) return;
          _consumed = true;
          _verificationId = null;
          if (!completer.isCompleted) completer.complete();
          onAutoVerified?.call(credential.smsCode);
        },
        verificationFailed: (e) {
          if (generation != _generation) return;
          if (!completer.isCompleted) {
            completer.completeError(FirebaseOtpFailure(e.message ?? 'SMS failed', code: e.code));
          }
        },
        codeSent: (verificationId, resendToken) {
          if (generation != _generation) return;
          _verificationId = verificationId;
          _resendToken = resendToken;
          if (!completer.isCompleted) completer.complete();
        },
        codeAutoRetrievalTimeout: (verificationId) {
          if (generation != _generation || _consumed) return;
          _verificationId ??= verificationId;
        },
      );
    } on FirebaseAuthException catch (e) {
      throw FirebaseOtpFailure(e.message ?? 'SMS failed', code: e.code);
    }
    return completer.future;
  }

  /// Confirms the typed code; returns the verified 10-digit number. Signs out of Firebase
  /// straight away (app login is resolved against Supabase tables, like web).
  Future<String> verifyOtp(String code) async {
    final smsCode = code.replaceAll(RegExp(r'\D'), '');
    try {
      if (kIsWeb) {
        final confirmation = _webConfirmation;
        if (confirmation == null || _consumed) {
          throw FirebaseOtpFailure('Session expired. Tap Resend OTP.', code: 'session-missing');
        }
        await confirmation.confirm(smsCode);
      } else {
        final verificationId = _verificationId;
        if (verificationId == null || _consumed) {
          throw FirebaseOtpFailure('Session expired. Tap Resend OTP.', code: 'session-missing');
        }
        final credential = PhoneAuthProvider.credential(verificationId: verificationId, smsCode: smsCode);
        await FirebaseAuth.instance.signInWithCredential(credential);
      }
    } on FirebaseAuthException catch (e) {
      throw FirebaseOtpFailure(e.message ?? 'Invalid code', code: e.code);
    }
    final verified = FirebaseAuth.instance.currentUser?.phoneNumber ?? '';
    _consumed = true;
    _verificationId = null;
    _webConfirmation = null;
    await signOutQuietly();
    final last10 = _last10(verified);
    return last10.length == 10 ? last10 : (_phone ?? last10);
  }

  /// Forget the pending verification (web "Change Number").
  Future<void> reset() async {
    _generation++;
    _consumed = false;
    _verificationId = null;
    _webConfirmation = null;
    await signOutQuietly();
  }

  static Future<void> signOutQuietly() async {
    if (!FirebaseBootstrap.isReady) return;
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }
}
