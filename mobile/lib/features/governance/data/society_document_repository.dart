import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/db.dart';
import '../logic/document_logic.dart';
import '../models/society_document_models.dart';
import 'gov_backend.dart';

/// Supabase access for society documents — same table / private bucket as web
/// `SocietyDocumentsManager.tsx`.
class SocietyDocumentRepository {
  const SocietyDocumentRepository(this.societyId);

  final String societyId;

  StorageFileApi get _bucket => db.storage.from(GovBackend.societyDocumentsBucket);

  Future<List<SocietyDocumentRow>> load({required bool residentOnly}) async {
    if (!dbReady) return const [];
    var q = db.from('society_documents').select('*').eq('society_id', societyId);
    if (residentOnly) q = q.eq('published', true);
    final rows = rowsOf(await q.order('sort_order', ascending: true).order('created_at', ascending: false));
    return rows.map(SocietyDocumentRow.fromJson).toList();
  }

  Future<String> signedUrl(String storagePath, int ttlSeconds) => _bucket.createSignedUrl(storagePath, ttlSeconds);

  Future<Uint8List> download(String storagePath) => _bucket.download(storagePath);

  /// Upload a file and insert the row (published = false). Removes the object when the insert fails.
  Future<void> upload({
    required String title,
    required String? description,
    required SocietyDocCategory category,
    required Uint8List bytes,
    required String fileName,
    required String? mimeType,
    required int sortOrder,
    required String? uploadedBy,
  }) async {
    final docId = GovBackend.newId();
    final path = societyDocStoragePath(societyId, docId, fileName);
    await _bucket.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(cacheControl: '3600', upsert: false, contentType: mimeType),
    );
    try {
      await db.from('society_documents').insert({
        'id': docId,
        'society_id': societyId,
        'title': title.trim(),
        'description': description == null || description.trim().isEmpty ? null : description.trim(),
        'category': category.value,
        'storage_path': path,
        'file_name': fileName,
        'mime_type': mimeType,
        'published': false,
        'sort_order': sortOrder,
        'uploaded_by': uploadedBy,
      });
    } catch (_) {
      try {
        await _bucket.remove([path]);
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> setPublished(SocietyDocumentRow doc, bool published) => db.from('society_documents').update({
        'published': published,
        'member_reveal_until': published ? doc.memberRevealUntil : null,
      }).eq('id', doc.id);

  Future<void> setRevealUntil(String id, String? untilIso) =>
      db.from('society_documents').update({'member_reveal_until': untilIso}).eq('id', id);

  /// Removes the object (errors are reported but do not stop the row delete, like the web).
  Future<String?> delete(SocietyDocumentRow doc) async {
    String? storageError;
    try {
      await _bucket.remove([doc.storagePath]);
    } catch (e) {
      storageError = GovBackend.errorText(e);
    }
    await db.from('society_documents').delete().eq('id', doc.id);
    return storageError;
  }

  /// Realtime UPDATE feed (web channel `society-docs-{societyId}`).
  RealtimeChannel subscribeUpdates(void Function(Map<String, dynamic> newRow) onUpdate) {
    return db
        .channel('society-docs-$societyId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'society_documents',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'society_id', value: societyId),
          callback: (payload) => onUpdate(Map<String, dynamic>.from(payload.newRecord)),
        )
        .subscribe();
  }
}
