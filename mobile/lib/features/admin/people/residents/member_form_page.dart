import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/ui/ui.dart';
import '../../../../utils/member_categories.dart';
import '../../../shared/directory/directory_widgets.dart';
import '../data/people_models.dart';
import '../data/residents_service.dart';
import '../logic/residents_logic.dart';
import '../widgets/image_capture.dart';
import '../widgets/sensitive_verify.dart';

/// Add / edit household member — the inline member form of web `AdminResidentManager.tsx`
/// as a full page. Pops `true` after a successful save.
class MemberFormPage extends StatefulWidget {
  const MemberFormPage({
    super.key,
    required this.societyId,
    required this.adminId,
    required this.adminName,
    required this.flat,
    required this.flatMembers,
    this.editing,
  });

  final String societyId;
  final String adminId;
  final String adminName;
  final PeopleFlat flat;
  final List<PeopleMember> flatMembers;
  final PeopleMember? editing;

  @override
  State<MemberFormPage> createState() => _MemberFormPageState();
}

class _MemberFormPageState extends State<MemberFormPage> {
  final _service = ResidentsService();
  late MemberFormState _f;
  List<MemberDocDraft> _docs = [];
  bool _loadingExtras = false;
  bool _saving = false;

  late final TextEditingController _name, _phone, _wa, _email, _age, _spouse, _vName, _vNumber, _vColor;

  bool get _isEdit => widget.editing != null;

  @override
  void initState() {
    super.initState();
    _f = widget.editing == null ? MemberFormState() : memberFormFrom(widget.editing!);
    _name = TextEditingController(text: _f.name);
    _phone = TextEditingController(text: _f.phone);
    _wa = TextEditingController(text: _f.whatsappPhone);
    _email = TextEditingController(text: _f.email);
    _age = TextEditingController(text: _f.age);
    _spouse = TextEditingController(text: _f.spouseName);
    _vName = TextEditingController();
    _vNumber = TextEditingController();
    _vColor = TextEditingController();
    if (_isEdit) _loadExtras();
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _wa, _email, _age, _spouse, _vName, _vNumber, _vColor]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadExtras() async {
    setState(() => _loadingExtras = true);
    try {
      final data = await _service.loadMemberEditData(widget.editing!.id);
      if (!mounted) return;
      setState(() {
        _docs = data.docs;
        final v = data.vehicle;
        if (v != null) {
          _f.vehicleCategory = v['vehicle_type']?.toString() ?? '';
          _vName.text = _f.vehicleName = v['vehicle_display_name']?.toString() ?? '';
          final num = v['vehicle_number']?.toString() ?? '';
          _vNumber.text = _f.vehicleNumber = num == 'N/A' ? '' : num;
          _vColor.text = _f.vehicleColor = v['vehicle_color']?.toString() ?? '';
        }
      });
    } catch (_) {
      // Documents are optional context; the form still works.
    } finally {
      if (mounted) setState(() => _loadingExtras = false);
    }
  }

  void _sync() {
    _f
      ..name = _name.text
      ..phone = _phone.text
      ..whatsappPhone = _wa.text
      ..email = _email.text
      ..age = _age.text
      ..spouseName = _spouse.text
      ..vehicleName = _vName.text
      ..vehicleNumber = _vNumber.text
      ..vehicleColor = _vColor.text;
  }

  PeopleMember? get _primary => widget.flatMembers.where((m) => m.isPrimary).firstOrNull;

