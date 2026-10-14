import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/supabase/db.dart';

/// Onboarding price shown on the signup page (edge function `base_price_inr`).
const kSocietySignupPriceInr = 8500;

/// Web `SocietySignupDraft` (`src/lib/phonepeClient.ts`).
class SocietySignupDraft {
  const SocietySignupDraft({
    this.societyName = '',
    this.address = '',
    this.city = '',
    this.state = '',
    this.pincode = '',
    this.blocksCsv = '',
    this.totalFloors = '',
    this.flatsPerFloor = '',
    this.flatSeriesStart = '',
    this.flatSeriesEnd = '',
    this.contactPerson = '',
    this.contactPhone = '',
    this.contactEmail = '',
    this.referralCode = '',
    this.adminId = '',
    this.adminPassword = '',
  });

  final String societyName;
  final String address;
  final String city;
  final String state;
  final String pincode;
  final String blocksCsv;
  final String totalFloors;
  final String flatsPerFloor;
  final String flatSeriesStart;
  final String flatSeriesEnd;
  final String contactPerson;
  final String contactPhone;
  final String contactEmail;
  final String referralCode;
  final String adminId;
  final String adminPassword;

  /// Web `canSubmit`: society name, contact phone, admin id and password are required.
  bool get canSubmit =>
      societyName.trim().isNotEmpty && contactPhone.trim().isNotEmpty && adminId.trim().isNotEmpty && adminPassword.trim().isNotEmpty;

  /// `phonepe-init-order` body (required fields trimmed like the web `onPay`).
  Map<String, dynamic> toBody() => {
        'society_name': societyName.trim(),
        'address': address,
        'city': city,
        'state': state,
        'pincode': pincode,
        'blocks_csv': blocksCsv,
        'total_floors': totalFloors,
        'flats_per_floor': flatsPerFloor,
        'flat_series_start': flatSeriesStart,
        'flat_series_end': flatSeriesEnd,
        'contact_person': contactPerson,
        'contact_phone': contactPhone.trim(),
        'contact_email': contactEmail,
        'referral_code': referralCode,
        'admin_id': adminId.trim(),
        'admin_password': adminPassword.trim(),
      };
}

/// `phonepe-init-order` response.
class PhonePeInitResult {
  const PhonePeInitResult({
    this.alreadyExists = false,
    this.signupId = '',
    this.token = '',
    this.amountInr = kSocietySignupPriceInr,
    this.redirectUrl = '',
    this.societyName = '',
  });

  final bool alreadyExists;
  final String signupId;
  final String token;
  final int amountInr;
  final String redirectUrl;
  final String societyName;

  factory PhonePeInitResult.fromJson(Map<String, dynamic> j) => PhonePeInitResult(
        alreadyExists: j['alreadyExists'] == true,
        signupId: '${j['signupId'] ?? ''}',
        token: '${j['token'] ?? ''}',
        amountInr: (j['amountInr'] as num?)?.toInt() ?? kSocietySignupPriceInr,
        redirectUrl: '${j['redirectUrl'] ?? ''}',
        societyName: '${j['societyName'] ?? ''}',
      );
}

/// `phonepe-poll-status` response.
class SignupPollResult {
  const SignupPollResult({required this.signupId, required this.status, required this.societyName, this.order});

  final String signupId;
  final String status;
  final String societyName;
  final Map<String, dynamic>? order;

  factory SignupPollResult.fromJson(Map<String, dynamic> j) => SignupPollResult(
        signupId: '${j['signupId'] ?? ''}',
        status: '${j['status'] ?? ''}',
        societyName: '${j['societyName'] ?? ''}',
        order: j['order'] is Map ? Map<String, dynamic>.from(j['order'] as Map) : null,
      );
}

/// Web `SocietySignupStatusPage` title: a translation key, or the upper-cased status for
/// failed / cancelled.
({String? key, String? literal}) signupStatusTitle(String status) {
  final s = status.toLowerCase();
  if (s == 'pending' || s == 'paid') return (key: 'signup.successPending', literal: null);
  if (s == 'provisioned') return (key: 'signup.successDone', literal: null);
  if (s == 'failed' || s == 'cancelled') return (key: null, literal: s.toUpperCase());
  return (key: 'signup.successProvisioning', literal: null);
}

/// Polling stops at `provisioned`, `failed` or `cancelled` (every 2.5 s otherwise).
bool signupStatusIsTerminal(String status) {
  final s = status.toLowerCase();
  return s == 'provisioned' || s == 'failed' || s == 'cancelled';
}

bool signupStatusFailed(String status) {
  final s = status.toLowerCase();
  return s == 'failed' || s == 'cancelled';
}

const kSignupPollInterval = Duration(milliseconds: 2500);

/// Edge functions used by the web `phonepeClient.ts`.
abstract final class PhonePeClient {
  static Future<PhonePeInitResult> initOrder(SocietySignupDraft draft) async {
    final data = await invokeFunction('phonepe-init-order', draft.toBody());
    if (data == null) throw StateError('Empty phonepe-init-order response');
    return PhonePeInitResult.fromJson(data);
  }

  static Future<SignupPollResult> pollStatus({required String signupId, required String token}) async {
    final data = await invokeFunction('phonepe-poll-status', {'signupId': signupId, 'token': token});
    if (data == null) throw StateError('Empty phonepe-poll-status response');
    return SignupPollResult.fromJson(data);
  }
}

/// Signup started on this device, waiting for payment / provisioning. Native apps cannot
/// rely on PhonePe redirecting back into the app, so the status page reads this.
class PendingSocietySignup {
  const PendingSocietySignup({required this.signupId, required this.token, this.redirectUrl = '', this.societyName = ''});

  final String signupId;
  final String token;
  final String redirectUrl;
  final String societyName;

  Map<String, String> toJson() => {'signupId': signupId, 'token': token, 'redirectUrl': redirectUrl, 'societyName': societyName};

  static PendingSocietySignup? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = '${raw['signupId'] ?? ''}';
    final token = '${raw['token'] ?? ''}';
    if (id.isEmpty || token.isEmpty) return null;
    return PendingSocietySignup(
      signupId: id,
      token: token,
      redirectUrl: '${raw['redirectUrl'] ?? ''}',
      societyName: '${raw['societyName'] ?? ''}',
    );
  }
}

abstract final class SocietySignupStore {
  static const key = 'sgb_pending_society_signup_v1';

  static Future<PendingSocietySignup?> readPending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      return PendingSocietySignup.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  static Future<void> savePending(PendingSocietySignup p) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(p.toJson()));
    } catch (_) {}
  }

  static Future<void> clearPending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (_) {}
  }
}
