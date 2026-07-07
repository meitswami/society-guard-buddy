import '../core/config/env.dart';
import '../core/supabase/supabase_bootstrap.dart';
import '../models/society_document.dart';

class SocietyDocumentService {
  Future<List<SocietyDocument>> fetchPublished(String societyId) async {
    if (!Env.isConfigured) return const [];

    final rows = await SupabaseBootstrap.client
        .from('society_documents')
        .select('*')
        .eq('society_id', societyId)
        .eq('published', true)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((r) => SocietyDocument.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<String?> createSignedUrl(String storagePath, {int ttlSeconds = 300}) async {
    if (!Env.isConfigured) return null;

    final result = await SupabaseBootstrap.client.storage
        .from('society-documents')
        .createSignedUrl(storagePath, ttlSeconds);

    return result;
  }
}
