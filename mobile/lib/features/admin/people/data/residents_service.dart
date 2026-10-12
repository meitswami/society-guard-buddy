import '../../../../core/supabase/db.dart';
import '../../../../utils/member_categories.dart';
import '../../../../utils/password_generator.dart';
import '../../../../utils/society_flat_layout.dart'
    show floorLabelFromFlatNumber;
import '../../../shared/directory/directory_service.dart';
import '../logic/residents_logic.dart';
import 'people_models.dart';

/// Everything the Residents module shows.
class ResidentsSnapshot {
  const ResidentsSnapshot({
    required this.flats,
    required this.members,
    required this.vehicles,
    required this.logins,
    required this.selfIdUploadEnabled,
  });

  final List<PeopleFlat> flats;
  final List<PeopleMember> members;
  final List<PeopleVehicle> vehicles;
  final List<ResidentLogin> logins;
  final bool selfIdUploadEnabled;

  static const empty = ResidentsSnapshot(
      flats: [],
      members: [],
      vehicles: [],
      logins: [],
      selfIdUploadEnabled: false);
}

/// Member being edited: documents + linked staff vehicle (web `editMember`).
class MemberEditData {
  const MemberEditData({required this.docs, this.vehicle});

  final List<MemberDocDraft> docs;
  final Map<String, dynamic>? vehicle;
}

/// Outcome of saving a member.
class MemberSaveResult {
  const MemberSaveResult(
      {required this.memberId,
      required this.loginsCreated,
      required this.updated});

  final String memberId;
  final int loginsCreated;
  final bool updated;
}

class MemberSaveException implements Exception {
  MemberSaveException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Data access of web `AdminResidentManager.tsx` — same tables, filters, inserts and updates.
class ResidentsService {
  final _dir = DirectoryService();

  Future<ResidentsSnapshot> load(String societyId) async {
    if (!dbReady) return ResidentsSnapshot.empty;
    final flats = await _dir.loadFlats(societyId);
    final flatIds = flats.map((f) => f.id).toList();
    final results = await Future.wait<Object>([
      _dir.loadMembers(flatIds),
      _dir.loadVehicles(societyId),
      loadLogins(flatIds),
      loadSelfIdUploadEnabled(societyId),
    ]);
    return ResidentsSnapshot(
      flats: flats,
      members: results[0] as List<PeopleMember>,
      vehicles: results[1] as List<PeopleVehicle>,
      logins: results[2] as List<ResidentLogin>,
      selfIdUploadEnabled: results[3] as bool,
    );
  }

  /// `resident_users` of the society's flats (web `loadResidentUsers`).
  Future<List<ResidentLogin>> loadLogins(List<String> flatIds) async {
    if (!dbReady || flatIds.isEmpty) return const [];
    final rows = await selectInChunks(
        table: 'resident_users', columns: '*', column: 'flat_id', ids: flatIds);
    return rows.map(ResidentLogin.fromJson).toList();
  }

