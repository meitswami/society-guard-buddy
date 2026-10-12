import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/ui/ui.dart';
import '../data/committee_repository.dart';
import '../data/gov_backend.dart';
import '../logic/committee_logic.dart';
import '../widgets/gov_widgets.dart';
import '../widgets/image_pick.dart';

/// Add / edit committee member (web `CommitteeManager` form modal). Pops `true` when saved.
class CommitteeMemberFormPage extends StatefulWidget {
  const CommitteeMemberFormPage({
    super.key,
    required this.societyId,
    required this.flats,
    this.editing,
    this.defaultSortOrder = 0,
  });

  final String societyId;
  final List<CommitteeFlatOption> flats;
  final CommitteeMemberRow? editing;
  final int defaultSortOrder;

  @override
  State<CommitteeMemberFormPage> createState() =>
      _CommitteeMemberFormPageState();
}

class _CommitteeMemberFormPageState extends State<CommitteeMemberFormPage> {
  late final CommitteeRepository _repo = CommitteeRepository(widget.societyId);
  final _flatSearch = TextEditingController();
  final _name = TextEditingController();
  final _customPosition = TextEditingController();
  final _phone = TextEditingController();
  final _repName = TextEditingController();
  final _repPhone = TextEditingController();
  final _sortOrder = TextEditingController();
  String _flatId = '';
  String _flatNumber = '';
  String _flatOwnerName = '';
  String _position = 'Committee Member';
  String _gender = '';
  String _photo = '';
  bool _showRep = false;
  String _repPhoto = '';
  String _termFrom = '';
  String _termTo = '';
  String _selectionType = '';
  bool _saving = false;

  bool get _hi => context.lang == AppLang.hi;

