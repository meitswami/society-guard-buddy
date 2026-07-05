import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_bootstrap.dart';

class MediaUploadService {
  Future<String?> uploadImage({
    required Uint8List bytes,
    required String folder,
    String fileName = 'photo.jpg',
    String mimeType = 'image/jpeg',
  }) async {
    if (!mimeType.startsWith('image/')) return null;
    final safe = fileName.replaceAll(RegExp(r'[^\w.-]'), '_');
    final path = '$folder/${DateTime.now().millisecondsSinceEpoch}_$safe';
    await SupabaseBootstrap.client.storage.from('notification-media').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, cacheControl: '3600', upsert: false),
        );
    return SupabaseBootstrap.client.storage.from('notification-media').getPublicUrl(path);
  }

  Future<List<Map<String, String>>> uploadImages(
    List<({Uint8List bytes, String fileName})> files,
    String folder,
  ) async {
    final items = <Map<String, String>>[];
    for (final f in files) {
      final url = await uploadImage(bytes: f.bytes, folder: folder, fileName: f.fileName);
      if (url != null) items.add({'url': url, 'kind': 'image'});
    }
    return items;
  }
}
