import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../core/ui/ui.dart';
import '../../../models/session_models.dart';
import '../data/resident_feedback.dart';
import '../data/resident_media.dart';
import '../data/resident_repository.dart';

/// Feedback tab — port of web `ResidentFeedbackForm` (message, voice note, photos / videos →
/// `support_tickets` + `send-feedback-alert`).
class ResidentFeedbackTab extends StatefulWidget {
  const ResidentFeedbackTab({super.key, required this.session});

  final SessionResident session;

  @override
  State<ResidentFeedbackTab> createState() => _ResidentFeedbackTabState();
}

class _ResidentFeedbackTabState extends State<ResidentFeedbackTab> {
  final _repo = const ResidentFeedbackRepository();
  final _message = TextEditingController();
  final _recorder = AudioRecorder();
  final List<PickedMedia> _files = [];
  Uint8List? _voice;
  bool _recording = false;
  bool _submitting = false;

  @override
  void dispose() {
    _message.dispose();
    _recorder.dispose();
    super.dispose();
  }

  void _err(String m) => AppFeedback.toast(context, m, tone: BadgeTone.alert);

  Future<void> _startRecording() async {
    try {
      if (!await _recorder.hasPermission()) {
        if (mounted) _err(context.tr('Could not access microphone', 'माइक्रोफ़ोन उपलब्ध नहीं हो सका'));
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/feedback_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      if (mounted) setState(() => _recording = true);
    } catch (_) {
      if (mounted) _err(context.tr('Could not access microphone', 'माइक्रोफ़ोन उपलब्ध नहीं हो सका'));
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _recorder.stop();
      if (!mounted) return;
      setState(() => _recording = false);
      if (path != null) {
        final bytes = await File(path).readAsBytes();
        if (mounted) setState(() => _voice = bytes);
      }
    } catch (_) {
      if (mounted) setState(() => _recording = false);
    }
  }

  Future<void> _pick() async {
    final picked = await ResidentMedia.pickFeedbackMedia(context);
    if (picked.isEmpty || !mounted) return;
    final next = List.of(_files);
    for (final f in picked) {
      if (!f.isImage && !f.isVideo) {
        _err(context.tr('${f.name}: use an image or video', '${f.name}: चित्र या वीडियो चुनें'));
        continue;
      }
      if (next.length >= kFeedbackMaxAttachments) {
        _err(context.tr('Maximum $kFeedbackMaxAttachments files', 'अधिकतम $kFeedbackMaxAttachments फ़ाइलें'));
        break;
      }
      next.add(f);
    }
    setState(() {
      _files
        ..clear()
        ..addAll(next);
    });
  }

  String _issueText(String name, FeedbackFileIssue i) => switch (i) {
        FeedbackFileIssue.notMedia => context.tr('$name: use an image or video', '$name: चित्र या वीडियो चुनें'),
        FeedbackFileIssue.imageTooLarge => context.tr('Image too large (max 12MB): $name', 'चित्र बहुत बड़ा है (अधिकतम 12MB): $name'),
        FeedbackFileIssue.videoTooLarge => context.tr('Video too large (max 50MB): $name', 'वीडियो बहुत बड़ा है (अधिकतम 50MB): $name'),
        FeedbackFileIssue.uploadFailed => context.tr('Upload failed: $name', 'अपलोड विफल: $name'),
      };

  Future<void> _submit() async {
    final text = _message.text.trim();
    final s = widget.session;
    if (s.societyId.isEmpty) {
      _err(context.tr('Society is not loaded. Try again in a moment.', 'सोसाइटी लोड नहीं हुई। थोड़ी देर में फिर कोशिश करें।'));
      return;
    }
    if (text.isEmpty && _files.isEmpty && _voice == null) {
      _err(context.tr('Add a message, voice note, or at least one image/video', 'संदेश, आवाज़ नोट या कम से कम एक चित्र / वीडियो जोड़ें'));
      return;
    }
    setState(() => _submitting = true);
    try {
      final societyName = await const ResidentRepository().fetchSocietyName(s.societyId);
      var media = <Map<String, String>>[];
      if (_files.isNotEmpty) {
        final report = await _repo.uploadFiles(_files, s.resident.id);
        media = report.items;
        if (mounted) {
          for (final issue in report.issues) {
            _err(_issueText(issue.$1, issue.$2));
          }
        }
      }
      String? audioUrl;
      final voice = _voice;
      if (voice != null) {
        if (voice.length > kFeedbackMaxAudioBytes) {
          if (mounted) _err(context.tr('Recording is too long or too large (max 15MB)', 'रिकॉर्डिंग बहुत लंबी या बड़ी है (अधिकतम 15MB)'));
        } else {
          try {
            audioUrl = await _repo.uploadVoice(voice, s.resident.id);
          } catch (e) {
            if (mounted) _err('$e');
          }
        }
        if (audioUrl == null && text.isEmpty && media.isEmpty) {
          if (mounted) setState(() => _submitting = false);
          return;
        }
      }
      await _repo.insertTicket(
        societyId: s.societyId,
        societyName: societyName,
        residentId: s.resident.id,
        residentName: s.resident.name,
        flatNumber: s.resident.flatNumber,
        message: text,
        mediaItems: media,
        audioUrl: audioUrl,
      );
      if (!mounted) return;
      AppFeedback.toast(context, context.tr('Thanks! Your feedback was sent to support.', 'धन्यवाद! आपकी प्रतिक्रिया सहायता टीम को भेज दी गई।'),
          tone: BadgeTone.success);
      setState(() {
        _message.clear();
        _files.clear();
        _voice = null;
      });
    } catch (e) {
      if (mounted) _err(context.tr('Could not submit feedback: $e', 'प्रतिक्रिया जमा नहीं हो सकी: $e'));
    }
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return PageContainer(
      children: [
        PageHeader(
          title: context.t('resident.feedback'),
          subtitle: context.tr(
              'Report bugs or ideas. Include details — the developer gets your flat, name, and society automatically.',
              'गड़बड़ी या सुझाव बताएँ। विवरण लिखें — डेवलपर को आपका फ्लैट, नाम और सोसाइटी अपने आप मिल जाती है।'),
          icon: Icons.chat_bubble_outline,
        ),
        CardSection(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            FieldLabel(context.tr('Message (optional if you send voice or media)', 'संदेश (आवाज़ या मीडिया भेजने पर वैकल्पिक)')),
            AppTextField(
              controller: _message,
              hint: context.tr('Describe what happened or what you would like…', 'बताएँ क्या हुआ या आप क्या चाहते हैं…'),
              maxLines: 8,
              minLines: 5,
              caps: false,
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              if (!_recording)
                AppButton.secondary(
                  label: context.tr('Record voice', 'आवाज़ रिकॉर्ड करें'),
                  icon: Icons.mic_none,
                  dense: true,
                  expand: false,
                  onPressed: _submitting ? null : _startRecording,
                )
              else
                AppButton(
                  label: context.tr('Stop', 'रोकें'),
                  icon: Icons.stop,
                  variant: AppButtonVariant.destructive,
                  dense: true,
                  expand: false,
                  onPressed: _stopRecording,
                ),
              if (_voice != null && !_recording) ...[
                Text(context.tr('Voice note ready (${(_voice!.length / 1024).round()} KB)', 'आवाज़ नोट तैयार (${(_voice!.length / 1024).round()} KB)'),
                    style: AppText.caption(context)),
                TextButton(
                  onPressed: () => setState(() => _voice = null),
                  style: TextButton.styleFrom(foregroundColor: t.destructive, visualDensity: VisualDensity.compact),
                  child: Text(context.tr('Remove', 'हटाएँ')),
                ),
              ],
            ]),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton.secondary(
                label: context.tr('Photos / videos', 'फ़ोटो / वीडियो'),
                icon: Icons.attach_file,
                dense: true,
                expand: false,
                onPressed: _submitting ? null : _pick,
              ),
            ),
            for (var i = 0; i < _files.length; i++)
              Row(children: [
                Icon(_files[i].isVideo ? Icons.videocam_outlined : Icons.image_outlined, size: 14, color: t.mutedForeground),
                const SizedBox(width: 6),
                Expanded(child: Text(_files[i].name, style: AppText.caption(context), overflow: TextOverflow.ellipsis)),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close, size: 16, color: t.destructive),
                  onPressed: () => setState(() => _files.removeAt(i)),
                ),
              ]),
            const SizedBox(height: 12),
            AppButton(
              label: _submitting ? context.tr('Sending…', 'भेज रहे हैं…') : context.tr('Send feedback', 'प्रतिक्रिया भेजें'),
              icon: Icons.send,
              loading: _submitting,
              onPressed: _submit,
            ),
          ]),
        ),
      ],
    );
  }
}