  @override
  void initState() {
    super.initState();
    final r = widget.editing;
    if (r != null) {
      _flatId = r.flatId ?? '';
      _flatNumber = r.flatNumber ?? '';
      _flatOwnerName = r.flatOwnerName ?? '';
      _name.text = r.name;
      _position = r.position;
      if (!committeePositionPresets.contains(r.position)) {
        _customPosition.text = r.position;
      }
      _phone.text = r.phone ?? '';
      _gender = r.gender ?? '';
      _photo = r.photo ?? '';
      _showRep = r.showRepresentative;
      _repName.text = r.repName ?? '';
      _repPhone.text = r.repPhone ?? '';
      _repPhoto = r.repPhoto ?? '';
      _sortOrder.text = '${r.sortOrder}';
      _termFrom = r.termFrom == null
          ? ''
          : r.termFrom!
              .substring(0, r.termFrom!.length >= 10 ? 10 : r.termFrom!.length);
      _termTo = r.termTo == null
          ? ''
          : r.termTo!
              .substring(0, r.termTo!.length >= 10 ? 10 : r.termTo!.length);
      _selectionType = r.selectionType ?? '';
    } else {
      _sortOrder.text = '${widget.defaultSortOrder}';
    }
    _name.addListener(() => setState(() {}));
    _flatSearch.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [
      _flatSearch,
      _name,
      _customPosition,
      _phone,
      _repName,
      _repPhone,
      _sortOrder
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  List<CommitteeFlatOption> get _filteredFlats {
    final q = _flatSearch.text.trim().toLowerCase();
    final list = q.isEmpty
        ? widget.flats
        : widget.flats
            .where((f) =>
                f.flatNumber.toLowerCase().contains(q) ||
                f.primaryMemberName.toLowerCase().contains(q) ||
                (f.ownerName ?? '').toLowerCase().contains(q))
            .toList();
    // Keep the selected flat selectable even when filtered out.
    if (_flatId.isNotEmpty && !list.any((f) => f.id == _flatId)) {
      final sel = widget.flats.where((f) => f.id == _flatId);
      return [...sel, ...list];
    }
    return list;
  }

  void _applyFlat(String? id) {
    final flat = widget.flats.where((f) => f.id == id).firstOrNull;
    setState(() {
      if (flat == null) {
        _flatId = '';
        _flatNumber = '';
        _flatOwnerName = '';
        return;
      }
      final owner = flat.primaryMemberName.isNotEmpty
          ? flat.primaryMemberName
          : (flat.ownerName ?? '').trim();
      _flatId = flat.id;
      _flatNumber = flat.flatNumber;
      _flatOwnerName = owner;
      if (_name.text.trim().isEmpty) _name.text = owner;
      if (_photo.trim().isEmpty) _photo = flat.primaryMemberPhoto ?? '';
    });
  }

  Future<void> _save() async {
    final err = validateCommitteeForm(
      position: _position,
      flatId: _flatId,
      flatNumber: _flatNumber,
      name: _name.text,
      termFrom: _termFrom,
      termTo: _termTo,
      selectionType: _selectionType,
    );
    if (err != null) {
      GovToast.error(context, _hi ? err.$2 : err.$1);
      return;
    }
    final payload = committeeMemberPayload(
      societyId: widget.societyId,
      flatId: _flatId,
      flatNumber: _flatNumber,
      flatOwnerName: _flatOwnerName,
      name: _name.text,
      position: _position,
      phone: _phone.text,
      gender: _gender,
      photo: _photo,
      showRepresentative: _showRep,
      repName: _repName.text,
      repPhone: _repPhone.text,
      repPhoto: _repPhoto,
      sortOrder: int.tryParse(_sortOrder.text.trim()) ?? 0,
      termFrom: _termFrom,
      termTo: _termTo,
      selectionType: _selectionType,
    );
    setState(() => _saving = true);
    try {
      if (widget.editing != null) {
        await _repo.updateMember(widget.editing!.id, payload);
        if (mounted) {
          GovToast.ok(context,
              context.tr('Committee member updated', 'समिति सदस्य अद्यतन'));
        }
      } else {
        await _repo.insertMember(payload);
        if (mounted) {
          GovToast.ok(context,
              context.tr('Committee member added', 'समिति सदस्य जोड़ा गया'));
        }
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) GovToast.error(context, GovBackend.errorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _photoRow(String value, ValueChanged<String> onPicked) {
    final t = context.tokens;
    return Row(
      children: [
        MiniButton(
          label: context.tr('Upload photo', 'फ़ोटो अपलोड करें'),
          icon: Icons.photo_camera_outlined,
          onPressed: () async {
            final url = await pickPhotoDataUrl(context);
            if (url != null) onPicked(url);
          },
        ),
        if (value.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text('✓', style: TextStyle(fontSize: 12, color: t.success)),
          const SizedBox(width: 6),
          PersonAvatar(name: '', photo: value, size: AvatarSize.md),
          IconButton(
            onPressed: () => onPicked(''),
            icon: Icon(Icons.close, size: 16, color: t.mutedForeground),
            tooltip: context.tr('Remove photo', 'फ़ोटो हटाएँ'),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final nameDiffers = committeeIsRepresentative(
        name: _name.text, flatOwnerName: _flatOwnerName);
    final isPreset = committeePositionPresets.contains(_position);
    const gap = SizedBox(height: 14);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editing != null
            ? context.tr('Edit committee member', 'समिति सदस्य संपादित करें')
            : context.tr('Add committee member', 'समिति सदस्य जोड़ें')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          FieldLabel(context.tr('Flat no.', 'फ्लैट नं.'), required: true),
          AppTextField(
            controller: _flatSearch,
            hint: context.tr(
                'Search flat or owner name…', 'फ्लैट या स्वामी का नाम खोजें…'),
            prefixIcon: Icons.search,
            caps: false,
          ),
          const SizedBox(height: 8),
          AppDropdown<String>(
            items: ['', ..._filteredFlats.map((f) => f.id)],
            value: _flatId,
            hint: context.tr('Select flat…', 'फ्लैट चुनें…'),
            labelOf: (id) {
              if (id.isEmpty) return context.tr('Select flat…', 'फ्लैट चुनें…');
              final f = widget.flats.firstWhere((x) => x.id == id);
              return f.primaryMemberName.isNotEmpty
                  ? '${f.flatNumber} — ${f.primaryMemberName}'
                  : f.flatNumber;
            },
            onChanged: _applyFlat,
          ),
          if (_flatOwnerName.isNotEmpty) ...[
            const SizedBox(height: 10),
            TintBox(
              color: t.mutedForeground,
              fill: 0.06,
              child: Row(
                children: [
                  PersonAvatar(
                      name: _flatOwnerName, photo: _photo, size: AvatarSize.md),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            context.tr('FLAT OWNER (FROM MEMBERS)',
                                'फ्लैट स्वामी (सदस्यों से)'),
                            style: AppText.tiny(context)),
                        Text(_flatOwnerName,
                            style: AppText.bodyMedium(context)),
                        if (_flatNumber.isNotEmpty)
                          Text(
                              context.tr(
                                  'Flat $_flatNumber', 'फ्लैट $_flatNumber'),
                              style: AppText.tiny(context)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          gap,
          AppTextField(
            controller: _name,
            label: context.tr('Name for this post', 'इस पद के लिए नाम'),
            required: true,
            hint: context.tr(
                'Defaults to flat owner; change if a representative holds the post',
                'डिफ़ॉल्ट फ्लैट स्वामी; प्रतिनिधि पद पर हो तो बदलें'),
            caps: false,
          ),
          if (nameDiffers)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                context.tr(
                    'Representative name will be shown (owner: $_flatOwnerName)',
                    'प्रतिनिधि का नाम दिखेगा (स्वामी: $_flatOwnerName)'),
                style: TextStyle(fontSize: 11, color: t.primary),
              ),
            ),
          gap,
          AppDropdown<String>(
            label: context.tr('Position', 'पद'),
            required: true,
            items: committeePositionPresets,
            value: isPreset ? _position : null,
            hint: _position,
            labelOf: (p) => positionLabel(p, hi: _hi),
            onChanged: (v) => setState(() {
              if (v != null) {
                _position = v;
                _customPosition.clear();
              }
            }),
          ),
          const SizedBox(height: 8),
          AppTextField(
            controller: _customPosition,
            hint: context.tr('Or type custom position', 'या कस्टम पद लिखें'),
            caps: false,
            onChanged: (v) => setState(() {
              if (v.isNotEmpty) _position = v;
            }),
          ),
          gap,
          FieldLabel(context.tr('How selected', 'चयन कैसे हुआ'),
              required: true),
          Wrap(
            spacing: 4,
            children: [
              for (final opt in CommitteeSelectionType.values)
                ChoiceChip(
                  label: Text(opt.label(_hi),
                      style: const TextStyle(fontSize: 12)),
                  selected: _selectionType == opt.value,
                  onSelected: (_) => setState(() => _selectionType = opt.value),
                ),
            ],
          ),
          gap,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GovDateField(
                  label: context.tr('Tenure from', 'कार्यकाल से'),
                  required: true,
                  value: _termFrom,
                  onChanged: (v) => setState(() => _termFrom = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GovDateField(
                  label: context.tr('Tenure to', 'कार्यकाल तक'),
                  value: _termTo,
                  helper: context.tr('Leave blank until retirement',
                      'सेवानिवृत्ति तक खाली छोड़ें'),
                  onChanged: (v) => setState(() => _termTo = v),
                ),
              ),
            ],
          ),
          gap,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  controller: _phone,
                  label: context.tr('Mobile', 'मोबाइल'),
                  keyboardType: TextInputType.phone,
                  mono: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppDropdown<String>(
                  label: context.tr('Gender', 'लिंग'),
                  items: const ['', 'male', 'female', 'other'],
                  value: _gender,
                  labelOf: (g) => switch (g) {
                    'male' => context.tr('Male', 'पुरुष'),
                    'female' => context.tr('Female', 'महिला'),
                    'other' => context.tr('Other', 'अन्य'),
                    _ => '—',
                  },
                  onChanged: (v) => setState(() {
                    _gender = v ?? '';
                    if (_gender != 'female') _showRep = false;
                  }),
                ),
              ),
            ],
          ),
          gap,
          FieldLabel(context.tr('Photo', 'फ़ोटो')),
          _photoRow(_photo, (v) => setState(() => _photo = v)),
          gap,
          AppTextField(
            controller: _sortOrder,
            label: context.tr('Display order', 'प्रदर्शन क्रम'),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'-?\d*'))
            ],
          ),
          if (_gender == 'female') ...[
            gap,
            TintBox(
              color: t.secondaryForeground,
              fill: 0.05,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CheckRow(
                    value: _showRep,
                    onChanged: (v) => setState(() => _showRep = v),
                    label: context.tr(
                        'Add separate representative contact (photo & mobile) for residents',
                        'निवासियों के लिए अलग प्रतिनिधि संपर्क (फ़ोटो व मोबाइल) जोड़ें'),
                  ),
                  if (_showRep) ...[
                    const SizedBox(height: 10),
                    AppTextField(
                        controller: _repName,
                        label: context.tr(
                            'Representative name', 'प्रतिनिधि का नाम'),
                        caps: false),
                    const SizedBox(height: 10),
                    AppTextField(
                      controller: _repPhone,
                      label: context.tr(
                          'Representative mobile', 'प्रतिनिधि मोबाइल'),
                      keyboardType: TextInputType.phone,
                      mono: true,
                    ),
                    const SizedBox(height: 10),
                    FieldLabel(
                        context.tr('Representative photo', 'प्रतिनिधि फ़ोटो')),
                    _photoRow(_repPhoto, (v) => setState(() => _repPhoto = v)),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: AppButton.secondary(
                  label: context.tr('Cancel', 'रद्द करें'),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: AppButton(
                      label: context.tr('Save', 'सहेजें'),
                      loading: _saving,
                      onPressed: _save)),
            ],
          ),
        ],
      ),
    );
  }
}
