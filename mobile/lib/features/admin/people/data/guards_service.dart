import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../../../../core/supabase/db.dart';
import '../../../shared/directory/directory_service.dart';
import 'people_models.dart';

/// Guards with their Photo ID documents and attachments (web `loadGuards`).
class GuardsSnapshot {
  const GuardsSnapshot(
      {required this.guards, required this.docs, required this.attachments});

  final List<GuardRow> guards;
  final Map<String, List<GuardDoc>> docs;
  final Map<String, List<GuardAttachment>> attachments;

  static const empty = GuardsSnapshot(guards: [], docs: {}, attachments: {});
}

/// `isPdfUrl` of the web guard manager.
bool isPdfUrl(String url) =>
    RegExp(r'\.pdf($|\?)', caseSensitive: false).hasMatch(url) ||
    url.toLowerCase().contains('application/pdf');

/// Storage-safe file name (web `file.name.replace(/[^a-zA-Z0-9._-]/g, '_')`).
String safeGuardFileName(String name) =>
    name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

/// Content type from a file name (Storage needs it for public viewing).
String contentTypeForFileName(String name) {
  final n = name.toLowerCase();
  if (n.endsWith('.pdf')) return 'application/pdf';
  if (n.endsWith('.png')) return 'image/png';
  if (n.endsWith('.webp')) return 'image/webp';
  if (n.endsWith('.gif')) return 'image/gif';
  if (n.endsWith('.heic')) return 'image/heic';
  if (n.endsWith('.heif')) return 'image/heif';
  return 'image/jpeg';
}

/// Data access of web `AdminGuardManager.tsx`.
class GuardsService {
  static const bucket = 'guard-documents';

  Future<GuardsSnapshot> load(String societyId) async {
    if (!dbReady) return GuardsSnapshot.empty;
    final rows = rowsOf(await db
        .from('guards')
        .select('*')
        .eq('society_id', societyId)
        .order('guard_id', ascending: true));
    final guards = rows.map(GuardRow.fromJson).toList();
    final ids = guards.map((g) => g.id).toList();
    if (ids.isEmpty) {
      return GuardsSnapshot(
          guards: guards, docs: const {}, attachments: const {});
    }
    final results = await Future.wait([
      selectInChunks(
          table: 'guard_documents', columns: '*', column: 'guard_id', ids: ids),
      selectInChunks(
        table: 'guard_attachments',
        columns: '*',
        column: 'guard_id',
        ids: ids,
        build: (q) => q.order('sort_order', ascending: true),
      ),
    ]);
    final docs = <String, List<GuardDoc>>{};
    for (final d in results[0].map(GuardDoc.fromJson)) {
      (docs[d.guardId] ??= []).add(d);
    }
    final atts = <String, List<GuardAttachment>>{};
    for (final a in results[1].map(GuardAttachment.fromJson)) {
      (atts[a.guardId] ??= []).add(a);
    }
    for (final list in atts.values) {
      list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }
    return GuardsSnapshot(guards: guards, docs: docs, attachments: atts);
  }

  /// Web `addGuard` insert.
  Future<void> addGuard({
    required String societyId,
    required String guardId,
    required String name,
    required String password,
    required String authMode,
    required String policeVerification,
    required int kycAlertDays,
    required String phone,
  }) async {
    await db.from('guards').insert({
      'guard_id': guardId.toUpperCase(),
      'name': name,
      'password': password.isEmpty ? 'OTP_AUTH' : password,
      'society_id': societyId,
      'auth_mode': authMode,
      'police_verification': policeVerification,
      'kyc_alert_days': kycAlertDays,
      'phone': phone.isEmpty ? null : phone,
    });
  }

  /// Web `updateGuard`.
  Future<void> updateGuard({
    required String id,
    required String name,
    required String guardId,
    required String authMode,
    required String policeVerification,
    required int kycAlertDays,
    required String phoneDigits,
  }) async {
    await db.from('guards').update({
      'name': name,
      'guard_id': guardId,
      'auth_mode': authMode,
      'police_verification': policeVerification,
      'kyc_alert_days': kycAlertDays,
      'phone': phoneDigits.isEmpty ? null : phoneDigits,
    }).eq('id', id);
  }

  Future<void> deleteGuard(String id) =>
      db.from('guards').delete().eq('id', id);

  Future<void> resetPassword(String id, String password) =>
      db.from('guards').update({'password': password}).eq('id', id);

  /// Web `uploadGuardFile`: `guard-documents/<guardUuid>/<prefix>_<ms>_<safeName>` → public URL.
  Future<String> uploadGuardFile({
    required String guardUuid,
    required Uint8List bytes,
    required String fileName,
    required String prefix,
  }) async {
    final path =
        '$guardUuid/${prefix}_${DateTime.now().millisecondsSinceEpoch}_${safeGuardFileName(fileName)}';
    await db.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions:
              FileOptions(contentType: contentTypeForFileName(fileName)),
        );
    return db.storage.from(bucket).getPublicUrl(path);
  }

  /// Web `uploadProfilePhoto`.
  Future<void> setProfilePhoto(
      {required String guardUuid,
      required Uint8List bytes,
      required String fileName}) async {
    final url = await uploadGuardFile(
        guardUuid: guardUuid,
        bytes: bytes,
        fileName: fileName,
        prefix: 'profile');
    await db.from('guards').update({'photo_url': url}).eq('id', guardUuid);
  }

  Future<void> removeProfilePhoto(String guardUuid) =>
      db.from('guards').update({'photo_url': null}).eq('id', guardUuid);

  /// Web `uploadDoc`: front/back of an ID card; creates a new `guard_documents` row unless [existingDocId].
  Future<void> uploadDoc({
    required String guardUuid,
    required Uint8List bytes,
    required String fileName,
    required String side,
    required String docLabel,
    String? existingDocId,
  }) async {
    final urlKey = '${side}_url';
    final url = await uploadGuardFile(
        guardUuid: guardUuid,
        bytes: bytes,
        fileName: fileName,
        prefix: 'id_$side');
    if (existingDocId != null) {
      await db
          .from('guard_documents')
          .update({urlKey: url}).eq('id', existingDocId);
    } else {
      await db
          .from('guard_documents')
          .insert({'guard_id': guardUuid, 'doc_label': docLabel, urlKey: url});
    }
  }

  /// Web `uploadAttachments` (one row per file, `sort_order` continues after existing ones).
  Future<int> uploadAttachments({
    required String guardUuid,
    required List<({Uint8List bytes, String name})> files,
    required String docLabel,
    required int existingCount,
  }) async {
    var sortBase = existingCount;
    var saved = 0;
    for (final f in files) {
      final url = await uploadGuardFile(
          guardUuid: guardUuid,
          bytes: f.bytes,
          fileName: f.name,
          prefix: 'doc');
      await db.from('guard_attachments').insert({
        'guard_id': guardUuid,
        'file_url': url,
        'file_name': f.name,
        'doc_label': docLabel,
        'sort_order': sortBase++,
      });
      saved++;
    }
    return saved;
  }

  Future<void> deleteDoc(String docId) =>
      db.from('guard_documents').delete().eq('id', docId);

  Future<void> deleteAttachment(String attId) =>
      db.from('guard_attachments').delete().eq('id', attId);
}
