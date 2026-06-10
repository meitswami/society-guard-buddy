import 'package:intl/intl.dart';

import '../core/config/env.dart';
import '../core/supabase/supabase_bootstrap.dart';

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

class VisitorPassVerifyService {
  Future<VerifiedPass> verifyAndUse({
    required String societyId,
    required String otp,
  }) async {
    if (!Env.isConfigured) throw StateError('Supabase not configured');
    if (otp.length != 6) throw StateError('Enter a 6-digit OTP');

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final now = DateFormat('HH:mm:ss').format(DateTime.now());

    final flatRows = await SupabaseBootstrap.client
        .from('flats')
        .select('id')
        .eq('society_id', societyId);
    final flatIds = (flatRows as List).map((f) => f['id'] as String).toList();
    if (flatIds.isEmpty) throw StateError('Invalid OTP');

    final pass = await SupabaseBootstrap.client
        .from('visitor_passes')
        .select('*')
        .eq('otp_code', otp)
        .eq('status', 'active')
        .eq('valid_date', today)
        .inFilter('flat_id', flatIds)
        .maybeSingle();

    if (pass == null) throw StateError('Invalid or expired OTP');

    final start = pass['time_slot_start'] as String?;
    final end = pass['time_slot_end'] as String?;
    if (start != null && end != null && (now.compareTo(start) < 0 || now.compareTo(end) > 0)) {
      throw StateError('OTP is outside the allowed time slot');
    }

    await SupabaseBootstrap.client.from('visitor_passes').update({
      'status': 'used',
      'used_at': DateTime.now().toIso8601String(),
    }).eq('id', pass['id']).inFilter('flat_id', flatIds);

    return VerifiedPass(
      guestName: pass['guest_name'] as String? ?? 'Guest',
      flatNumber: pass['flat_number'] as String? ?? '',
      guestPhone: pass['guest_phone'] as String? ?? '',
    );
  }
}
