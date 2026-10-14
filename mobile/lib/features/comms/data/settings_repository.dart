/// Supabase queries behind the Settings page panels (web `SettingsPage.tsx`,
/// `SocietyAppFeaturesPanel`, `SocietyContentEditor`, `SocietyAddressPanel`,
/// `SocietyReportSettingsPanel`, `SocietyBankAccountPanel` / `societyBankAccountService`,
/// `GeofenceSetup`, `AdminPasswordChange`, `adminVerify.ts`).
library;

import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase/db.dart';
import 'notification_media_storage.dart';
import 'society_settings_logic.dart';

/// Counts for the "Data summary" card (web store arrays: flats, members, vehicles,
/// visitors, blacklist of the current society).
class SocietyDataSummary {
  const SocietyDataSummary(
      {this.flats = 0,
      this.members = 0,
      this.vehicles = 0,
      this.visitors = 0,
      this.blacklist = 0});

  final int flats;
  final int members;
  final int vehicles;
  final int visitors;
  final int blacklist;
}

class AppFeatureFlags {
  const AppFeatureFlags({this.selfIdEnabled = false, this.soundUrl});

  final bool selfIdEnabled;
  final String? soundUrl;
}

class SocietyAddress {
  const SocietyAddress(
      {this.name = '',
      this.address = '',
      this.city = '',
      this.state = '',
      this.pincode = ''});

  final String name;
  final String address;
  final String city;
  final String state;
  final String pincode;
}

class GeofenceRow {
  const GeofenceRow(
      {required this.id,
      required this.latitude,
      required this.longitude,
      required this.radiusMeters});

  final String id;
  final double latitude;
  final double longitude;
  final int radiusMeters;

  factory GeofenceRow.fromRow(Map<String, dynamic> r) {
    double d(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    return GeofenceRow(
      id: r['id']?.toString() ?? '',
      latitude: d(r['latitude']),
      longitude: d(r['longitude']),
      radiusMeters: d(r['radius_meters']).round(),
    );
  }
}

const String kSocietyDocumentsBucket = 'society-documents';

const _fullLetterheadSelect =
    'id, name, logo_url, letterhead_url, letterhead_storage_path, letterhead_mode, letterhead_top_mm, letterhead_bottom_mm, letterhead_left_mm, letterhead_right_mm, default_report_format, address, city, state, pincode, contact_phone, contact_email';
const _fallbackLetterheadSelect =
    'id, name, logo_url, letterhead_url, letterhead_mode, letterhead_top_mm, letterhead_bottom_mm, address, city, state, pincode, contact_phone, contact_email';

class SettingsRepository {
  const SettingsRepository();

  // ---- Data summary ------------------------------------------------------------------

  Future<int> _count(String table, String societyId) async {
    final res = await db
        .from(table)
        .select('id')
        .eq('society_id', societyId)
        .limit(1)
        .count(CountOption.exact);
    return res.count;
  }

  Future<SocietyDataSummary> loadDataSummary(String societyId) async {
    if (!dbReady) return const SocietyDataSummary();
    final flatRows =
        rowsOf(await db.from('flats').select('id').eq('society_id', societyId));
    final flatIds = flatRows.map((r) => r['id'].toString()).toList();
    final results = await Future.wait<int>([
      _count('resident_vehicles', societyId),
      _count('visitors', societyId),
      _count('blacklist', societyId),
      if (flatIds.isEmpty)
        Future.value(0)
      else
        db
            .from('members')
            .select('id')
            .inFilter('flat_id', flatIds)
            .limit(1)
            .count(CountOption.exact)
            .then((r) => r.count),
    ]);
    return SocietyDataSummary(
      flats: flatIds.length,
      vehicles: results[0],
      visitors: results[1],
      blacklist: results[2],
      members: results[3],
    );
  }

  // ---- App features (self ID + signature tune) ---------------------------------------

  Future<AppFeatureFlags> loadAppFeatures(String societyId) async {
    final row = await db
        .from('societies')
        .select('resident_self_id_upload_enabled, admin_push_sound_url')
        .eq('id', societyId)
        .maybeSingle();
    final url = row?['admin_push_sound_url']?.toString().trim() ?? '';
    return AppFeatureFlags(
        selfIdEnabled: row?['resident_self_id_upload_enabled'] == true,
        soundUrl: url.isEmpty ? null : url);
  }

  Future<void> setSelfIdUpload(String societyId, bool on) async {
    await db
        .from('societies')
        .update({'resident_self_id_upload_enabled': on}).eq('id', societyId);
  }

