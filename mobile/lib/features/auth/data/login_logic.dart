import 'dart:math';

import '../../../utils/phone_utils.dart';

export '../../../utils/phone_utils.dart' show normalizeLoginPhone;

/// Role picked on the unified login (web `LoginRole`; `''` ⇔ null).
enum LoginRole { guard, admin, resident }

/// Web `loginMode`: `'otp' | 'credentials'`.
enum LoginMode { otp, credentials }

LoginRole? loginRoleFromKey(String? key) => switch (key) {
      'guard' => LoginRole.guard,
      'admin' => LoginRole.admin,
      'resident' => LoginRole.resident,
      _ => null,
    };

/// Web `useShowSuperadminLogin`: the superadmin entry shows only on desktop-wide screens (≥ 1024).
bool showSuperadminEntryForWidth(double width) => width >= 1024;

/// Web `SocietyListStatus`: which message to show under the society picker
/// (null → hidden: while loading, or when the list loaded with societies).
String? societyListStatusKey({required bool loading, required String? error, required int count}) {
  if (loading || (error == null && count > 0)) return null;
  return error != null ? 'login.societiesLoadFailed' : 'login.societiesEmpty';
}

/// Phone typed into a phone box: digits only, first 10 kept (web `.replace(/\D/g,'').slice(0, 10)`).
String phoneInputDigits(String input) {
  final digits = input.replaceAll(RegExp(r'\D'), '');
  return digits.length > 10 ? digits.substring(0, 10) : digits;
}

/// Identifier used for the credential query: resident phones are normalised to the last
/// 10 digits, guard / admin ids are only trimmed (web `handleCredentialLogin`).
String credentialIdentifier(LoginRole role, String raw) {
  final idRaw = raw.trim();
  return role == LoginRole.resident ? normalizeLoginPhone(idRaw) : idRaw;
}

/// Web `showBiometric`.
bool showBiometricLogin({
  required bool deviceSupported,
  required String societyId,
  required bool superadminMode,
  required LoginRole? role,
  required String flatId,
}) =>
    deviceSupported && societyId.isNotEmpty && !superadminMode && role != null && (role != LoginRole.resident || flatId.isNotEmpty);

/// Bilingual text produced by pure helpers (the widget picks the current language).
typedef BiText = ({String en, String hi});

/// Port of web `formatFirebaseAuthError` for the native Firebase error codes
/// (FlutterFire codes have no `auth/` prefix; both forms are accepted).
BiText describeOtpError(String? code, {String? message}) {
  final c = (code ?? '').replaceFirst('auth/', '').trim();
  switch (c) {
    case 'invalid-phone-number':
    case 'invalid-phone':
      return (en: 'Invalid phone number.', hi: 'फोन नंबर अमान्य है।');
    case 'missing-phone-number':
      return (en: 'Enter a valid phone number.', hi: 'मान्य फोन नंबर दर्ज करें।');
    case 'too-many-requests':
      return (en: 'Too many attempts. Try again later.', hi: 'बहुत अधिक प्रयास। कुछ देर बाद फिर कोशिश करें।');
    case 'invalid-verification-code':
      return (en: 'Invalid code.', hi: 'गलत कोड।');
    case 'code-expired':
    case 'session-expired':
      return (en: 'Code expired. Request a new one.', hi: 'कोड की समय-सीमा समाप्त हो गई। नया कोड मँगवाएँ।');
    case 'session-missing':
    case 'invalid-verification-id':
    case 'missing-verification-id':
      return (en: 'Session expired. Tap Resend OTP.', hi: 'सत्र समाप्त हो गया। "ओटीपी फिर से भेजें" दबाएँ।');
    case 'captcha-check-failed':
    case 'web-context-cancelled':
    case 'web-context-already-presented':
      return (
        en: 'Security check failed. Close and reopen the app, then try again.',
        hi: 'सुरक्षा जाँच विफल रही। ऐप बंद करके फिर खोलें और दोबारा कोशिश करें।',
      );
    case 'invalid-app-credential':
    case 'invalid-app-credentials':
    case 'missing-client-identifier':
    case 'missing-recaptcha-token':
    case 'app-not-verified':
      return (
        en: 'App verification failed. Add this app\'s SHA-1 / SHA-256 fingerprints in Firebase → Project settings, '
            'enable Play Integrity, and allow India in Authentication → Settings → SMS region policy.',
        hi: 'ऐप सत्यापन विफल रहा। Firebase → Project settings में इस ऐप के SHA-1 / SHA-256 फ़िंगरप्रिंट जोड़ें, '
            'Play Integrity चालू करें और Authentication → Settings → SMS region policy में भारत को अनुमति दें।',
      );
    case 'operation-not-allowed':
      return (
        en: 'Phone sign-in is disabled. Enable the Phone provider in Firebase Console → Authentication → Sign-in method.',
        hi: 'फोन से प्रवेश बंद है। Firebase Console → Authentication → Sign-in method में Phone प्रदाता चालू करें।',
      );
    case 'billing-not-enabled':
      return (
        en: 'SMS requires the Firebase project on a billing-enabled (Blaze) plan.',
        hi: 'एसएमएस के लिए Firebase परियोजना बिलिंग-सक्षम (Blaze) योजना पर होनी चाहिए।',
      );
    case 'quota-exceeded':
      return (en: 'SMS quota exceeded. Contact support.', hi: 'एसएमएस सीमा समाप्त हो गई। सहायता से संपर्क करें।');
    case 'app-not-authorized':
      return (
        en: 'This app is not authorized to use Firebase Authentication with this key.',
        hi: 'यह ऐप इस कुंजी के साथ Firebase Authentication उपयोग करने के लिए अधिकृत नहीं है।',
      );
    case 'network-request-failed':
      return (en: 'Network error. Check your internet and try again.', hi: 'नेटवर्क त्रुटि। इंटरनेट जाँचें और फिर कोशिश करें।');
    case 'not-configured':
      return (
        en: 'SMS login is not configured. Add the FIREBASE_* keys to mobile/.env.',
        hi: 'एसएमएस प्रवेश कॉन्फ़िगर नहीं है। mobile/.env में FIREBASE_* कुंजियाँ जोड़ें।',
      );
    case '':
      return (en: 'Something went wrong. Try again.', hi: 'कुछ गलत हुआ। फिर कोशिश करें।');
    default:
      final m = (message ?? '').trim();
      if (m.isNotEmpty && m.length < 200) return (en: '$m ($c)', hi: '$m ($c)');
      return (en: 'Something went wrong ($c).', hi: 'कुछ गलत हुआ ($c)।');
  }
}

