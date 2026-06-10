import '../core/config/env.dart';
import '../core/supabase/supabase_bootstrap.dart';
import '../models/resident_vehicle.dart';

class VehicleService {
  Future<List<ResidentVehicle>> fetchForFlat(String societyId, String flatId) async {
    if (!Env.isConfigured) return const [];

    final rows = await SupabaseBootstrap.client
        .from('resident_vehicles')
        .select('*')
        .eq('society_id', societyId)
        .eq('flat_id', flatId)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((r) => ResidentVehicle.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<void> addVehicle({
    required String societyId,
    required String flatId,
    required String flatNumber,
    required String residentName,
    required String vehicleNumber,
    required String vehicleType,
  }) async {
    if (!Env.isConfigured) return;

    await SupabaseBootstrap.client.from('resident_vehicles').insert({
      'society_id': societyId,
      'flat_id': flatId,
      'flat_number': flatNumber,
      'resident_name': residentName,
      'vehicle_number': vehicleNumber.trim().toUpperCase(),
      'vehicle_type': vehicleType,
    });
  }

  Future<void> removeVehicle(String societyId, String id) async {
    if (!Env.isConfigured) return;

    await SupabaseBootstrap.client
        .from('resident_vehicles')
        .delete()
        .eq('id', id)
        .eq('society_id', societyId);
  }
}