  Future<void> _save() async {
    _sync();
    final issue = validateMemberForm(form: _f, docs: _docs, editing: widget.editing);
    if (issue != null) {
      AppFeedback.toast(context, context.tr(issue.en, issue.hi), tone: BadgeTone.alert);
      return;
    }
    final ok = await SensitiveVerify.confirm(
      context,
      societyId: widget.societyId,
      adminId: widget.adminId,
      adminName: widget.adminName,
      title: _isEdit ? context.tr('Update household member', 'परिवार सदस्य अद्यतन करें') : context.tr('Add household member', 'परिवार सदस्य जोड़ें'),
      actionLabel: _isEdit ? 'update_member' : 'add_member',
    );
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    try {
      final res = await _service.saveMember(
        societyId: widget.societyId,
        flat: widget.flat,
        flatMembers: widget.flatMembers,
        editing: widget.editing,
        form: _f,
        docs: _docs,
      );
      if (!mounted) return;
      if (res.updated) {
        await AppFeedback.success(context,
            title: context.tr('Updated!', 'अद्यतन!'), message: context.tr('Member updated successfully', 'सदस्य सफलतापूर्वक अद्यतन'));
      } else {
        AppFeedback.toast(context, context.tr('Member added', 'सदस्य जोड़ा गया'), tone: BadgeTone.success);
      }
      if (res.loginsCreated > 0 && mounted) {
        AppFeedback.toast(
          context,
          context.tr('${res.loginsCreated} resident login(s) created', '${res.loginsCreated} निवासी लॉगिन बनाए गए'),
          tone: BadgeTone.success,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppFeedback.toast(context, e is MemberSaveException ? e.message : context.tr('Could not save member: $e', 'सदस्य सहेजा नहीं जा सका: $e'),
          tone: BadgeTone.alert);
    }
  }

  Future<void> _pickPhoto() async {
    final p = await PeopleImagePicker.pick(context, title: context.tr('Profile photo', 'प्रोफ़ाइल फ़ोटो'));
    if (p != null && mounted) setState(() => _f.photo = p.dataUrl);
  }

  Future<void> _pickDoc(MemberDocDraft d, bool front) async {
    final p = await PeopleImagePicker.pick(context, maxSide: 1200, quality: 75);
    if (p == null || !mounted) return;
    setState(() => front ? d.front = p.dataUrl : d.back = p.dataUrl);
  }

  Future<void> _pickDate(bool joining) async {
    final cur = DateTime.tryParse(joining ? _f.dateJoining : _f.dateLeave);
    final picked = await showDatePicker(
      context: context,
      initialDate: cur ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() => joining ? _f.dateJoining = Fmt.isoDate(picked) : _f.dateLeave = Fmt.isoDate(picked));
  }

  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final relation = _f.relation;
    final restrictedForm = memberNeedsDocs(relation);
    final isTenant = isTenantRelation(relation);
    final primary = _primary;
    final showCheckbox = showPrimaryCheckbox(
      relation: relation,
      primaryExists: primary != null,
      flatMemberCount: widget.flatMembers.length,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? context.tr('Edit Member', 'सदस्य संपादित करें') : context.tr('Add Member', 'सदस्य जोड़ें')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Text(
              '${context.t('common.flat')} ${widget.flat.flatNumber}${widget.flat.wing != null ? ' · ${context.tr('Wing', 'विंग')} ${widget.flat.wing}' : ''}',
              style: AppText.caption(context),
            ),
            if (_loadingExtras) const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 12),
            AppTextField(label: context.tr('Name', 'नाम'), required: true, controller: _name),
            const SizedBox(height: 12),
            AppTextField(
              label: restrictedForm
                  ? context.tr('Phone (contact only, no login)', 'फ़ोन (केवल संपर्क, लॉगिन नहीं)')
                  : context.tr('Phone (for login)', 'फ़ोन (लॉगिन हेतु)'),
              controller: _phone,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              mono: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: context.tr('WhatsApp (shared)', 'व्हाट्सऐप (साझा)'),
              controller: _wa,
              keyboardType: TextInputType.phone,
              maxLength: 15,
              mono: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 12),
            AppTextField(label: context.tr('Email ID', 'ईमेल आईडी'), controller: _email, keyboardType: TextInputType.emailAddress, caps: false),
            const SizedBox(height: 4),
            _Check(
              label: context.tr('Notify via WhatsApp', 'व्हाट्सऐप से सूचित करें'),
              value: _f.notifyWhatsapp,
              onChanged: (v) => setState(() => _f.notifyWhatsapp = v),
            ),
            _Check(
              label: context.tr('Notify via email', 'ईमेल से सूचित करें'),
              value: _f.notifyEmail,
              onChanged: (v) => setState(() => _f.notifyEmail = v),
            ),
            const SizedBox(height: 8),
            FieldLabel(context.tr('Relation / role', 'संबंध / भूमिका'), required: true),
            _RelationDropdown(
              value: relation,
              onChanged: (v) => setState(() {
                _f.relation = v;
                _f.isPrimary = false;
              }),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: AppTextField(
                  label: context.tr('Age', 'आयु'),
                  controller: _age,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppDropdown<String>(
                  label: context.tr('Gender', 'लिंग'),
                  hint: '---${context.tr('Select', 'चुनें')}---',
                  items: const ['Male', 'Female', 'Other'],
                  value: _f.gender.isEmpty ? null : _f.gender,
                  labelOf: (g) => switch (g) {
                    'Male' => context.tr('Male', 'पुरुष'),
                    'Female' => context.tr('Female', 'महिला'),
                    _ => context.tr('Other', 'अन्य'),
                  },
                  onChanged: (v) => setState(() => _f.gender = v ?? ''),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            TinyLabel(context.tr('Profile photo (optional — used in elections & committee)', 'प्रोफ़ाइल फ़ोटो (वैकल्पिक — चुनाव और समिति में उपयोग)')),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              AppButton.secondary(
                label: context.tr('Upload photo', 'फ़ोटो अपलोड करें'),
                icon: Icons.photo_camera_outlined,
                dense: true,
                expand: false,
                onPressed: _pickPhoto,
              ),
              if (_f.photo.isNotEmpty) ...[
                Icon(Icons.check, size: 14, color: t.success),
                ImageThumb(src: _f.photo, width: 40, height: 40, radius: 20),
                TextButton(
                  onPressed: () => setState(() => _f.photo = ''),
                  child: Text(context.tr('Remove', 'हटाएँ'), style: TextStyle(fontSize: 12, color: t.destructive)),
                ),
              ],
            ]),
            if (restrictedForm) ...[
              const SizedBox(height: 16),
              _DocSection(
                title: context.tr('Photo ID uploads', 'फ़ोटो आईडी अपलोड'),
                addLabel: context.tr('Add ID', 'आईडी जोड़ें'),
                emptyText: context.tr('No Photo IDs added yet.', 'अभी कोई फ़ोटो आईडी नहीं जोड़ी गई।'),
                kind: MemberDocKind.photoId,
                docs: _docs,
                twoSided: true,
                onAdd: () => setState(() => _docs.add(MemberDocDraft(kind: MemberDocKind.photoId, type: defaultDocType(MemberDocKind.photoId)))),
                onRemove: (d) => setState(() => _docs.remove(d)),
                onType: (d, v) => setState(() => d.type = v),
                onPick: _pickDoc,
              ),
              if (_f.idPhotoFront.isNotEmpty || _f.idPhotoBack.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(children: [
                  Text(context.tr('Earlier ID on file: ', 'पहले से दर्ज आईडी: '), style: AppText.tiny(context)),
                  if (_f.idPhotoFront.isNotEmpty) ImageThumb(src: _f.idPhotoFront, width: 48, height: 32),
                  const SizedBox(width: 4),
                  if (_f.idPhotoBack.isNotEmpty) ImageThumb(src: _f.idPhotoBack, width: 48, height: 32),
                ]),
              ],
              const SizedBox(height: 16),
              if (isTenant)
                _DocSection(
                  title: context.tr('Tenant documents (mandatory)', 'किरायेदार दस्तावेज़ (अनिवार्य)'),
                  addLabel: context.tr('Add doc', 'दस्तावेज़ जोड़ें'),
                  emptyText: context.tr('Add at least the rental agreement.', 'कम से कम किराया अनुबंध जोड़ें।'),
                  kind: MemberDocKind.tenantDoc,
                  docs: _docs,
                  onAdd: () => setState(() => _docs.add(MemberDocDraft(kind: MemberDocKind.tenantDoc, type: defaultDocType(MemberDocKind.tenantDoc)))),
                  onRemove: (d) => setState(() => _docs.remove(d)),
                  onType: (d, v) => setState(() => d.type = v),
                  onPick: _pickDoc,
                )
              else
                _DocSection(
                  title: context.tr('Service documents (optional)', 'सेवा दस्तावेज़ (वैकल्पिक)'),
                  addLabel: context.tr('Add doc', 'दस्तावेज़ जोड़ें'),
                  kind: MemberDocKind.serviceDoc,
                  docs: _docs,
                  onAdd: () => setState(() => _docs.add(MemberDocDraft(kind: MemberDocKind.serviceDoc, type: defaultDocType(MemberDocKind.serviceDoc)))),
                  onRemove: (d) => setState(() => _docs.remove(d)),
                  onType: (d, v) => setState(() => d.type = v),
                  onPick: _pickDoc,
                ),
              const SizedBox(height: 16),
              AppDropdown<String>(
                label: context.tr('Police verification', 'पुलिस सत्यापन'),
                hint: '---${context.tr('Select', 'चुनें')}---',
                items: const ['pending', 'submitted', 'verified'],
                value: _f.policeVerification.isEmpty ? null : _f.policeVerification,
                labelOf: (v) => switch (v) {
                  'pending' => context.tr('Pending', 'लंबित'),
                  'submitted' => context.tr('Submitted', 'जमा किया'),
                  _ => context.tr('Verified', 'सत्यापित'),
                },
                onChanged: (v) => setState(() => _f.policeVerification = v ?? ''),
              ),
              const SizedBox(height: 12),
              AppTextField(label: context.tr('Spouse / husband name (optional)', 'पति/पत्नी का नाम (वैकल्पिक)'), controller: _spouse),
              const Divider(height: 32),
              TinyLabel(context.tr('Service dates (optional)', 'सेवा तिथियाँ (वैकल्पिक)')),
              const SizedBox(height: 4),
              Text(
                context.tr(
                  'When this person started / finished working for the flat (for staff, maid, driver, etc.).',
                  'यह व्यक्ति फ्लैट के लिए कब से / कब तक काम करता रहा (स्टाफ़, मेड, ड्राइवर आदि)।',
                ),
                style: AppText.tiny(context),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: _DateBox(
                    label: context.tr('Date of joining', 'जुड़ने की तिथि'),
                    iso: _f.dateJoining,
                    onTap: () => _pickDate(true),
                    onClear: () => setState(() => _f.dateJoining = ''),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateBox(
                    label: context.tr('Date of leave', 'छोड़ने की तिथि'),
                    iso: _f.dateLeave,
                    onTap: () => _pickDate(false),
                    onClear: () => setState(() => _f.dateLeave = ''),
                  ),
                ),
              ]),
              const Divider(height: 32),
              TinyLabel(context.tr('Vehicle (optional)', 'वाहन (वैकल्पिक)')),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: AppDropdown<String>(
                    hint: '---${context.tr('Select', 'चुनें')}---',
                    items: kStaffVehicleTypes,
                    value: _f.vehicleCategory.isEmpty ? null : _f.vehicleCategory,
                    labelOf: (v) => v,
                    onChanged: (v) => setState(() => _f.vehicleCategory = v ?? ''),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: AppTextField(hint: context.tr('Vehicle name / model', 'वाहन नाम / मॉडल'), controller: _vName)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: AppTextField(hint: context.tr('Registration no.', 'पंजीकरण सं.'), controller: _vNumber, mono: true)),
                const SizedBox(width: 12),
                Expanded(child: AppTextField(hint: context.tr('Color', 'रंग'), controller: _vColor)),
              ]),
            ],
            if (showCheckbox)
              _Check(
                label: context.tr('Set as primary member', 'प्राथमिक सदस्य बनाएँ'),
                value: _f.isPrimary,
                onChanged: (v) => setState(() => _f.isPrimary = v),
              ),
            if (primary != null && !showCheckbox && allowsPrimaryMember(relation))
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  context.tr(
                    'Primary is already set. Use ★ on a household member in the list to change it.',
                    'प्राथमिक सदस्य पहले से तय है। बदलने के लिए सूची में परिवार सदस्य पर ★ दबाएँ।',
                  ),
                  style: AppText.tiny(context),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              restrictedForm
                  ? context.tr(
                      '💡 Tenant, other, and staff do not get resident app login. Phone is for contact only.',
                      '💡 किरायेदार, अन्य और स्टाफ़ को निवासी ऐप लॉगिन नहीं मिलता। फ़ोन केवल संपर्क हेतु है।',
                    )
                  : context.tr(
                      '💡 Household members with a phone number get a shared flat login password.',
                      '💡 फ़ोन नंबर वाले परिवार सदस्यों को साझा फ्लैट लॉगिन पासवर्ड मिलता है।',
                    ),
              style: AppText.tiny(context),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: AppButton(
                  label: _isEdit ? context.tr('Update', 'अद्यतन करें') : context.t('common.add'),
                  loading: _saving,
                  onPressed: _save,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: AppButton.secondary(label: context.t('common.cancel'), onPressed: () => Navigator.pop(context))),
            ]),
          ],
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Row(children: [
        Checkbox(value: value, onChanged: (v) => onChanged(v ?? false), visualDensity: VisualDensity.compact),
        Expanded(child: Text(label, style: AppText.caption(context))),
      ]),
    );
  }
}

