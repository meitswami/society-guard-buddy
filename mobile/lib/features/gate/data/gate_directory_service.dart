import '../../../core/supabase/db.dart';
import 'gate_models.dart';

/// Flats and household members for the gate screens — web `useStore.loadFlats` / `loadMembers`.
class GateDirectoryService {
  const GateDirectoryService();

  /// Columns of `members` the gate screens use (ID-proof images are not downloaded).
  static const memberColumns =
      'id, flat_id, name, phone, relation, is_primary, household_group';

  /// Flat ids per `in` filter (keeps the request URL short for large societies).
  static const _chunk = 150;

  Future<List<GateFlat>> fetchFlats(String societyId) async {
    if (!dbReady) return const [];
    final rows = await db
        .from('flats')
        .select('*')
        .eq('society_id', societyId)
        .order('flat_number', ascending: true);
    return rowsOf(rows).map(GateFlat.fromRow).toList();
  }

  /// Members of the given flats, primary members first.
  Future<List<GateMember>> fetchMembers(List<String> flatIds) async {
    if (!dbReady || flatIds.isEmpty) return const [];
    final out = <GateMember>[];
    for (var i = 0; i < flatIds.length; i += _chunk) {
      final ids = flatIds.sublist(
          i, i + _chunk > flatIds.length ? flatIds.length : i + _chunk);
      final rows = await db
          .from('members')
          .select(memberColumns)
          .inFilter('flat_id', ids)
          .order('is_primary', ascending: false);
      out.addAll(rowsOf(rows).map(GateMember.fromRow));
    }
    return out;
  }
}

/// `resident_vehicles` access — web `useStore` vehicle actions.
class GateVehicleService {
  const GateVehicleService();

  static const columns =
      'id, society_id, flat_number, resident_name, vehicle_number, vehicle_type, flat_id, member_id, '
      'vehicle_color, vehicle_display_name, created_at';

  Future<List<GateResidentVehicle>> fetchAll(String societyId) async {
    if (!dbReady) return const [];
    final rows = await db
        .from('resident_vehicles')
        .select(columns)
        .eq('society_id', societyId);
    return rowsOf(rows).map(GateResidentVehicle.fromRow).toList();
  }

  /// Web `addResidentVehicle`.
  Future<void> add({
    required String societyId,
    required String flatNumber,
    required String residentName,
    required String vehicleNumber,
    required String vehicleType,
    String? flatId,
  }) async {
    if (!dbReady) return;
    await db.from('resident_vehicles').insert({
      'society_id': societyId,
      'flat_number': flatNumber,
      'resident_name': residentName,
      'vehicle_number': vehicleNumber,
      'vehicle_type': vehicleType,
      'flat_id': flatId,
    });
  }

  /// Web `removeResidentVehicle`.
  Future<void> remove({required String societyId, required String id}) async {
    if (!dbReady) return;
    await db
        .from('resident_vehicles')
        .delete()
        .eq('id', id)
        .eq('society_id', societyId);
  }
}
