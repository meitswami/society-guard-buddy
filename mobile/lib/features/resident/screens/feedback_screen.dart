import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../core/theme/kutumbika_brand_theme.dart';
import '../../../core/theme/kutumbika_colors.dart';
import '../../../models/session_models.dart';
import '../../../services/feedback_service.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key, required this.session});

  final SessionResident session;

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _service = FeedbackService();
  final _messageCtrl = TextEditingController();
  final _images = <({Uint8List bytes, String fileName})>[];
  final _recorder = AudioRecorder();
  Uint8List? _audioBytes;
  String _audioFileName = 'voice.m4a';
  bool _recording = false;
  bool _submitting = false;

  @override
  void dispose() {
    _messageCtrl.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_images.length >= 6) return;
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _images.add((bytes: bytes, fileName: file.name)));
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      final path = await _recorder.stop();
      setState(() => _recording = false);
      if (path != null && !kIsWeb) {
        final bytes = await File(path).readAsBytes();
        setState(() {
          _audioBytes = bytes;
          _audioFileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        });
      }
      return;
    }

    if (!await _recorder.hasPermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission required')),
      );
      return;
    }

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/feedback_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    setState(() {
      _recording = true;
      _audioBytes = null;
    });
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await _service.submitResidentFeedback(
        societyId: widget.session.societyId,
        societyName: widget.session.societyName,
        residentId: widget.session.resident.id,
        residentName: widget.session.resident.name,
        flatNumber: widget.session.resident.flatNumber,
        message: _messageCtrl.text,
        images: _images,
        audioBytes: _audioBytes,
        audioFileName: _audioFileName,
      );
      if (!mounted) return;
      _messageCtrl.clear();
      setState(() {
        _images.clear();
        _audioBytes = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks! Your feedback was sent.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = KutumbikaBrandTheme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Complaints & feedback')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Share a complaint, suggestion, or issue. Our support team will review it.',
              style: const TextStyle(color: KutumbikaColors.textMuted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _messageCtrl,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: 'Describe your feedback…',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (var i = 0; i < _images.length; i++)
                  Chip(
                    label: Text('Photo ${i + 1}'),
                    onDeleted: () => setState(() => _images.removeAt(i)),
                  ),
                if (_images.length < 6)
                  ActionChip(
                    avatar: const Icon(Icons.attach_file, size: 18),
                    label: const Text('Attach photo'),
                    onPressed: _pickImage,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (!kIsWeb)
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: _toggleRecording,
                  icon: Icon(_recording ? Icons.stop : Icons.mic),
                  label: Text(_recording ? 'Stop' : (_audioBytes != null ? 'Re-record' : 'Voice note')),
                ),
                if (_audioBytes != null) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 4),
                  const Text('Voice attached', style: TextStyle(fontSize: 12)),
                ],
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(backgroundColor: brand.primary),
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit feedback'),
            ),
          ],
        ),
      ),
    );
  }
}