class _DateBox extends StatelessWidget {
  const _DateBox({required this.label, required this.iso, required this.onTap, required this.onClear});

  final String label;
  final String iso;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: t.mutedForeground)),
        const SizedBox(height: 2),
        InkWell(
          onTap: onTap,
          child: InputDecorator(
            decoration: InputDecoration(
              isDense: true,
              suffixIcon: iso.isEmpty
                  ? Icon(Icons.calendar_today_outlined, size: 16, color: t.mutedForeground)
                  : IconButton(icon: const Icon(Icons.close, size: 16), onPressed: onClear),
            ),
            child: Text(iso.isEmpty ? 'dd/mm/yyyy' : Fmt.isoToDisplay(iso),
                style: TextStyle(fontSize: 13, color: iso.isEmpty ? t.mutedForeground : t.foreground)),
          ),
        ),
      ],
    );
  }
}

class _RelationDropdown extends StatelessWidget {
  const _RelationDropdown({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  static String label(BuildContext context, String r) {
    const hi = {
      'owner': 'मालिक',
      'spouse': 'पति/पत्नी',
      'son': 'पुत्र',
      'daughter': 'पुत्री',
      'father': 'पिता',
      'mother': 'माता',
      'family': 'परिवार',
      'tenant': 'किरायेदार',
      'other': 'अन्य',
      'cook': 'रसोइया',
      'maid': 'मेड',
      'washerman': 'धोबी',
      'newspaper': 'अख़बार वाला',
      'driver': 'ड्राइवर',
      'guard': 'गार्ड',
      'cleaner': 'सफ़ाईकर्मी',
      'sweeper': 'झाड़ूवाला',
      'housekeeper': 'हाउसकीपर',
      'mid-servant': 'सहायक',
    };
    final en = capitalizeWords(r);
    return context.tr(en == 'Mid-Servant' ? 'Mid-servant' : en, hi[r] ?? en);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final known = {...kAdminHouseholdRelations, ...kAdminStaffRelations};
    final custom = value.isNotEmpty && !known.contains(value) ? value : null;
    DropdownMenuItem<String> header(String text) => DropdownMenuItem<String>(
          enabled: false,
          value: '__$text',
          child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: t.mutedForeground)),
        );
    DropdownMenuItem<String> item(String r) => DropdownMenuItem<String>(
          value: r,
          child: Padding(padding: const EdgeInsets.only(left: 8), child: Text(label(context, r))),
        );
    return DropdownButtonFormField<String>(
      key: ValueKey(value),
      initialValue: value.isEmpty ? null : value,
      isExpanded: true,
      dropdownColor: t.card,
      style: TextStyle(fontSize: 14, color: t.foreground),
      hint: Text('---${context.tr('Select', 'चुनें')}---'),
      items: [
        if (custom != null) item(custom),
        header(context.tr('Household', 'परिवार')),
        for (final r in kAdminHouseholdRelations) item(r),
        header(context.tr('Staff / service (Quick Entry)', 'स्टाफ़ / सेवा (क्विक एंट्री)')),
        for (final r in kAdminStaffRelations) item(r),
      ],
      onChanged: (v) {
        if (v != null && !v.startsWith('__')) onChanged(v);
      },
    );
  }
}

