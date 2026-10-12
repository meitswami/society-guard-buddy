import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/db.dart';
import '../logic/backup_export.dart';
import '../logic/flat_layout.dart';
import '../logic/role_permissions.dart';
import 'superadmin_models.dart';

/// Result of the web `upsertSocietyFlatsFromLayout`.
class FlatGenerateResult {
  const FlatGenerateResult(
      {required this.created, required this.skipped, this.error});

  final int created;
  final int skipped;
  final String? error;
}

/// Insert / update outcome with the PostgREST error code (`23505` = duplicate).
class WriteResult {
  const WriteResult.ok([this.id])
      : code = null,
        message = null;
  const WriteResult.fail(this.code, this.message) : id = null;

  final String? id;
  final String? code;
  final String? message;

  bool get ok => code == null && message == null;
  bool get duplicate => code == '23505';
}

WriteResult _fail(Object e) {
  if (e is PostgrestException) {
    return WriteResult.fail(e.code ?? 'error', e.message);
  }
  return WriteResult.fail('error', '$e');
}

/// Everything the web `loadAll()` loads (null when that query failed — web keeps the old list).
class ConsoleData {
  const ConsoleData({this.societies, this.roles, this.admins});

  final List<SocietyRow>? societies;
  final List<SocietyRoleRow>? roles;
  final List<AdminRow>? admins;
}

/// Response of `superadmin-recovery-send` / `-verify` (errors normalised).
class RecoveryResponse {
  const RecoveryResponse({this.data, this.errorMessage, this.status});

  final Map<String, dynamic>? data;
  final String? errorMessage;
  final int? status;

  bool get failed => errorMessage != null;
}

/// Outcome of `backup-export`.
class BackupResponse {
  const BackupResponse({this.data, this.error});

  final Map<String, dynamic>? data;
  final String? error;
}

/// Society details shown in the info sheet (counts, referral & wallet when readable).
class SocietyDetails {
  const SocietyDetails({
    this.flats,
    this.admins,
    this.roles,
    this.guards,
    this.referrals = const [],
    this.wallet = const [],
  });

  final int? flats;
  final int? admins;
  final int? roles;
  final int? guards;
  final List<Map<String, dynamic>> referrals;
  final List<Map<String, dynamic>> wallet;

  int get walletBalance {
    var sum = 0;
    for (final w in wallet) {
      final amt = w['amount_inr'] is num
          ? (w['amount_inr'] as num).toInt()
          : int.tryParse('${w['amount_inr']}') ?? 0;
      sum += w['entry_type'] == 'debit' ? -amt : amt;
    }
    return sum;
  }
}

String? _functionError(Object? details) {
  if (details is Map) {
    final e = details['error'] ?? details['message'];
    if (e != null && '$e'.trim().isNotEmpty) return '$e';
  }
  if (details is String && details.trim().isNotEmpty) return details;
  return null;
}

/// All Superadmin console data access — the same tables, columns, filters and edge
/// functions as `SuperadminDashboard.tsx`, `SuperadminLoginForm.tsx` and
/// `SuperadminSupportTickets.tsx`.
class SuperadminRepository {
  const SuperadminRepository();

  // ---------------------------------------------------------------------------
  // Console bootstrap (web `loadAll`)