  /// Upload a society alert tune to `notification-media/admin-sounds/{society}/…` (upsert)
  /// and store it on `societies.admin_push_sound_url`.
  Future<String> uploadSocietySound(
      String societyId, Uint8List bytes, String fileName,
      {String? contentType}) async {
    final path =
        'admin-sounds/$societyId/${DateTime.now().millisecondsSinceEpoch}_${sanitizeStorageFileName(fileName)}';
    final url = await uploadToNotificationMedia(path, bytes,
        contentType: contentType, upsert: true);
    await db
        .from('societies')
        .update({'admin_push_sound_url': url}).eq('id', societyId);
    return url;
  }

  Future<void> clearSocietySound(String societyId) async {
    await db
        .from('societies')
        .update({'admin_push_sound_url': null}).eq('id', societyId);
  }

  // ---- Member content translations ----------------------------------------------------

  Future<List<Map<String, dynamic>>> loadContentTranslations(
      String societyId) async {
    final data = await db
        .from('society_content_translations')
        .select('content_key, text_en, text_hi')
        .eq('society_id', societyId);
    return rowsOf(data);
  }

  Future<void> upsertContentTranslations(
      List<Map<String, dynamic>> rows) async {
    await db
        .from('society_content_translations')
        .upsert(rows, onConflict: 'society_id,content_key');
  }

  Future<void> deleteContentTranslations(
      String societyId, List<String> keys) async {
    await db
        .from('society_content_translations')
        .delete()
        .eq('society_id', societyId)
        .inFilter('content_key', keys);
  }

  // ---- Address -----------------------------------------------------------------------

  Future<SocietyAddress> loadAddress(String societyId) async {
    final row = await db
        .from('societies')
        .select('name, address, city, state, pincode')
        .eq('id', societyId)
        .maybeSingle();
    String s(String k) => row?[k]?.toString() ?? '';
    return SocietyAddress(
        name: s('name'),
        address: s('address'),
        city: s('city'),
        state: s('state'),
        pincode: s('pincode'));
  }

  Future<void> saveAddress(String societyId, Map<String, dynamic> patch) async {
    await db.from('societies').update(patch).eq('id', societyId);
  }

  // ---- Report settings / letterhead ---------------------------------------------------

  /// Web `fetchSocietyLetterhead` (full select, then the fallback column set).
  Future<SocietyLetterheadInfo?> loadLetterhead(String societyId) async {
    Map<String, dynamic>? data;
    try {
      data = await db
          .from('societies')
          .select(_fullLetterheadSelect)
          .eq('id', societyId)
          .maybeSingle();
    } on PostgrestException {
      data = await db
          .from('societies')
          .select(_fallbackLetterheadSelect)
          .eq('id', societyId)
          .maybeSingle();
    }
    if (data == null) return null;
    final rowId = data['id']?.toString();
    if (rowId != null && rowId != societyId) return null;
    return SocietyLetterheadInfo.fromRow(data);
  }

  /// Signed URL (1 h) for a private `society-documents` object; null when it fails.
  Future<String?> signedDocumentUrl(String? path) async {
    if (path == null || path.trim().isEmpty) return null;
    try {
      return await db.storage
          .from(kSocietyDocumentsBucket)
          .createSignedUrl(path, 3600);
    } catch (_) {
      return null;
    }
  }

  /// Web `uploadLetterheadToSocietyDocuments`: `{society}/letterhead/{uuid}_{name}`.
  Future<({String path, String signedUrl})> uploadLetterhead(
      String societyId, Uint8List bytes, String fileName,
      {String? contentType}) async {
    final safe = fileName.replaceAll(RegExp(r'[^\w.-]'), '_');
    final path = '$societyId/letterhead/${const Uuid().v4()}_$safe';
    final bucket = db.storage.from(kSocietyDocumentsBucket);
    await bucket.uploadBinary(path, bytes,
        fileOptions: FileOptions(
            cacheControl: '3600', upsert: false, contentType: contentType));
    final signed = await bucket.createSignedUrl(path, 3600);
    return (path: path, signedUrl: signed);
  }

  Future<void> removeDocument(String path) async {
    try {
      await db.storage.from(kSocietyDocumentsBucket).remove([path]);
    } catch (_) {
      // Best effort (web ignores the result).
    }
  }

  Future<void> updateSociety(
      String societyId, Map<String, dynamic> patch) async {
    await db.from('societies').update(patch).eq('id', societyId);
  }

  // ---- Dashboard banners -------------------------------------------------------------

  Future<List<Map<String, dynamic>>> loadBanners(String societyId) async {
    final data = await db
        .from('society_dashboard_banners')
        .select('*')
        .eq('society_id', societyId)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: false);
    return rowsOf(data);
  }