class _DocSection extends StatelessWidget {
  const _DocSection({
    required this.title,
    required this.addLabel,
    this.emptyText,
    required this.kind,
    required this.docs,
    this.twoSided = false,
    required this.onAdd,
    required this.onRemove,
    required this.onType,
    required this.onPick,
  });

  final String title;
  final String addLabel;
  final String? emptyText;
  final MemberDocKind kind;
  final List<MemberDocDraft> docs;
  final bool twoSided;
  final VoidCallback onAdd;
  final ValueChanged<MemberDocDraft> onRemove;
  final void Function(MemberDocDraft, String) onType;
  final Future<void> Function(MemberDocDraft, bool front) onPick;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final mine = docs.where((d) => d.kind == kind).toList();
    final options = docTypesFor(kind);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(child: TinyLabel(title)),
          TextButton.icon(
            onPressed: onAdd,
            icon: Icon(Icons.add, size: 14, color: t.primary),
            label: Text(addLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: t.primary)),
          ),
        ]),
        if (mine.isEmpty && emptyText != null) Text(emptyText!, style: AppText.tiny(context)),
        for (final d in mine)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTokens.tint(t.background, 0.5),
              border: Border.all(color: t.border),
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(
                    child: AppDropdown<String>(
                      items: [
                        ...options.map((o) => o.value),
                        if (!options.any((o) => o.value == d.type)) d.type,
                      ],
                      value: d.type,
                      labelOf: (v) {
                        final o = options.where((x) => x.value == v).firstOrNull;
                        return o == null ? v : context.tr(o.en, o.hi);
                      },
                      onChanged: (v) {
                        if (v != null) onType(d, v);
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: context.tr('Remove', 'हटाएँ'),
                    icon: Icon(Icons.close, size: 18, color: t.mutedForeground),
                    onPressed: () => onRemove(d),
                  ),
                ]),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  AppButton.secondary(
                    label: twoSided ? context.tr('Front', 'आगे') : context.tr('Upload', 'अपलोड'),
                    icon: Icons.photo_camera_outlined,
                    dense: true,
                    expand: false,
                    onPressed: () => onPick(d, true),
                  ),
                  if (d.front.isNotEmpty) Icon(Icons.check, size: 14, color: t.success),
                  if (twoSided) ...[
                    AppButton.secondary(
                      label: context.tr('Back', 'पीछे'),
                      icon: Icons.photo_camera_outlined,
                      dense: true,
                      expand: false,
                      onPressed: () => onPick(d, false),
                    ),
                    if (d.back.isNotEmpty) Icon(Icons.check, size: 14, color: t.success),
                  ],
                  if (d.front.isNotEmpty) ImageThumb(src: d.front, width: 48, height: 32),
                  if (twoSided && d.back.isNotEmpty) ImageThumb(src: d.back, width: 48, height: 32),
                ]),
              ],
            ),
          ),
      ],
    );
  }
}
