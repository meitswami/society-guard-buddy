import '../../../../core/supabase/db.dart';
import 'people_models.dart';

/// Flat choice of the parking form (`flats.flat_number, id`).
class ParkingFlatOption {
  const ParkingFlatOption({required this.id, required this.flatNumber});

  final String id;
  final String flatNumber;
}

class ParkingSnapshot {
  const ParkingSnapshot({required this.spaces, required this.flats});

  final List<ParkingSpace> spaces;
  final List<ParkingFlatOption> flats;

  List<ParkingSpace> get allocated =>
      spaces.where((s) => s.isAllocated).toList();
  List<ParkingSpace> get available =>
      spaces.where((s) => !s.isAllocated).toList();

  static const empty = ParkingSnapshot(spaces: [], flats: []);
}

/// Data access of web `ParkingManager.tsx`.
class ParkingService {
  Future<ParkingSnapshot> load(String societyId) async {
    if (!dbReady) return ParkingSnapshot.empty;
    final results = await Future.wait([
      db
          .from('parking_spaces')
          .select('*')
          .eq('society_id', societyId)
          .order('space_number', ascending: true),
      db
          .from('flats')
          .select('flat_number, id')
          .eq('society_id', societyId)
          .order('flat_number', ascending: true),
    ]);
    return ParkingSnapshot(
      spaces: rowsOf(results[0]).map(ParkingSpace.fromJson).toList(),
      flats: [
        for (final f in rowsOf(results[1]))
          ParkingFlatOption(
              id: '${f['id']}', flatNumber: '${f['flat_number'] ?? ''}'),
      ],
    );
  }

  /// Web `addSpace`.
  Future<void> addSpace({
    required String societyId,
    required String spaceNumber,
    required String spaceType,
    required String floorLevel,
    required String allocatedFlatNumber,
    required String allocatedVehicleNumber,
    required String notes,
    required List<ParkingFlatOption> flats,
  }) async {
    String? id;
    for (final f in flats) {
      if (f.flatNumber == allocatedFlatNumber) {
        id = f.id;
        break;
      }
    }
    await db.from('parking_spaces').insert([
      {
        'society_id': societyId,
        'space_number': spaceNumber,
        'space_type': spaceType,
        'floor_level': floorLevel.isEmpty ? null : floorLevel,
        'is_allocated': allocatedFlatNumber.isNotEmpty,
        'allocated_flat_id': id,
        'allocated_flat_number':
            allocatedFlatNumber.isEmpty ? null : allocatedFlatNumber,
        'allocated_vehicle_number':
            allocatedVehicleNumber.isEmpty ? null : allocatedVehicleNumber,
        'notes': notes.isEmpty ? null : notes,
      },
    ]);
  }

  Future<void> deleteSpace({required String societyId, required String id}) =>
      db
          .from('parking_spaces')
          .delete()
          .eq('id', id)
          .eq('society_id', societyId);

  /// Web `deallocate`.
  Future<void> deallocate({required String societyId, required String id}) => db
      .from('parking_spaces')
      .update({
        'is_allocated': false,
        'allocated_flat_id': null,
        'allocated_flat_number': null,
        'allocated_vehicle_number': null,
      })
      .eq('id', id)
      .eq('society_id', societyId);
}