  Future<ConsoleData> loadAll() async {
    if (!dbReady) {
      return const ConsoleData(societies: [], roles: [], admins: []);
    }
    Future<List<Map<String, dynamic>>?> q(Future<Object?> f) async {
      try {
        return rowsOf(await f);
      } catch (_) {
        return null;
      }
    }

    final results = await Future.wait([
      q(db.from('societies').select('*').order('name', ascending: true)),
      q(db.from('society_roles').select('*').order('role_name', ascending: true)),
      q(db.from('admins').select('*').order('name', ascending: true)),
    ]);
    return ConsoleData(
      societies: results[0]?.map(SocietyRow.fromJson).toList(),
      roles: results[1]?.map(SocietyRoleRow.fromJson).toList(),
      admins: results[2]?.map(AdminRow.fromJson).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // Societies

  Future<String> insertSociety(Map<String, dynamic> row) async {
    final data = await db.from('societies').insert(row).select('id').single();
    return '${data['id']}';
  }

  Future<void> updateSociety(String id, Map<String, dynamic> patch) =>
      db.from('societies').update(patch).eq('id', id);

  Future<void> deleteSociety(String id) =>
      db.from('societies').delete().eq('id', id);

  Future<void> setSocietyActive(String id, bool active) =>
      db.from('societies').update({'is_active': active}).eq('id', id);

  Future<WriteResult> setReferralCode(String id, String code) async {
    try {
      await db.from('societies').update({'referral_code': code}).eq('id', id);
      return const WriteResult.ok();
    } catch (e) {
      return _fail(e);
    }
  }

  Future<List<ExistingFlat>> _flats(String societyId,
      {bool withMeta = true}) async {
    final rows = rowsOf(await db
        .from('flats')
        .select(
            withMeta ? 'id, flat_number, wing, flat_type' : 'flat_number, wing')
        .eq('society_id', societyId));
    return [
      for (final r in rows)
        ExistingFlat(
          id: r['id']?.toString(),
          flatNumber: '${r['flat_number'] ?? ''}',
          wing: r['wing']?.toString(),
          flatType: r['flat_type']?.toString(),
        ),
    ];
  }

  /// Web `trimSocietyFlatsToConfiguredRange` → number of flats removed (0 on any error).
  Future<int> trimFlatsToConfiguredRange(
      String societyId, SocietyLayoutInput row) async {
    if (canTrimFlatsFromSocietyRow(row) == null) return 0;
    try {
      final flats = await _flats(societyId);
      if (flats.isEmpty) return 0;
      final ids = flatIdsToTrim(row, flats);
      if (ids.isEmpty) return 0;
      for (final part in chunked(ids, 200)) {
        await db.from('flats').delete().inFilter('id', part);
      }
      return ids.length;
    } catch (_) {
      return 0;
    }
  }

  /// Web `upsertSocietyFlatsFromLayout`.
  Future<FlatGenerateResult> upsertFlatsFromLayout(
      String societyId, SocietyLayoutInput row) async {
    if (societyId.isEmpty) {
      return const FlatGenerateResult(
          created: 0, skipped: 0, error: 'Missing society id');
    }
    if (canTrimFlatsFromSocietyRow(row) == null) {
      return const FlatGenerateResult(
          created: 0, skipped: 0, error: kInvalidFlatLayoutError);
    }
    List<ExistingFlat> existing;
    try {
      existing = await _flats(societyId, withMeta: false);
    } on PostgrestException catch (e) {
      return FlatGenerateResult(created: 0, skipped: 0, error: e.message);
    }
    final plan = planFlatsFromLayout(societyId, row, existing);
    if (plan.error != null) {
      return FlatGenerateResult(created: 0, skipped: 0, error: plan.error);
    }
    if (plan.rows.isEmpty) {
      return FlatGenerateResult(created: 0, skipped: plan.skipped);
    }
    var created = 0;
    for (final part in chunked(plan.rows, 250)) {
      try {
        await db.from('flats').insert(part);
      } on PostgrestException catch (e) {
        return FlatGenerateResult(
            created: created, skipped: plan.skipped, error: e.message);
      }
      created += part.length;
    }
    return FlatGenerateResult(created: created, skipped: plan.skipped);
  }

  /// Web `regenerateSocietyFlats` delete step (residential or untyped flats only).
  Future<void> deleteResidentialFlats(String societyId) => db
      .from('flats')
      .delete()
      .eq('society_id', societyId)
      .or('flat_type.eq.residential,flat_type.is.null');

  Future<int?> _count(String table, String column, String value) async {
    try {
      final res = await db
          .from(table)
          .select('id')
          .eq(column, value)
          .count(CountOption.exact);
      return res.count;
    } catch (_) {
      return null;
    }
  }

  /// Info sheet: counts + referral rewards + wallet ledger (empty when RLS hides them).
  Future<SocietyDetails> societyDetails(String societyId) async {
    Future<List<Map<String, dynamic>>> rows(Future<Object?> f) async {
      try {
        return rowsOf(await f);
      } catch (_) {
        return const [];
      }
    }

    final counts = await Future.wait([
      _count('flats', 'society_id', societyId),
      _count('admins', 'society_id', societyId),
      _count('society_roles', 'society_id', societyId),
      _count('guards', 'society_id', societyId),
    ]);
    final lists = await Future.wait([
      rows(db
          .from('society_referrals')
          .select(
              'id, created_at, referral_code_used, referrer_reward_inr, referred_reward_inr, reward_percent, referred_society_id, referrer_society_id')
          .or('referrer_society_id.eq.$societyId,referred_society_id.eq.$societyId')
          .order('created_at', ascending: false)),
      rows(db
          .from('society_wallet_ledger')
          .select('id, created_at, entry_type, amount_inr, notes')
          .eq('society_id', societyId)
          .order('created_at', ascending: false)),
    ]);
    return SocietyDetails(
      flats: counts[0],
      admins: counts[1],
      roles: counts[2],
      guards: counts[3],
      referrals: lists[0],
      wallet: lists[1],
    );
  }

  // ---------------------------------------------------------------------------
  // Roles

  /// Web `addRole` insert (permissions = `NEW_CUSTOM_ROLE_PERMISSIONS`).
  Future<WriteResult> insertRole(String societyId, String roleName,
      {RolePermissions? permissions}) async {
    try {
      await db.from('society_roles').insert({
        'society_id': societyId,
        'role_name': roleName,
        'permissions': (permissions ?? RolePermissions.newCustom).toJson(),
      });
      return const WriteResult.ok();
    } catch (e) {
      return _fail(e);
    }
  }

  Future<void> deleteRole(String id) =>
      db.from('society_roles').delete().eq('id', id);

  Future<WriteResult> updateRole(String id,
      {String? roleName, RolePermissions? permissions}) async {
    try {
      await db.from('society_roles').update({
        if (roleName != null) 'role_name': roleName,
        if (permissions != null) 'permissions': permissions.toJson(),
      }).eq('id', id);
      return const WriteResult.ok();
    } catch (e) {
      return _fail(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Admins

  /// Web `addAdmin` insert (`admin_id` upper-cased, empty role / e-mail → null).
  Future<WriteResult> insertAdmin({
    required String name,
    required String adminId,
    required String password,
    required String societyId,
    String? roleId,
    String? email,
  }) async {
    try {
      await db.from('admins').insert({
        'name': name,
        'admin_id': adminId.toUpperCase(),
        'password': password,
        'society_id': societyId,
        'role_id': (roleId == null || roleId.isEmpty) ? null : roleId,
        'email': (email == null || email.isEmpty) ? null : email,
      });
      return const WriteResult.ok();
    } catch (e) {
      return _fail(e);
    }
  }

  Future<WriteResult> updateAdmin(String id, Map<String, dynamic> patch) async {
    try {
      await db.from('admins').update(patch).eq('id', id);
      return const WriteResult.ok();
    } catch (e) {
      return _fail(e);
    }
  }

  Future<void> deleteAdmin(String id) =>
      db.from('admins').delete().eq('id', id);

  // ---------------------------------------------------------------------------
  // Superadmin login + security settings

  /// Web login: match by username only, compare the password in-app.
  Future<Map<String, dynamic>?> fetchSuperAdminByUsername(
      String username) async {
    final row = await db
        .from('super_admins')
        .select('*')
        .eq('username', username)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Future<Map<String, dynamic>?> fetchSuperAdminById(String id) async {
    final row =
        await db.from('super_admins').select('*').eq('id', id).maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Future<Map<String, dynamic>?> fetchSecurity(String id) async {
    final row = await db
        .from('super_admins')
        .select('recovery_email, totp_enabled, totp_secret')
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Future<void> updateSuperAdmin(String id, Map<String, dynamic> patch) =>
      db.from('super_admins').update(patch).eq('id', id);

  Future<RecoveryResponse> _invoke(String fn, Map<String, dynamic> body) async {
    try {
      final res = await db.functions.invoke(fn, body: body);
      final data = res.data;
      return RecoveryResponse(
          data: data is Map ? Map<String, dynamic>.from(data) : null,
          status: res.status);
    } on FunctionException catch (e) {
      return RecoveryResponse(
          errorMessage: _functionError(e.details) ?? '', status: e.status);
    } catch (e) {
      return RecoveryResponse(errorMessage: '$e');
    }
  }

  /// Edge function `superadmin-recovery-send`.
  Future<RecoveryResponse> sendRecoveryCode(
          String username, String recoveryEmail) =>
      _invoke('superadmin-recovery-send',
          {'username': username, 'recovery_email': recoveryEmail});

  /// Edge function `superadmin-recovery-verify`.
  Future<RecoveryResponse> verifyRecoveryCode(String username, String code) =>
      _invoke(
          'superadmin-recovery-verify', {'username': username, 'code': code});

  // ---------------------------------------------------------------------------
  // Platform branding (Flutter app)

  Future<Map<String, dynamic>?> fetchBranding() async {
    final row = await db
        .from('platform_branding')
        .select(
            'app_name, tagline, logo_url, primary_color, primary_dark_color, background_color')
        .eq('id', 'default')
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Future<void> upsertBranding(Map<String, dynamic> row) =>
      db.from('platform_branding').upsert({'id': 'default', ...row});

  // ---------------------------------------------------------------------------
  // Maintenance

  /// Edge function `backup-export` (JSON envelope `{ backup, filename }` or e-mail result).
  Future<BackupResponse> backupExport(
      {String? societyId,
      bool completeDb = false,
      bool sendEmail = false}) async {
    try {
      final res = await db.functions.invoke(
        'backup-export',
        body: backupExportBody(
            societyId: societyId, completeDb: completeDb, sendEmail: sendEmail),
      );
      final data = res.data;
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        final err = map['error'];
        if (err != null && '$err'.isNotEmpty) {
          return BackupResponse(error: '$err');
        }
        return BackupResponse(data: map);
      }
      return const BackupResponse(data: {});
    } on FunctionException catch (e) {
      return BackupResponse(
          error: describeBackupExportHttpError(e.status,
              serverMessage: _functionError(e.details)));
    } catch (e) {
      return BackupResponse(error: describeBackupExportNetworkError('$e'));
    }
  }

  /// Web store `clearAllData()` — deletes every row of these tables (all societies).
  Future<void> clearAllData() async {
    const none = '00000000-0000-0000-0000-000000000000';
    for (final table in const [
      'meetings',
      'visitors',
      'blacklist',
      'resident_vehicles',
      'members',
      'flats',
      'guard_shifts'
    ]) {
      await db.from(table).delete().neq('id', none);
    }
  }

  // ---------------------------------------------------------------------------
  // Onboarding payments

  /// Web `loadOnboarding`.
  Future<List<OnboardingRow>> loadOnboarding() async {
    final orders = rowsOf(await db
        .from('society_orders')
        .select(
            'id, signup_id, status, amount_inr, currency, provider, merchant_transaction_id, created_at')
        .order('created_at', ascending: false)
        .limit(200));
    final ids = distinctSignupIds(orders);
    var signups = const <Map<String, dynamic>>[];
    if (ids.isNotEmpty) {
      signups = rowsOf(await db
          .from('society_signups')
          .select(
              'id, status, society_name, contact_phone, contact_person, referral_code_used, created_at')
          .inFilter('id', ids));
    }
    return joinOnboarding(orders, signups);
  }

  // ---------------------------------------------------------------------------
  // Support tickets

  Future<List<SupportTicket>> loadTickets() async {
    final rows = rowsOf(await db
        .from('support_tickets')
        .select('*')
        .order('ticket_number', ascending: false));
    return rows.map(SupportTicket.fromJson).toList();
  }

  Future<void> setTicketStatus(String id, String status) =>
      db.from('support_tickets').update({'status': status}).eq('id', id);

  /// Web `fetchSocietyNotificationSound(societyId)`.
  Future<({String soundKey, String? soundCustomUrl})> societyNotificationSound(
      String? societyId) async {
    if (societyId == null || societyId.isEmpty) {
      return (soundKey: 'digital', soundCustomUrl: null);
    }
    try {
      final row = await db
          .from('societies')
          .select('admin_push_sound_url')
          .eq('id', societyId)
          .maybeSingle();
      final url = (row?['admin_push_sound_url'] as String?)?.trim();
      if (url != null && url.isNotEmpty) {
        return (soundKey: 'custom', soundCustomUrl: url);
      }
    } catch (_) {}
    return (soundKey: 'digital', soundCustomUrl: null);
  }

  /// Web `sendReply(t)`: store the reply, notify the resident in-app, then push (best effort).
  Future<String?> replyToTicket({
    required SupportTicket ticket,
    required String body,
    required String superadminId,
    required String superadminName,
  }) async {
    try {
      await db.from('support_tickets').update({
        'superadmin_reply': body,
        'replied_at': DateTime.now().toUtc().toIso8601String(),
        'replied_by_superadmin_id': superadminId,
      }).eq('id', ticket.id);
    } on PostgrestException catch (e) {
      return e.message;
    }

    final title = 'Support · Ticket #${ticket.ticketNumber}';
    final sound = await societyNotificationSound(ticket.societyId);
    try {
      await db.from('notifications').insert({
        'society_id': ticket.societyId,
        'title': title,
        'message': body,
        'type': 'support',
        'target_type': 'user',
        'target_id': ticket.submitterResidentId,
        'created_by': 'Superadmin ($superadminName)',
        'media_items': <Object>[],
        'sound_key': sound.soundKey,
        'sound_custom_url': sound.soundCustomUrl,
      });
    } on PostgrestException catch (e) {
      return e.message;
    }

    try {
      await db.functions.invoke('send-push-notification', body: {
        'title': title,
        'message': body.length > 180 ? body.substring(0, 180) : body,
        'target_type': 'user',
        'target_ids': [ticket.submitterResidentId],
        'society_id': ticket.societyId,
        'sound_key': sound.soundKey,
        'sound_custom_url': sound.soundCustomUrl ?? '',
      });
    } catch (_) {
      // Web: `console.warn('Push invoke:', e)` — in-app notification already stored.
    }
    return null;
  }
}
