import 'package:intl/intl.dart';

import '../core/config/env.dart';
import '../core/supabase/db.dart';

class VerifiedPass {
  const VerifiedPass({
    required this.guestName,
    required this.flatNumber,
    required this.guestPhone,
  });

  final String guestName;
  final String flatNumber;
  final String guestPhone;
}

/// Why an OTP pass was not accepted (web `OTPVerifyModal` messages).
enum PassVerifyError {
  /// `otp.enterSixDigit`
  enterSixDigit,

  /// `otp.invalid`
  invalid,

  /// `otp.outsideTimeSlot`
  outsideTimeSlot,
}

class PassVerifyResult {
  const PassVerifyResult.ok(VerifiedPass this.pass) : error = null;
  const PassVerifyResult.failed(PassVerifyError this.error) : pass = null;

  final VerifiedPass? pass;
  final PassVerifyError? error;

  bool get isValid => pass != null;

  /// Web i18n key of the error message.
  String? get errorKey => switch (error) {
        PassVerifyError.enterSixDigit => 'otp.enterSixDigit',
        PassVerifyError.invalid => 'otp.invalid',
        PassVerifyError.outsideTimeSlot => 'otp.outsideTimeSlot',
        null => null,
      };
}

/// True when [nowHms] (`HH:mm:ss`) is inside the pass slot; passes without a full slot
/// are valid all day (web compares the `time` strings).
bool isWithinPassTimeSlot(String nowHms, String? start, String? end) {
  if (start == null || start.isEmpty || end == null || end.isEmpty) return true;
  return !(nowHms.compareTo(start) < 0 || nowHms.compareTo(end) > 0);
}

/// Resident pre-approved visitor pass (6-digit OTP) check at the gate.
class VisitorPassVerifyService {
  /// Web `OTPVerifyModal.handleVerify`: today's active pass of a flat in this society, inside its
  /// time slot; marks it `used`.
  Future<PassVerifyResult> verify({required String societyId, required String otp, DateTime? now}) async {
    if (otp.length != 6) return const PassVerifyResult.failed(PassVerifyError.enterSixDigit);
    if (!Env.isConfigured || societyId.isEmpty) return const PassVerifyResult.failed(PassVerifyError.invalid);

    final at = now ?? DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(at);
    final nowHms = DateFormat('HH:mm:ss').format(at);

    final flatIds = rowsOf(await db.from('flats').select('id').eq('society_id', societyId))
        .map((f) => f['id'] as String)
        .toSet();
    if (flatIds.isEmpty) return const PassVerifyResult.failed(PassVerifyError.invalid);

    // Same rows as the web `.in('flat_id', flatIds).single()`, filtered client-side so large
    // societies do not produce an oversized request URL.
    final candidates = rowsOf(
      await db.from('visitor_passes').select('*').eq('otp_code', otp).eq('status', 'active').eq('valid_date', today),
    ).where((p) => flatIds.contains(p['flat_id'])).toList();
    if (candidates.length != 1) return const PassVerifyResult.failed(PassVerifyError.invalid);
    final pass = candidates.single;

    if (!isWithinPassTimeSlot(nowHms, pass['time_slot_start'] as String?, pass['time_slot_end'] as String?)) {
      return const PassVerifyResult.failed(PassVerifyError.outsideTimeSlot);
    }

    await db.from('visitor_passes').update({
      'status': 'used',
      'used_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', pass['id'] as String);

    final guestName = (pass['guest_name'] as String?) ?? '';
    return PassVerifyResult.ok(VerifiedPass(
      guestName: guestName.isEmpty ? 'Guest' : guestName,
      flatNumber: (pass['flat_number'] as String?) ?? '',
      guestPhone: (pass['guest_phone'] as String?) ?? '',
    ));
  }

  /// Legacy API: throws [StateError] with an English message when the OTP is not accepted.
  Future<VerifiedPass> verifyAndUse({
    required String societyId,
    required String otp,
  }) async {
    if (!Env.isConfigured) throw StateError('Supabase not configured');
    final res = await verify(societyId: societyId, otp: otp);
    if (res.pass != null) return res.pass!;
    throw StateError(switch (res.error) {
      PassVerifyError.enterSixDigit => 'Enter a 6-digit OTP',
      PassVerifyError.outsideTimeSlot => 'OTP is outside the allowed time slot',
      _ => 'Invalid or expired OTP',
    });
  }
}
