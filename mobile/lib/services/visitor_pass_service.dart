import 'dart:math';

import '../core/config/env.dart';
import '../core/supabase/supabase_bootstrap.dart';
import '../models/visitor_pass.dart';

class VisitorPassService {
  Future<List<VisitorPass>> fetchForFlat(String flatId) async {
    if (!Env.isConfigured) return const [];

    final rows = await SupabaseBootstrap.client
        .from('visitor_passes')
        .select('*')
        .eq('flat_id', flatId)
        .order('created_at', ascending: false)
        .limit(50);

    return (rows as List)
        .map((r) => VisitorPass.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<String> createPass({
    required String flatId,
    required String flatNumber,
    required String residentId,
    required String residentName,
    required String guestName,
    required String guestPhone,
    required String validDate,
    String? timeStart,
    String? timeEnd,
  }) async {
    final otp = (100000 + Random().nextInt(900000)).toString();

    if (!Env.isConfigured) return otp;

    await SupabaseBootstrap.client.from('visitor_passes').insert({
      'otp_code': otp,
      'flat_id': flatId,
      'flat_number': flatNumber,
      'created_by_type': 'resident',
      'created_by_id': residentId,
      'created_by_name': residentName,
      'guest_name': guestName.isEmpty ? null : guestName,
      'guest_phone': guestPhone.isEmpty ? null : guestPhone,
      'valid_date': validDate,
      'time_slot_start': timeStart,
      'time_slot_end': timeEnd,
    });

    return otp;
  }
}
