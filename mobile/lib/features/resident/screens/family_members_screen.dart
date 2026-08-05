import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/kutumbika_brand_theme.dart';
import '../../../core/theme/kutumbika_colors.dart';
import '../../../models/flat_member.dart';
import '../../../models/session_models.dart';
import '../../../services/member_service.dart';
import '../../../utils/member_photo.dart';

const _familyRelations = [
  'Owner',
  'Spouse',
  'Son',
  'Daughter',
  'Father',
  'Mother',
  'Brother',
  'Sister',
  'Tenant',
  'Others',
];

const _staffRoles = [
  'Cook',
  'Maid',
  'Washerman',
  'Newspaper',
  'Driver',
  'Guard',
  'Cleaner',
  'Sweeper',
  'Housekeeper',
  'Mid-servant',
  'Others',
];

class FamilyMembersScreen extends StatefulWidget {
  const FamilyMembersScreen({super.key, required this.session});

  final SessionResident session;

  @override
  State<FamilyMembersScreen> createState() => _FamilyMembersScreenState();
}

class _FamilyMembersScreenState extends State<FamilyMembersScreen> {
  final _service = MemberService();
  List<FlatMember> _members = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final members = await _service.fetchForFlat(widget.session.resident.flatId);
    if (!mounted) return;
    setState(() {
      _members = members;
      _loading = false;
    });
  }

  Future<String?> _pickPhotoDataUrl() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 800,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final mime = file.mimeType ?? 'image/jpeg';
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }

  Future<void> _addMember() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final ageCtrl = TextEditingController();
    var isStaff = false;
    var relation = _familyRelations.first;
    String? photo;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Add family / staff'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Family'), icon: Icon(Icons.family_restroom, size: 16)),
                    ButtonSegment(value: true, label: Text('Staff'), icon: Icon(Icons.cleaning_services, size: 16)),
                  ],
                  selected: {isStaff},
                  onSelectionChanged: (s) => setLocal(() {
                    isStaff = s.first;
                    relation = isStaff ? _staffRoles.first : _familyRelations.first;
                  }),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name *'),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: relation,
                  decoration: InputDecoration(labelText: isStaff ? 'Role' : 'Relation'),
                  items: (isStaff ? _staffRoles : _familyRelations)
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) => setLocal(() => relation = v ?? relation),
                ),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  keyboardType: TextInputType.phone,
                ),
                TextField(
                  controller: ageCtrl,
                  decoration: const InputDecoration(labelText: 'Age'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    memberPhotoAvatar(
                      name: nameCtrl.text.isEmpty ? '?' : nameCtrl.text,
                      photo: photo,
                      backgroundColor: KutumbikaColors.textMuted.withValues(alpha: 0.12),
                      radius: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final data = await _pickPhotoDataUrl();
                          if (data != null) setLocal(() => photo = data);
                        },
                        icon: const Icon(Icons.photo_camera_outlined, size: 18),
                        label: Text(photo == null ? 'Add photo' : 'Change photo'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Photos appear beside election nominees and elected committee members.',
                  style: TextStyle(fontSize: 11, color: KutumbikaColors.textMuted),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required')),
      );
      return;
    }

    final ageText = ageCtrl.text.trim();
    final age = ageText.isEmpty ? null : int.tryParse(ageText);

    try {
      await _service.addMember(
        flatId: widget.session.resident.flatId,
        name: name,
        relation: relation.toLowerCase(),
        phone: phoneCtrl.text.trim(),
        age: age,
        photo: photo,
        householdGroup: 'owner',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Member added')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add member: $e')),
      );
    }
  }

  Future<void> _updatePhoto(FlatMember m) async {
    final data = await _pickPhotoDataUrl();
    if (data == null || !mounted) return;
    try {
      await _service.updatePhoto(memberId: m.id, photo: data);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo saved')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save photo: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = KutumbikaBrandTheme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Family & staff')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addMember,
        backgroundColor: brand.primary,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _members.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(
                          child: Text(
                            'No members yet — add family, servants, guards, cleaners…',
                            style: TextStyle(color: KutumbikaColors.textMuted),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _members.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final m = _members[index];
                        final subtitle = [
                          if (m.relation != null && m.relation!.isNotEmpty) m.relation,
                          if (m.phone != null && m.phone!.isNotEmpty) m.phone,
                          if (m.age != null) 'Age ${m.age}',
                        ].join(' · ');

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: memberPhotoAvatar(
                            name: m.name,
                            photo: m.photo,
                            backgroundColor: brand.primary.withValues(alpha: 0.12),
                            foregroundColor: brand.primary,
                          ),
                          title: Row(
                            children: [
                              Expanded(child: Text(m.name)),
                              if (m.isPrimary)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: brand.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Primary',
                                    style: TextStyle(fontSize: 11, color: brand.primary),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
                          trailing: IconButton(
                            tooltip: 'Update photo',
                            onPressed: () => _updatePhoto(m),
                            icon: Icon(Icons.photo_camera_outlined, color: brand.primary),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
