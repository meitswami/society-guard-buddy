import '../core/config/env.dart';
import '../core/supabase/supabase_bootstrap.dart';

class VisitorEntryService {
  Future<bool> isBlacklisted({
    required String societyId,
    required String phone,
  }) async {
    if (!Env.isConfigured) return false;

    final rows = await SupabaseBootstrap.client
        .from('blacklist')
        .select('id')
        .eq('society_id', societyId)
        .eq('phone', phone)
        .limit(1);

    return (rows as List).isNotEmpty;
  }

  Future<void> registerVisitor({
    required String societyId,
    required String guardId,
    required String guardName,
    required String name,
    required String phone,
    required String flatNumber,
    required String purpose,
    String documentType = 'aadhaar',
    String? documentNumber,
    String? vehicleNumber,
    String category = 'visitor',
    String? company,
    List<String> visitorPhotos = const [],
  }) async {
    if (!Env.isConfigured) return;

    final now = DateTime.now().toIso8601String();
    await SupabaseBootstrap.client.from('visitors').insert({
      'society_id': societyId,
      'name': name,
      'phone': phone,
      'document_type': documentType,
      'document_number': documentNumber,
      'flat_number': flatNumber,
      'purpose': purpose,
      'entry_time': now,
      'guard_id': guardId,
      'guard_name': guardName,
      'category': category,
      if (company != null && company.isNotEmpty) 'company': company,
      'vehicle_number': vehicleNumber,
      'vehicle_entry_time': vehicleNumber != null && vehicleNumber.isNotEmpty ? now : null,
      if (visitorPhotos.isNotEmpty) 'visitor_photos': visitorPhotos,
    });
  }

  Future<void> registerDelivery({
    required String societyId,
    required String guardId,
    required String guardName,
    required String name,
    required String phone,
    required String flatNumber,
    required String company,
    required bool isDelivery,
    String? vehicleNumber,
  }) async {
    final category = isDelivery ? 'delivery' : 'service';
    final purpose = isDelivery ? 'Delivery - $company' : 'Service - $company';
    await registerVisitor(
      societyId: societyId,
      guardId: guardId,
      guardName: guardName,
      name: name,
      phone: phone,
      flatNumber: flatNumber,
      purpose: purpose,
      documentType: 'other',
      documentNumber: '',
      vehicleNumber: vehicleNumber,
      category: category,
      company: company,
    );
  }
}
