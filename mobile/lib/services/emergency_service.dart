import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/env.dart';
import '../core/supabase/supabase_bootstrap.dart';

class EmergencyAlertResult {
  const EmergencyAlertResult({required this.success, this.error});

  final bool success;
  final String? error;
}

class EmergencyService {
  Future<EmergencyAlertResult> sendAlert({
    required String societyId,
    required String title,
    required String message,
    required String senderRole,
    required String senderName,
    String? senderFlatNumber,
    List<({Uint8List bytes, String mimeType, String fileName})> images = const [],
  }) async {
    if (!Env.isConfigured) {
      return const EmergencyAlertResult(success: false, error: 'Supabase not configured');
    }

    final mediaItems = <Map<String, String>>[];
    for (final img in images) {
      if (!img.mimeType.startsWith('image/')) continue;
      final safe = img.fileName.replaceAll(RegExp(r'[^\w.-]'), '_');
      final path = 'emergency/${DateTime.now().millisecondsSinceEpoch}_$safe';
      await SupabaseBootstrap.client.storage.from('notification-media').uploadBinary(
            path,
            img.bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );
      final url = SupabaseBootstrap.client.storage.from('notification-media').getPublicUrl(path);
      mediaItems.add({'url': url, 'kind': 'image'});
    }

    final response = await SupabaseBootstrap.client.functions.invoke(
      'send-emergency-alert',
      body: {
        'society_id': societyId,
        'title': title.trim().isEmpty ? '🚨 EMERGENCY ALERT' : title.trim(),
        'message': message.trim(),
        'sender_role': senderRole,
        'sender_name': senderName,
        'sender_flat_number': senderFlatNumber,
        'media_items': mediaItems,
      },
    );

    final data = response.data;
    if (response.status != 200) {
      return EmergencyAlertResult(
        success: false,
        error: data is Map ? data['error']?.toString() : 'Request failed',
      );
    }
    if (data is Map && data['error'] != null) {
      return EmergencyAlertResult(success: false, error: data['error'].toString());
    }
    return const EmergencyAlertResult(success: true);
  }
}
