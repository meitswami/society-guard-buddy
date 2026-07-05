import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/kutumbika_brand_theme.dart';
import '../../../models/session_models.dart';
import '../../../services/emergency_service.dart';

class ResidentEmergencyScreen extends StatefulWidget {
  const ResidentEmergencyScreen({super.key, required this.session});

  final SessionResident session;

  @override
  State<ResidentEmergencyScreen> createState() => _ResidentEmergencyScreenState();
}

class _ResidentEmergencyScreenState extends State<ResidentEmergencyScreen> {
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
    final file = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _images.add((bytes: bytes, mimeType: 'image/jpeg', fileName: file.name)));
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
        content: const Text('Broadcasts to ALL residents. Use only for genuine emergencies.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send')),
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
        senderRole: 'resident',
        senderName: widget.session.resident.name,
        senderFlatNumber: widget.session.resident.flatNumber,
        images: _images,
      );
      if (!mounted) return;
      if (result.success) {
        _messageCtrl.clear();
        setState(() => _images.clear());
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Emergency alert sent')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.error ?? 'Failed')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency alert')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Flat ${widget.session.resident.flatNumber}',
              style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(
            controller: _messageCtrl,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'What is happening? *', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < _images.length; i++)
                Chip(label: Text('Photo ${i + 1}'), onDeleted: () => setState(() => _images.removeAt(i))),
              if (_images.length < 4)
                ActionChip(
                  avatar: const Icon(Icons.camera_alt, size: 18),
                  label: const Text('Photo'),
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
        ],
      ),
    );
  }
}