  Future<bool> loadSelfIdUploadEnabled(String societyId) async {
    if (!dbReady) return false;
    try {
      final row = await db
          .from('societies')
          .select('resident_self_id_upload_enabled')
          .eq('id', societyId)
          .maybeSingle();
      return row?['resident_self_id_upload_enabled'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> setSelfIdUploadEnabled(String societyId, bool on) async {
    await db
        .from('societies')
        .update({'resident_self_id_upload_enabled': on}).eq('id', societyId);
  }

  Future<String> societyName(String societyId) async {
    if (!dbReady) return 'Society';
    try {
      final row = await db
          .from('societies')
          .select('name')
          .eq('id', societyId)
          .maybeSingle();
      final name = row?['name']?.toString() ?? '';
      return name.isEmpty ? 'Society' : name;
    } catch (_) {
      return 'Society';
    }
  }

  /// Web `saveFlat` insert.
  Future<void> addFlat({
    required String societyId,
    required String flatNumber,
    required String floor,
    required String wing,
    required String ownerName,
    required String ownerPhone,
    required String intercom,
  }) async {
    final suggested = floorLabelFromFlatNumber(flatNumber);
    final floorValue =
        (floor.trim().isNotEmpty ? floor.trim() : (suggested ?? '')).trim();
    await db.from('flats').insert({
      'flat_number': flatNumber,
      'floor': floorValue.isEmpty ? null : floorValue,
      'wing': wing.isEmpty ? null : wing,
      'flat_type': 'residential',
      'owner_name': ownerName.isEmpty ? null : ownerName,
      'owner_phone': ownerPhone.isEmpty ? null : ownerPhone,
      'intercom': intercom.isEmpty ? null : intercom,
      'is_occupied': ownerName.isNotEmpty,
      'society_id': societyId,
    });
  }

  /// Web `saveFlatMeta`.
  Future<void> updateFlatMeta(
      {required String flatId,
      required String floor,
      required String wing,
      required String intercom}) async {
    String? v(String s) => s.trim().isEmpty ? null : s.trim();
    await db.from('flats').update({
      'floor': v(floor),
      'wing': v(wing),
      'intercom': v(intercom)
    }).eq('id', flatId);
  }

  /// Web `editMember` extra loads (documents ordered by creation, linked vehicle).
  Future<MemberEditData> loadMemberEditData(String memberId) async {
    final docs = rowsOf(await db
        .from('member_documents')
        .select('doc_kind, doc_type, front_url, back_url')
        .eq('member_id', memberId)
        .order('created_at', ascending: true));
    Map<String, dynamic>? vehicle;
    try {
      vehicle = await db
          .from('resident_vehicles')
          .select('*')
          .eq('member_id', memberId)
          .maybeSingle();
    } catch (_) {
      vehicle = null;
    }
    return MemberEditData(
        docs: docs.map(MemberDocDraft.fromJson).toList(), vehicle: vehicle);
  }

  Future<String?> _vehicleIdForMember(String memberId) async {
    try {
      final row = await db
          .from('resident_vehicles')
          .select('id')
          .eq('member_id', memberId)
          .maybeSingle();
      return row?['id']?.toString();
    } catch (_) {
      return null;
    }
  }

  /// Web `saveMember` (after validation + sensitive verification).
  Future<MemberSaveResult> saveMember({
    required String societyId,
    required PeopleFlat flat,
    required List<PeopleMember> flatMembers,
    required PeopleMember? editing,
    required MemberFormState form,
    required List<MemberDocDraft> docs,
  }) async {
    final flatId = flat.id;
    final restricted = isRestrictedMemberCategory(form.relation);
    final primary = flatMembers.where((m) => m.isPrimary).firstOrNull;
    final isPrimary = decideIsPrimary(
      relation: form.relation,
      isEditing: editing != null,
      previousWasPrimary: editing?.isPrimary ?? false,
      flatMemberCount: flatMembers.length,
      primaryExists: primary != null,
      formIsPrimary: form.isPrimary,
    );

    if (isPrimary && primary != null && primary.id != editing?.id) {
      await db
          .from('members')
          .update({'is_primary': false}).eq('id', primary.id);
    }

    final payload = buildMemberPayload(
        flatId: flatId, form: form, docs: docs, isPrimary: isPrimary);

    final prevPhone = editing?.phone;
    if (prevPhone != null &&
        (restricted || form.phone.isEmpty || form.phone != prevPhone)) {
      await db
          .from('resident_users')
          .delete()
          .eq('phone', prevPhone)
          .eq('flat_id', flatId);
    }
    if (restricted && form.phone.isNotEmpty) {
      await db
          .from('resident_users')
          .delete()
          .eq('phone', form.phone)
          .eq('flat_id', flatId);
    }

    late final String memberId;
    if (editing != null) {
      memberId = editing.id;
      await db.from('members').update(payload).eq('id', memberId);
      if (allowsResidentLogin(form.relation) && form.phone.isNotEmpty) {
        await db
            .from('resident_users')
            .update({
              'name': form.name,
              'whatsapp_phone':
                  form.whatsappPhone.isEmpty ? null : form.whatsappPhone,
              'email': form.email.trim().isEmpty ? null : form.email.trim(),
            })
            .eq('phone', form.phone)
            .eq('flat_id', flatId);
      }
    } else {
      final ins =
          await db.from('members').insert(payload).select('id').single();
      final id = ins['id']?.toString();
      if (id == null || id.isEmpty) {
        throw MemberSaveException('Could not add member');
      }
      memberId = id;
    }

    // Replace member documents (best effort, like the web).
    await db.from('member_documents').delete().eq('member_id', memberId);
    final docRows = memberDocumentRows(memberId, docs);
    if (docRows.isNotEmpty) await db.from('member_documents').insert(docRows);
    await propagateMemberPhoto(
        memberId, form.photo.isEmpty ? null : form.photo);

    if (isPrimary) {
      await db.from('flats').update(
          {'owner_name': form.name, 'is_occupied': true}).eq('id', flatId);
    }

    // The form shows the vehicle row for staff and tenants (`memberNeedsDocs`), so save it
    // for both. The web saves it only for staff and silently deletes a tenant's vehicle.
    if (restricted || isTenantRelation(form.relation)) {
      await _syncStaffVehicleRow(
          societyId: societyId, memberId: memberId, flat: flat, form: form);
    } else {
      final vid = await _vehicleIdForMember(memberId);
      if (vid != null) {
        await db.from('resident_vehicles').delete().eq('id', vid);
      }
    }

    var created = 0;
    if (allowsResidentLogin(form.relation) && form.phone.isNotEmpty) {
      created = await syncResidentUsersForFlat(flatId, flat.flatNumber);
    }
    return MemberSaveResult(
        memberId: memberId, loginsCreated: created, updated: editing != null);
  }

  Future<void> _syncStaffVehicleRow({
    required String societyId,
    required String memberId,
    required PeopleFlat flat,
    required MemberFormState form,
  }) async {
    final existingId = await _vehicleIdForMember(memberId);
    final row = staffVehicleRow(
      societyId: societyId,
      memberId: memberId,
      flatId: flat.id,
      flatNumber: flat.flatNumber,
      residentName: form.name,
      form: form,
    );
    if (row == null) {
      if (existingId != null) {
        await db.from('resident_vehicles').delete().eq('id', existingId);
      }
      return;
    }
    if (existingId != null) {
      await db.from('resident_vehicles').update(row).eq('id', existingId);
    } else {
      await db.from('resident_vehicles').insert(row);
    }
  }

  /// Web `syncResidentUsersForFlat`: create logins for household members with a phone.
  /// Returns how many logins were created.
  Future<int> syncResidentUsersForFlat(String flatId, String flatNumber) async {
    final latest =
        rowsOf(await db.from('members').select('*').eq('flat_id', flatId));
    final existing = rowsOf(
        await db.from('resident_users').select('*').eq('flat_id', flatId));
    final rows = planNewResidentLogins(
      latestMembers: latest,
      existingUsers: existing,
      flatId: flatId,
      flatNumber: flatNumber,
      newPassword: generateFlatPassword,
    );
    if (rows.isEmpty) return 0;
    await db.from('resident_users').insert(rows);
    return rows.length;
  }

  /// Web `propagateMemberPhoto` (`src/lib/memberPhotos.ts`): keep active committee roster photos in sync.
  Future<void> propagateMemberPhoto(String memberId, String? photo) async {
    final trimmed = photo?.trim() ?? '';
    final value = trimmed.isEmpty ? null : trimmed;
    final member = await db
        .from('members')
        .select('id, name, flat_id')
        .eq('id', memberId)
        .maybeSingle();
    final flatId = member?['flat_id']?.toString();
    final name = member?['name']?.toString().trim() ?? '';
    if (flatId == null || flatId.isEmpty || name.isEmpty) return;
    await db
        .from('committee_members')
        .update({'photo': value})
        .eq('flat_id', flatId)
        .eq('name', name)
        .eq('is_active', true);
  }

  /// Web `removeMember`.
  Future<void> removeMember(PeopleMember member) async {
    await db.from('resident_vehicles').delete().eq('member_id', member.id);
    await db.from('members').delete().eq('id', member.id);
    if (member.phone != null) {
      await db
          .from('resident_users')
          .delete()
          .eq('phone', member.phone!)
          .eq('flat_id', member.flatId);
    }
  }

  /// Web `setPrimaryMember`.
  Future<void> setPrimaryMember(
      {required PeopleMember target,
      required List<PeopleMember> flatMembers}) async {
    for (final m in flatMembers) {
      if (m.isPrimary) {
        await db.from('members').update({'is_primary': false}).eq('id', m.id);
      }
    }
    await db.from('members').update({'is_primary': true}).eq('id', target.id);
    await db
        .from('flats')
        .update({'owner_name': target.name}).eq('id', target.flatId);
  }

  /// Web `resetFlatPassword` — returns the new shared password.
  Future<String> resetFlatPassword(String flatId) async {
    final newPass = generateFlatPassword();
    await db
        .from('resident_users')
        .update({'password': newPass}).eq('flat_id', flatId);
    return newPass;
  }

  /// Web `removeFlat` (logins, members, then the flat).
  Future<void> removeFlat(String flatId) async {
    await db.from('resident_users').delete().eq('flat_id', flatId);
    await db.from('members').delete().eq('flat_id', flatId);
    await db.from('flats').delete().eq('id', flatId);
  }
}
