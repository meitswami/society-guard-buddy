import '../core/config/env.dart';
import '../core/supabase/db.dart';
import '../features/gate/data/gate_logic.dart';
import '../features/gate/data/gate_models.dart';
import 'visitor_service.dart';

/// Gate entry writes (visitor / delivery / service), payloads identical to the web pages.
class VisitorEntryService {
  final _visitors = VisitorService();

  /// True when the phone is on the society blacklist.
  Future<bool> isBlacklisted({
    required String societyId,
    required String phone,
  }) async {
    if (!Env.isConfigured) return false;
    final rows = await db
        .from('blacklist')
        .select('id')
        .eq('society_id', societyId)
        .eq('phone', phone)
        .limit(1);
    return rowsOf(rows).isNotEmpty;
  }

  /// Insert a ready-made entry (see `buildVisitorEntry` / `buildDeliveryEntry`).
  Future<void> insertEntry(String societyId, GateVisitor entry) =>
      _visitors.insert(societyId, entry);

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
    String? documentPhoto,
  }) async {
    final base = buildVisitorEntry(
      name: name,
      phone: phone,
      flatNumber: flatNumber,
      purpose: purpose,
      documentType: documentType,
      documentNumber: documentNumber ?? '',
      documentPhoto: documentPhoto,
      visitorPhotos: visitorPhotos,
      hasVehicle: vehicleNumber != null && vehicleNumber.isNotEmpty,
      vehicleNumber: vehicleNumber ?? '',
      guardId: guardId,
      guardName: guardName,
    );
    final entry = category == 'visitor' && company == null
        ? base
        : GateVisitor(
            id: base.id,
            name: base.name,
            phone: base.phone,
            documentType: base.documentType,
            documentNumber: base.documentNumber,
            documentPhoto: base.documentPhoto,
            visitorPhotos: base.visitorPhotos,
            flatNumber: base.flatNumber,
            purpose: base.purpose,
            entryTime: base.entryTime,
            guardId: base.guardId,
            guardName: base.guardName,
            category: category,
            company: company,
            vehicleNumber: base.vehicleNumber,
            vehicleEntryTime: base.vehicleEntryTime,
          );
    await insertEntry(societyId, entry);
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
    List<String> personPhotos = const [],
  }) async {
    await insertEntry(
      societyId,
      buildDeliveryEntry(
        isDelivery: isDelivery,
        name: name,
        phone: phone,
        company: company,
        flatNumber: flatNumber,
        vehicleNumber: vehicleNumber ?? '',
        personPhotos: personPhotos,
        guardId: guardId,
        guardName: guardName,
      ),
    );
  }
}