  Future<void> addBanner(
      {required String societyId,
      required String imageUrl,
      String? title,
      required int sortOrder}) async {
    await db.from('society_dashboard_banners').insert({
      'society_id': societyId,
      'image_url': imageUrl,
      'title': title,
      'is_active': true,
      'sort_order': sortOrder,
    });
  }

  Future<void> updateBanner(
      String societyId, String id, Map<String, dynamic> patch) async {
    await db
        .from('society_dashboard_banners')
        .update(patch)
        .eq('id', id)
        .eq('society_id', societyId);
  }

  Future<void> deleteBanner(String societyId, String id) async {
    await db
        .from('society_dashboard_banners')
        .delete()
        .eq('id', id)
        .eq('society_id', societyId);
  }

  /// Web `moveBanner`: swap the two `sort_order` values.
  Future<void> swapBannerOrder(
      Map<String, dynamic> a, Map<String, dynamic> b) async {
    await db
        .from('society_dashboard_banners')
        .update({'sort_order': b['sort_order']}).eq('id', a['id']);
    await db
        .from('society_dashboard_banners')
        .update({'sort_order': a['sort_order']}).eq('id', b['id']);
  }

  // ---- Society bank account ----------------------------------------------------------

  Future<List<SocietyBankAccountRow>> loadBankAccounts(String societyId) async {
    final data = await db
        .from('society_bank_accounts')
        .select('*')
        .eq('society_id', societyId)
        .order('is_primary', ascending: false)
        .order('created_at', ascending: false);
    return rowsOf(data).map(SocietyBankAccountRow.fromRow).toList();
  }

  /// Web `upsertSocietyBankAccount`: demote other primaries, then update or insert.
  Future<SocietyBankAccountRow> upsertBankAccount(
      String societyId, BankAccountInput input,
      {String? existingId}) async {
    final payload = buildBankAccountPayload(societyId, input);
    if (payload['is_primary'] == true) {
      var demote = db
          .from('society_bank_accounts')
          .update({'is_primary': false})
          .eq('society_id', societyId)
          .eq('is_primary', true);
      if (existingId != null) demote = demote.neq('id', existingId);
      await demote;
    }
    final Map<String, dynamic> row;
    if (existingId != null) {
      row = await db
          .from('society_bank_accounts')
          .update(payload)
          .eq('id', existingId)
          .select('*')
          .single();
    } else {
      row = await db
          .from('society_bank_accounts')
          .insert(payload)
          .select('*')
          .single();
    }
    return SocietyBankAccountRow.fromRow(row);
  }

  // ---- Geofence ----------------------------------------------------------------------

  Future<GeofenceRow?> loadGeofence(String societyId) async {
    final data = await db
        .from('geofence_settings')
        .select('*')
        .eq('society_id', societyId)
        .order('created_at', ascending: false)
        .limit(1);
    final rows = rowsOf(data);
    return rows.isEmpty ? null : GeofenceRow.fromRow(rows.first);
  }

  Future<void> saveGeofence({
    required String societyId,
    required String? existingId,
    required double latitude,
    required double longitude,
    required int radius,
    required String setBy,
  }) async {
    if (existingId != null) {
      await db
          .from('geofence_settings')
          .update({
            'latitude': latitude,
            'longitude': longitude,
            'radius_meters': radius,
            'set_by': setBy,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', existingId)
          .eq('society_id', societyId);
    } else {
      await db.from('geofence_settings').insert({
        'society_id': societyId,
        'latitude': latitude,
        'longitude': longitude,
        'radius_meters': radius,
        'set_by': setBy,
      });
    }
  }

  Future<void> deleteGeofence(String societyId, String id) async {
    await db
        .from('geofence_settings')
        .delete()
        .eq('id', id)
        .eq('society_id', societyId);
  }

  // ---- Admin password ----------------------------------------------------------------

  /// Web `verifyAdminPassword` (trimmed password, `admins.id` + `password`).
  Future<bool> verifyAdminPassword(String adminId, String password) async {
    final trimmed = password.trim();
    if (trimmed.isEmpty) return false;
    try {
      final row = await db
          .from('admins')
          .select('id')
          .eq('id', adminId)
          .eq('password', trimmed)
          .maybeSingle();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  /// Web `AdminPasswordChange`: the current password is checked as typed.
  Future<bool> currentPasswordMatches(String adminId, String current) async {
    final row = await db
        .from('admins')
        .select('id')
        .eq('id', adminId)
        .eq('password', current)
        .maybeSingle();
    return row != null;
  }

  Future<void> setAdminPassword(String adminId, String newPassword) async {
    await db.from('admins').update({'password': newPassword}).eq('id', adminId);
  }
}
