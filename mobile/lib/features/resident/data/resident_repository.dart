import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase/db.dart';
import 'committee_roster.dart';
import 'member_rules.dart';
import 'payment_rules.dart';
import 'resident_models.dart';

/// Supabase access for the resident area. Every query mirrors `src/pages/ResidentDashboard.tsx`
/// (same tables, columns, filters, ordering, inserts and updates).
class ResidentRepository {
  const ResidentRepository();

  static const _mediaBucket = 'notification-media';

  // ---------------------------------------------------------------------------
  // Approvals (guard → resident)
  // ---------------------------------------------------------------------------

  Future<List<ApprovalRequestRow>> fetchApprovals(String flatId) async {
    if (!dbReady) return const [];
    final data = await db
        .from('approval_requests')
        .select('*')
        .eq('flat_id', flatId)
        .order('created_at', ascending: false)
        .limit(50);
    return rowsOf(data).map(ApprovalRequestRow.fromJson).toList();
  }

  Future<void> respondApproval({required String id, required String flatId, required String status}) async {
    if (!dbReady) return;
    await db
        .from('approval_requests')
        .update({'status': status, 'responded_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .eq('flat_id', flatId);
  }

  // ---------------------------------------------------------------------------
  // Visitor passes
  // ---------------------------------------------------------------------------

  Future<List<VisitorPassRow>> fetchPasses(String flatId) async {
    if (!dbReady) return const [];
    final data = await db
        .from('visitor_passes')
        .select('*')
        .eq('flat_id', flatId)
        .order('created_at', ascending: false)
        .limit(50);
    return rowsOf(data).map(VisitorPassRow.fromJson).toList();
  }

  Future<void> createPass({
    required String otp,
    required String flatId,
    required String flatNumber,
    required String residentId,
    required String residentName,
    required String guestName,
    required String guestPhone,
    required String validDate,
    required String timeStart,
    required String timeEnd,
  }) async {
    if (!dbReady) return;
    await db.from('visitor_passes').insert({
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
  }

  /// Mobile addition: an active pass can be withdrawn (guard verification only accepts `active`).
  Future<void> cancelPass({required String id, required String flatId}) async {
    if (!dbReady) return;
    await db
        .from('visitor_passes')
        .update({'status': 'cancelled'})
        .eq('id', id)
        .eq('flat_id', flatId)
        .eq('status', 'active');
  }

  // ---------------------------------------------------------------------------
  // Household (members, logins, committee roster, ID documents)
  // ---------------------------------------------------------------------------

  Future<List<HouseholdMember>> fetchMembers(String flatId) async {
    if (!dbReady) return const [];
    final data = await db.from('members').select('*').eq('flat_id', flatId).order('created_at');
    return rowsOf(data).map(HouseholdMember.fromJson).toList();
  }

  Future<List<FlatmateLogin>> fetchFlatmates(String flatId) async {
    if (!dbReady) return const [];
    final data = await db.from('resident_users').select('*').eq('flat_id', flatId);
    return rowsOf(data).map(FlatmateLogin.fromJson).toList();
  }

  Future<({String? whatsapp, String? email})> fetchContactChannels(String residentId) async {
    if (!dbReady) return (whatsapp: null, email: null);
    final row = await db.from('resident_users').select('whatsapp_phone, email').eq('id', residentId).maybeSingle();
    return (whatsapp: row?['whatsapp_phone']?.toString(), email: row?['email']?.toString());
  }

  Future<bool> fetchSelfIdUploadEnabled(String societyId) async {
    if (!dbReady || societyId.isEmpty) return false;
    final row = await db.from('societies').select('resident_self_id_upload_enabled').eq('id', societyId).maybeSingle();
    return row?['resident_self_id_upload_enabled'] == true;
  }

  Future<List<CommitteeRosterRow>> fetchCommitteeRoster(String societyId) async {
    if (!dbReady || societyId.isEmpty) return const [];
    final data = await db
        .from('committee_members')
        .select('*')
        .eq('society_id', societyId)
        .eq('is_active', true)
        .order('sort_order', ascending: true);
    return currentCommitteeMembers(rowsOf(data).map(CommitteeRosterRow.fromJson).toList());
  }

  Future<List<MemberDocDraft>> fetchMemberDocs(String memberId, {String? kind, String defaultType = 'other'}) async {
    if (!dbReady) return const [];
    var q = db.from('member_documents').select('doc_kind, doc_type, front_url, back_url').eq('member_id', memberId);
    if (kind != null) q = q.eq('doc_kind', kind);
    final data = await q.order('created_at', ascending: true);
    return rowsOf(data).map((r) => MemberDocDraft.fromRow(r, defaultType: defaultType)).toList();
  }

  Future<ResidentVehicleRow?> fetchMemberVehicle(String memberId) async {
    if (!dbReady) return null;
    final row = await db.from('resident_vehicles').select('*').eq('member_id', memberId).limit(1).maybeSingle();
    return row == null ? null : ResidentVehicleRow.fromJson(row);
  }

  /// Web `handleSaveSelfIdPhotos`.
  Future<void> saveSelfIdDocs(String memberId, List<MemberDocDraft> docs) async {
    if (!dbReady) return;
    await db.from('member_documents').delete().eq('member_id', memberId).eq('doc_kind', MemberDocDraft.kindPhotoId);
    final rows = [
      for (final d in docs)
        if (d.kind == MemberDocDraft.kindPhotoId && d.type.isNotEmpty && (d.front.isNotEmpty || d.back.isNotEmpty))
          d.toRow(memberId),
    ];
    if (rows.isNotEmpty) await db.from('member_documents').insert(rows);
  }

  /// Web `handleAddMember` (DB part, after [planMemberSave] validated the form).
  /// Returns the member id.
  Future<String> saveMember({
    required MemberSavePlan plan,
    required MemberFormData form,
    required List<MemberDocDraft> docs,
    required HouseholdMember? editing,
    required String flatId,
    required String flatNumber,
    required String? societyId,
  }) async {
    final name = form.name.trim();
    for (final phone
        in loginPhonesToRemove(previousPhone: editing?.phone, newPhone: form.phone, restricted: plan.restricted)) {
      await db.from('resident_users').delete().eq('phone', phone).eq('flat_id', flatId);
    }

    late final String memberId;
    if (editing != null) {
      await db.from('members').update(plan.payload).eq('id', editing.id);
      if (allowsResidentLogin(plan.relNorm) && form.phone.isNotEmpty) {
        await db.from('resident_users').update({'name': name}).eq('phone', form.phone).eq('flat_id', flatId);
      }
      if (plan.wasPrimary) {
        await db.from('flats').update({'owner_name': name, 'is_occupied': true}).eq('id', flatId);
      }
      memberId = editing.id;
    } else {
      final ins = await db.from('members').insert(plan.payload).select('id').single();
      memberId = ins['id'].toString();
      if (!plan.restricted && form.phone.isNotEmpty) {
        final existing = await db.from('resident_users').select('id').eq('phone', form.phone).limit(1).maybeSingle();
        if (existing == null) {
          final mate = await db.from('resident_users').select('password').eq('flat_id', flatId).limit(1).maybeSingle();
          final pw = (mate?['password'] ?? '').toString();
          await db.from('resident_users').insert({
            'phone': form.phone,
            'name': name,
            'password': pw.isEmpty ? 'Welcome123!' : pw,
            'flat_id': flatId,
            'flat_number': flatNumber,
          });
        }
      }
    }

    await db.from('member_documents').delete().eq('member_id', memberId);
    final docRows = memberDocumentRows(memberId, docs);
    if (docRows.isNotEmpty) await db.from('member_documents').insert(docRows);
    await propagateMemberPhoto(memberId, form.photo);

    if (plan.restricted) {
      await _syncStaffVehicle(
          form: form, memberId: memberId, societyId: societyId, flatId: flatId, flatNumber: flatNumber);
    } else {
      await db.from('resident_vehicles').delete().eq('member_id', memberId);
    }
    return memberId;
  }

  Future<void> _syncStaffVehicle({
    required MemberFormData form,
    required String memberId,
    required String? societyId,
    required String flatId,
    required String flatNumber,
  }) async {
    final existing = await db.from('resident_vehicles').select('id').eq('member_id', memberId).limit(1).maybeSingle();
    final row =
        staffVehicleRow(form: form, societyId: societyId, flatId: flatId, flatNumber: flatNumber, memberId: memberId);
    if (row == null) {
      if (existing != null) await db.from('resident_vehicles').delete().eq('id', existing['id']);
      return;
    }
    if (existing != null) {
      await db.from('resident_vehicles').update(row).eq('id', existing['id']);
    } else {
      await db.from('resident_vehicles').insert(row);
    }
  }

  /// Web `handleDeleteMember`.
  Future<void> deleteMember(HouseholdMember m, String flatId) async {
    await db.from('resident_vehicles').delete().eq('member_id', m.id);
    await db.from('members').delete().eq('id', m.id);
    if ((m.phone ?? '').isNotEmpty) {
      await db.from('resident_users').delete().eq('phone', m.phone!).eq('flat_id', flatId);
    }
  }

  /// Web `propagateMemberPhoto` — keeps active committee roster photos in sync.
  Future<void> propagateMemberPhoto(String memberId, String? photo) async {
    final trimmed = (photo ?? '').trim();
    final member = await db.from('members').select('id, name, flat_id').eq('id', memberId).maybeSingle();
    final flatId = member?['flat_id']?.toString() ?? '';
    final name = (member?['name'] ?? '').toString().trim();
    if (flatId.isEmpty || name.isEmpty) return;
    await db
        .from('committee_members')
        .update({'photo': trimmed.isEmpty ? null : trimmed})
        .eq('flat_id', flatId)
        .eq('name', name)
        .eq('is_active', true);
  }

  // ---------------------------------------------------------------------------
  // Vehicles
  // ---------------------------------------------------------------------------

  Future<List<ResidentVehicleRow>> fetchVehicles(String flatId) async {
    if (!dbReady) return const [];
    final data = await db.from('resident_vehicles').select('*').eq('flat_id', flatId).order('created_at');
    return rowsOf(data).map(ResidentVehicleRow.fromJson).toList();
  }

  Future<void> addVehicle({
    required String societyId,
    required String flatId,
    required String flatNumber,
    required String residentName,
    required String vehicleNumber,
    required String vehicleType,
  }) async {
    await db.from('resident_vehicles').insert({
      'society_id': societyId,
      'flat_number': flatNumber,
      'flat_id': flatId,
      'resident_name': residentName,
      'vehicle_number': vehicleNumber.toUpperCase(),
      'vehicle_type': vehicleType,
    });
  }

  Future<void> deleteVehicle({required String id, required String flatId}) async {
    await db.from('resident_vehicles').delete().eq('id', id).eq('flat_id', flatId);
  }

  // ---------------------------------------------------------------------------
  // Maintenance payments
  // ---------------------------------------------------------------------------

  Future<List<MaintenancePaymentRow>> fetchPayments(String flatId) async {
    if (!dbReady) return const [];
    final data = await db
        .from('maintenance_payments')
        .select('*')
        .eq('flat_id', flatId)
        .order('created_at', ascending: false)
        .limit(50);
    return rowsOf(data).map(MaintenancePaymentRow.fromJson).toList();
  }

  /// Every charge for the payment dropdown (web), with `is_active` for the dues card.
  Future<List<MaintenanceChargeRow>> fetchCharges(String societyId) async {
    if (!dbReady || societyId.isEmpty) return const [];
    final data = await db
        .from('maintenance_charges')
        .select('id, title, amount, due_day, frequency, created_at, is_active')
        .eq('society_id', societyId)
        .order('created_at', ascending: false);
    return rowsOf(data).map(MaintenanceChargeRow.fromJson).toList();
  }

  /// Web `fetchPrimarySocietyBankAccount`.
  Future<SocietyBankAccountRow?> fetchPrimaryBankAccount(String societyId) async {
    if (!dbReady || societyId.isEmpty) return null;
    final row = await db
        .from('society_bank_accounts')
        .select('*')
        .eq('society_id', societyId)
        .eq('is_active', true)
        .eq('is_primary', true)
        .maybeSingle();
    return row == null ? null : SocietyBankAccountRow.fromJson(row);
  }

  /// Web `uploadMaintenanceReceipt` → public URL in `notification-media`.
  Future<String?> uploadMaintenanceReceipt(Uint8List bytes, String fileName, {String? contentType}) async {
    final safe = fileName.replaceAll(RegExp(r'[^\w.-]'), '_');
    final path = 'maintenance-receipts/${const Uuid().v4()}_$safe';
    try {
      await db.storage.from(_mediaBucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(cacheControl: '3600', upsert: false, contentType: contentType),
          );
      return db.storage.from(_mediaBucket).getPublicUrl(path);
    } catch (_) {
      return null;
    }
  }

  /// Web `handleSubmitResidentPayment` insert.
  Future<void> submitPayment({
    required String chargeId,
    required String flatId,
    required String flatNumber,
    required String residentName,
    required String residentId,
    required double amount,
    required String paymentMethod,
    required String paidOn,
    required String dueDate,
    String? transactionId,
    String? screenshotUrl,
    String? notes,
  }) async {
    String? orNull(String? v) => (v ?? '').trim().isEmpty ? null : v!.trim();
    await db.from('maintenance_payments').insert([
      {
        'charge_id': chargeId,
        'flat_id': flatId,
        'flat_number': flatNumber,
        'resident_name': residentName,
        'amount': amount,
        'payment_method': paymentMethod,
        'payment_status': 'pending',
        'payment_date': paidAtIso(paidOn),
        'due_date': dueDate,
        'transaction_id': orNull(transactionId),
        'screenshot_url': orNull(screenshotUrl),
        'notes': orNull(notes),
        'submitted_by': 'resident',
        'submitted_by_user_id': residentId,
        'verified_by': null,
        'verified_at': null,
        'reviewed_at': null,
        'rejection_reason': null,
      },
    ]);
  }

  // ---------------------------------------------------------------------------
  // Profile
  // ---------------------------------------------------------------------------

  /// WhatsApp + email for directory despatch (resident login row, then the member row).
  Future<void> saveContactChannels({
    required String residentId,
    required String? memberId,
    required String? whatsapp,
    required String? email,
  }) async {
    await db.from('resident_users').update({'whatsapp_phone': whatsapp, 'email': email}).eq('id', residentId);
    if (memberId != null) {
      await db.from('members').update({'whatsapp_phone': whatsapp, 'email': email}).eq('id', memberId);
    }
  }

  Future<bool> verifyPassword({required String residentId, required String password}) async {
    final row =
        await db.from('resident_users').select('id').eq('id', residentId).eq('password', password).maybeSingle();
    return row != null;
  }

  /// Shared flat password for every flatmate (also clears `must_change_password`).
  Future<void> setFlatPassword({required String flatId, required String password}) async {
    await db.from('resident_users').update({'password': password, 'must_change_password': false}).eq('flat_id', flatId);
  }

  // ---------------------------------------------------------------------------
  // Society
  // ---------------------------------------------------------------------------

  Future<List<DashboardBanner>> fetchDashboardBanners(String societyId) async {
    if (!dbReady || societyId.isEmpty) return const [];
    final data = await db
        .from('society_dashboard_banners')
        .select('id, image_url, title, is_active')
        .eq('society_id', societyId)
        .eq('is_active', true)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: false);
    return rowsOf(data).map(DashboardBanner.fromJson).where((b) => b.imageUrl.isNotEmpty).toList();
  }

  Future<String> fetchSocietyName(String societyId) async {
    final row = await db.from('societies').select('name').eq('id', societyId).maybeSingle();
    return (row?['name'] ?? '').toString().trim();
  }

  // ---------------------------------------------------------------------------
  // Audit (web `auditLogout`)
  // ---------------------------------------------------------------------------

  Future<void> auditLogout({required String? societyId, required String userId, required String userName}) async {
    if (!dbReady) return;
    try {
      final ip = await _clientIp();
      await db.from('audit_logs').insert([
        {
          'society_id': societyId,
          'event_type': 'logout',
          'user_type': 'resident',
          'user_id': userId,
          'user_name': userName,
          'ip_address': ip,
          'user_agent': 'Kutumbika app (${Platform.operatingSystem} ${Platform.operatingSystemVersion})',
          'device_info': {
            'browser': 'Kutumbika app',
            'os': _osName(),
            'platform': Platform.operatingSystem,
            'language': Platform.localeName,
            'isMobile': Platform.isAndroid || Platform.isIOS,
          },
          'details': <String, dynamic>{},
          'severity': 'info',
        },
      ]);
    } catch (_) {
      // Audit failures never block logout (web logs to console only).
    }
  }

  static String _osName() {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }

  static Future<String> _clientIp() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      final req =
          await client.getUrl(Uri.parse('https://api.ipify.org?format=json')).timeout(const Duration(seconds: 3));
      final res = await req.close().timeout(const Duration(seconds: 3));
      final body = await res.transform(utf8.decoder).join().timeout(const Duration(seconds: 3));
      final decoded = jsonDecode(body);
      return decoded is Map && decoded['ip'] != null ? decoded['ip'].toString() : 'unknown';
    } catch (_) {
      return 'unknown';
    } finally {
      client.close(force: true);
    }
  }
}
