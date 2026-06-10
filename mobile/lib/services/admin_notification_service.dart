import '../core/config/env.dart';
import '../core/supabase/supabase_bootstrap.dart';

class AdminNotificationService {
  Future<void> broadcast({
    required String societyId,
    required String title,
    required String message,
    required String createdBy,
    String targetType = 'all',
  }) async {
    if (!Env.isConfigured) return;

    final text = message.trim();
    if (title.trim().isEmpty || text.isEmpty) {
      throw StateError('Title and message are required');
    }

    await SupabaseBootstrap.client.from('notifications').insert({
      'society_id': societyId,
      'title': title.trim(),
      'message': text,
      'type': 'announcement',
      'target_type': targetType,
      'created_by': createdBy,
    });
  }
}
