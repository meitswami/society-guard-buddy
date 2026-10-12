import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/ui/ui.dart';
import '../gate_i18n.dart';
import 'gate_photo.dart';

/// Web `PhotoCapture`: label with count, 64px previews with remove, Camera / Upload buttons.
/// Photos are compressed (max 800px, JPEG q70) and kept as data URLs, exactly like the web.
class PhotoCapture extends StatefulWidget {
  const PhotoCapture({super.key, required this.photos, required this.onChanged, this.maxPhotos = 3, this.label});

  final List<String> photos;
  final ValueChanged<List<String>> onChanged;
  final int maxPhotos;
  final String? label;

  @override
  State<PhotoCapture> createState() => _PhotoCaptureState();
}

class _PhotoCaptureState extends State<PhotoCapture> {
  final _picker = ImagePicker();
  bool _busy = false;

  int get _remaining => widget.maxPhotos - widget.photos.length;

  Future<void> _add(List<XFile> files) async {
    if (files.isEmpty) return;
    final out = [...widget.photos];
    try {
      for (final f in files) {
        if (out.length >= widget.maxPhotos) break;
        out.add(await compressToJpegDataUrl(await f.readAsBytes()));
      }
    } catch (_) {
      if (mounted) AppFeedback.toast(context, context.gt('gate.photo.failed'), tone: BadgeTone.alert);
    }
    if (out.length != widget.photos.length) widget.onChanged(out);
  }

  Future<void> _run(Future<List<XFile>> Function() pick) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _add(await pick());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _camera() => _run(() async {
        try {
          final f = await _picker.pickImage(
            source: ImageSource.camera,
            preferredCameraDevice: CameraDevice.rear,
            maxWidth: 1600,
            maxHeight: 1600,
            imageQuality: 90,
          );
          return f == null ? const <XFile>[] : [f];
        } catch (_) {
          // Camera not available — fall back to the gallery like the web file picker.
          final f = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, maxHeight: 1600, imageQuality: 90);
          return f == null ? const <XFile>[] : [f];
        }
      });

  Future<void> _upload() => _run(() async {
        if (_remaining <= 1) {
          final f = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, maxHeight: 1600, imageQuality: 90);
          return f == null ? const <XFile>[] : [f];
        }
        final files = await _picker.pickMultiImage(maxWidth: 1600, maxHeight: 1600, imageQuality: 90, limit: _remaining);
        return files.take(_remaining).toList();
      });

  void _remove(int index) {
    final out = [...widget.photos]..removeAt(index);
    widget.onChanged(out);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final label = widget.label ?? context.tr('Photos', 'फोटो');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        FieldLabel('$label (${widget.photos.length}/${widget.maxPhotos})'),
        if (widget.photos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < widget.photos.length; i++)
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                      border: Border.all(color: t.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        GatePhoto(src: widget.photos[i], size: 64, round: false),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Material(
                            color: t.destructive,
                            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(6)),
                            child: InkWell(
                              onTap: () => _remove(i),
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: Icon(Icons.close, size: 12, color: t.destructiveForeground),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        if (_remaining > 0)
          Row(
            children: [
              Expanded(
                child: AppButton.secondary(
                  label: context.gt('gate.photo.camera'),
                  icon: Icons.photo_camera_outlined,
                  dense: true,
                  loading: _busy,
                  onPressed: _busy ? null : _camera,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton.secondary(
                  label: context.gt('gate.photo.upload'),
                  icon: Icons.add_photo_alternate_outlined,
                  dense: true,
                  onPressed: _busy ? null : _upload,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
