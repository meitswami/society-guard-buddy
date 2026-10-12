
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../../core/ui/ui.dart';
import 'gov_widgets.dart';

Uint8List _compress(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;
  final longest = decoded.width > decoded.height ? decoded.width : decoded.height;
  final resized = longest > 800
      ? img.copyResize(decoded,
          width: decoded.width >= decoded.height ? 800 : null, height: decoded.height > decoded.width ? 800 : null)
      : decoded;
  return Uint8List.fromList(img.encodeJpg(resized, quality: 70));
}

/// Pick a photo (camera or gallery), compress (max 800 px, JPEG q70) and return a
/// data URL like the web `FileReader.readAsDataURL` result.
Future<String?> pickPhotoDataUrl(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: context.tokens.card,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(ctx.tr('Take photo', 'फ़ोटो लें')),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(ctx.tr('Choose from gallery', 'गैलरी से चुनें')),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null) return null;
  final file = await ImagePicker().pickImage(source: source);
  if (file == null) return null;
  final raw = await file.readAsBytes();
  final out = await compute(_compress, raw);
  return imageDataUrl(out);
}
