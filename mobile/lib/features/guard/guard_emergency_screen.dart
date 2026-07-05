import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/kutumbika_brand_theme.dart';
import '../../models/session_models.dart';
import '../../services/emergency_service.dart';

class GuardEmergencyScreen extends StatefulWidget {
  const GuardEmergencyScreen({super.key, required this.session});

  final SessionGuard session;

  @override
  State<GuardEmergencyScreen> createState() => _GuardEmergencyScreenState();
}

class _GuardEmergencyScreenState extends State<GuardEmergencyScreen> {
  final _service = EmergencyService();
  final _titleCtrl = TextEditingController(text: '🚨 EMERGENCY ALERT');
  final _messageCtrl = TextEditingController();
  final _images = <({Uint8List bytes, String mimeType, String fileName})>[];
  bool _sending = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_images.length >= 4) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _images.add((bytes: bytes, mimeType: 'image/jpeg', fileName: file.name));
    });
  }

  Future<void> _send() async {
    if (_messageCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Describe the emergency')),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send emergency alert?'),
        content: const Text(
          'This broadcasts to ALL residents. Use only for genuine emergencies.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send now')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _sending = true);
    try {
      final result = await _service.sendAlert(
        societyId: widget.session.societyId,
        title: _titleCtrl.text,
        message: _messageCtrl.text,
        senderRole: 'guard',
        senderName: widget.session.guard.name,
        images: _images,
      );
      if (!mounted) return;
      if (result.success) {
        _messageCtrl.clear();
        setState(() => _images.clear());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Emergency alert sent')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? 'Failed to send')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = KutumbikaBrandTheme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Emergency alert')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Broadcasts to all residents via notifications and push (where configured).',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _messageCtrl,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'What is happening? *',
              border: OutlineInputBorder(),
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
              if (_images.length < 4)
                ActionChip(
                  avatar: const Icon(Icons.camera_alt, size: 18),
                  label: const Text('Add photo'),
                  onPressed: _pickImage,
                ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _sending ? null : _send,
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              minimumSize: const Size.fromHeight(48),
            ),
            child: _sending
                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Send emergency alert'),
          ),
          const SizedBox(height: 8),
          Text('Sender: ${widget.session.guard.name}', style: TextStyle(fontSize: 12, color: brand.primary)),
        ],
      ),
    );
  }
}