// ---------------------------------------------------------------------------
// Password reset (web `PasswordResetFlow`)
// ---------------------------------------------------------------------------

/// `'admin' | 'resident' | 'guard'`.
enum ResetUserType { admin, resident, guard }

/// Web method toggle: phone / ID (default) or email.
enum ResetMethod { phone, email }

ResetUserType resetUserTypeFor(LoginRole role) => switch (role) {
      LoginRole.admin => ResetUserType.admin,
      LoginRole.guard => ResetUserType.guard,
      LoginRole.resident => ResetUserType.resident,
    };

/// Web identifier `onChange`: resident phones keep 10 digits; guard input stays digits
/// (max 10) while numeric, otherwise upper-cases the guard id; admin / email are raw.
String sanitizeResetIdentifier({required ResetMethod method, required ResetUserType userType, required String input}) {
  if (method == ResetMethod.phone && userType == ResetUserType.resident) {
    return phoneInputDigits(input);
  }
  if (method == ResetMethod.phone && userType == ResetUserType.guard) {
    if (RegExp(r'^\d*$').hasMatch(input)) return input.length > 10 ? input.substring(0, 10) : input;
    return input.toUpperCase();
  }
  return input;
}

/// Guard lookup by phone uses the last 10 digits when at least 10 were typed; otherwise
/// the input is treated as a guard id (null here).
String? guardResetPhoneLast10(String identifier) {
  final digits = identifier.replaceAll(RegExp(r'\D'), '');
  final last10 = digits.length <= 10 ? digits : digits.substring(digits.length - 10);
  return last10.length >= 10 ? last10 : null;
}

/// 6-digit reset code (`Math.floor(100000 + Math.random() * 900000)`).
String generateResetCode([Random? random]) => (100000 + (random ?? Random.secure()).nextInt(900000)).toString();

enum ResetPasswordProblem { invalidCode, tooShort, mismatch }

/// Client-side checks of web `verifyAndReset` (in order).
ResetPasswordProblem? validateResetInput({
  required String token,
  required String expectedToken,
  required String newPassword,
  required String confirmPassword,
}) {
  if (token != expectedToken) return ResetPasswordProblem.invalidCode;
  if (newPassword.isEmpty || newPassword.length < 4) return ResetPasswordProblem.tooShort;
  if (newPassword != confirmPassword) return ResetPasswordProblem.mismatch;
  return null;
}

/// `notifications.message` of the "Ask admin to reset" request (English, exactly as web).
String buildResetRequestMessage({
  required String userName,
  required String userType,
  required String flatNumber,
  required String identifier,
}) {
  final where = flatNumber.isNotEmpty ? 'Flat $flatNumber' : 'ID: $identifier';
  return '$userName ($userType, $where) is requesting a password reset. They don\'t have an email set. '
      'Please reset their password from the admin panel.';
}
