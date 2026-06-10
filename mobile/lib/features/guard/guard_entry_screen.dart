import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/kutumbika_brand_theme.dart';
import '../../models/session_models.dart';
import '../../services/media_upload_service.dart';
import '../../services/visitor_entry_service.dart';

class GuardEntryScreen extends StatefulWidget {
  const GuardEntryScreen({super.key, required this.session});

  final SessionGuard session;

  @override
  State<GuardEntryScreen> createState() => _GuardEntryScreenState();
}

class _GuardEntryScreenState extends State<GuardEntryScreen> {
  final _service = VisitorEntryService();
  final _media = MediaUploadService();
  final _photos = <Uint8List>[];
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _flatCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController(text: 'Visit');
  final _vehicleCtrl = TextEditingController();
  bool _hasVehicle = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _flatCtrl.dispose();
    _purposeCtrl.dispose();
    _vehicleCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final flat = _flatCtrl.text.trim();
    if (name.isEmpty || phone.length < 10 || flat.isEmpty) {
      setState(() => _error = 'Name, 10-digit phone, and flat are required');
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });

    try {
      final blocked = await _service.isBlacklisted(
        societyId: widget.session.societyId,
        phone: phone,
      );
      if (blocked) {
        setState(() => _error = 'Visitor is blacklisted');
        return;
      }

      final photoUrls = <String>[];
      for (var i = 0; i < _photos.length; i++) {
        final url = await _media.uploadImage(
          bytes: _photos[i],
          folder: 'visitors/${widget.session.societyId}',
          fileName: 'visitor_$i.jpg',
        );
        if (url != null) photoUrls.add(url);
      }

      await _service.registerVisitor(
        societyId: widget.session.societyId,
        guardId: widget.session.guard.guardId,
        guardName: widget.session.guard.name,
        name: name.toUpperCase(),
        phone: phone,
        flatNumber: flat.toUpperCase(),
        purpose: _purposeCtrl.text.trim().isEmpty ? 'Visit' : _purposeCtrl.text.trim(),
        vehicleNumber: _hasVehicle ? _vehicleCtrl.text.trim().toUpperCase() : null,
        visitorPhotos: photoUrls,
      );

      _nameCtrl.clear();
      _phoneCtrl.clear();
      _flatCtrl.clear();
      _vehicleCtrl.clear();
      setState(() => _photos.clear());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Visitor registered')),
      );
    } catch (_) {
      setState(() => _error = 'Could not register visitor');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = KutumbikaBrandTheme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Visitor name',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneCtrl,
          decoration: const InputDecoration(
            labelText: 'Phone',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.phone,
          maxLength: 10,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _flatCtrl,
          decoration: const InputDecoration(
            labelText: 'Flat number',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _purposeCtrl,
          decoration: const InputDecoration(
            labelText: 'Purpose',
            border: OutlineInputBorder(),
          ),
        ),
        SwitchListTile(
          value: _hasVehicle,
          onChanged: (v) => setState(() => _hasVehicle = v),
          title: const Text('Has vehicle'),
        ),
        if (_hasVehicle)
          TextField(
            controller: _vehicleCtrl,
            decoration: const InputDecoration(
              labelText: 'Vehicle number',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.characters,
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (var i = 0; i < _photos.length; i++)
              Chip(
                label: Text('Photo ${i + 1}'),
                onDeleted: () => setState(() => _photos.removeAt(i)),
              ),
            if (_photos.length < 3)
              ActionChip(
                avatar: const Icon(Icons.camera_alt, size: 18),
                label: const Text('Visitor photo'),
                onPressed: () async {
                  final file = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80);
                  if (file == null) return;
                  final bytes = await file.readAsBytes();
                  setState(() => _photos.add(bytes));
                },
              ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _saving ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: brand.primary,
            minimumSize: const Size.fromHeight(48),
          ),
          child: _saving
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Register visitor'),
        ),
      ],
    );
  }
}
