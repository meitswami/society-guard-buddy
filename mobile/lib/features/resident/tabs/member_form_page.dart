import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/ui/ui.dart';
import '../../../models/session_models.dart';
import '../data/member_rules.dart';
import '../data/resident_media.dart';
import '../data/resident_models.dart';
import '../data/resident_repository.dart';
import '../state/resident_controllers.dart';
import '../widgets/resident_widgets.dart';

String memberSaveErrorText(BuildContext context, MemberSaveError e) => switch (e) {
      MemberSaveError.onCommittee => context.tr(
          'This member is on the committee roster. Contact the admin to change their committee details.',
          'यह सदस्य समिति सूची में है। समिति विवरण बदलने के लिए व्यवस्थापक से संपर्क करें।'),
      MemberSaveError.nameRequired => context.tr('Name is required', 'नाम आवश्यक है'),
      MemberSaveError.serviceTypeRequired => context.tr('Please select a service type', 'कृपया सेवा का प्रकार चुनें'),
      MemberSaveError.relationRequired => context.tr('Please select a relation', 'कृपया संबंध चुनें'),
      MemberSaveError.primaryMustStayOwner => context.tr(
          'Primary member must stay an owner-household relation (not tenant/staff)',
          'प्राथमिक सदस्य मालिक-परिवार संबंध में ही रहना चाहिए (किरायेदार / कर्मचारी नहीं)'),
      MemberSaveError.tenantPhotoIdRequired =>
        context.tr('Tenant: at least 1 Photo ID is required', 'किरायेदार: कम से कम 1 फ़ोटो पहचान पत्र आवश्यक है'),
      MemberSaveError.tenantRentalRequired =>
        context.tr('Tenant: rental agreement is required', 'किरायेदार: किराया अनुबंध आवश्यक है'),
      MemberSaveError.restrictedPhotoIdRequired => context.tr(
          'Photo ID is required for restricted categories (tenant/other/service)',
          'प्रतिबंधित श्रेणियों (किरायेदार / अन्य / सेवा) के लिए फ़ोटो पहचान पत्र आवश्यक है'),
    };

/// Add / edit household member (web Family tab inline form), pushed as a full page.
/// Pops `true` after a successful save.
class ResidentMemberFormPage extends StatefulWidget {
  const ResidentMemberFormPage({
    super.key,
    required this.session,
    required this.household,
    this.editing,
    this.initialForm,
    this.initialDocs = const [],
  });

  final SessionResident session;
  final ResidentHousehold household;
  final HouseholdMember? editing;
  final MemberFormData? initialForm;
  final List<MemberDocDraft> initialDocs;

  @override
  State<ResidentMemberFormPage> createState() => _ResidentMemberFormPageState();
}

class _ResidentMemberFormPageState extends State<ResidentMemberFormPage> {
  final _repo = const ResidentRepository();
  late MemberFormData _form = widget.initialForm ?? const MemberFormData();
  late List<MemberDocDraft> _docs = List.of(widget.initialDocs);
  late final _name = TextEditingController(text: _form.name);
  late final _phone = TextEditingController(text: _form.phone);
  late final _age = TextEditingController(text: _form.age);
  late final _custom = TextEditingController(text: _form.customServiceType);
  late final _spouse = TextEditingController(text: _form.spouseName);
  late final _vName = TextEditingController(text: _form.vehicleName);
  late final _vNumber = TextEditingController(text: _form.vehicleNumber);
  late final _vColor = TextEditingController(text: _form.vehicleColor);
  bool _saving = false;

  bool get _isPrimary => widget.editing?.isPrimary ?? false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _age, _custom, _spouse, _vName, _vNumber, _vColor]) {
      c.dispose();
    }
    super.dispose();
  }

  MemberFormData _collect() => _form.copyWith(
        name: _name.text,
        phone: _phone.text.trim(),
        age: _age.text.trim(),
        customServiceType: _custom.text,
        spouseName: _spouse.text,
        vehicleName: _vName.text,
        vehicleNumber: _vNumber.text,
        vehicleColor: _vColor.text,
      );

  void _toast(String msg) => AppFeedback.toast(context, msg, tone: BadgeTone.alert);

  Future<void> _save() async {
    final form = _collect();
    final editing = widget.editing;
    final plan = planMemberSave(
      form: form,
      docs: _docs,
      flatId: widget.session.resident.flatId,
      editing: editing?.raw,
      editingOnCommittee: editing != null && widget.household.onCommittee(editing),
      myHouseholdGroup: widget.household.myMember?.householdGroup,
    );
    if (!plan.ok) {
      _toast(memberSaveErrorText(context, plan.error!));
      return;
    }
    setState(() => _saving = true);
    try {
      await _repo.saveMember(
        plan: plan,
        form: form,
        docs: _docs,
        editing: editing,
        flatId: widget.session.resident.flatId,
        flatNumber: widget.session.resident.flatNumber,
        societyId: widget.session.societyId,
      );
      if (!mounted) return;
      AppFeedback.toast(
        context,
        editing != null
            ? context.tr('Member updated', 'सदस्य अपडेट किया गया')
            : context.tr('Member added', 'सदस्य जोड़ा गया'),
        tone: BadgeTone.success,
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(editing == null ? context.tr('Could not add member: $e', 'सदस्य नहीं जुड़ सका: $e') : '$e');
    }
  }

  String _vehicleLabel(String v) => v.isEmpty ? v : '${v[0].toUpperCase()}${v.substring(1)}';

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final editing = widget.editing;
    final f = _form;
    final title = _isPrimary
        ? context.tr('Edit Primary Member', 'प्राथमिक सदस्य संपादित करें')
        : editing != null
            ? context.tr('Edit Member', 'सदस्य संपादित करें')
            : context.tr('Add Member', 'सदस्य जोड़ें');
    final contactOnly = f.isServiceman || f.relation == 'Tenant' || f.relation == 'Others';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: PageContainer(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (_isPrimary)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                context.tr('Update name, contact details, and profile photo. Primary status is kept on save.',
                    'नाम, संपर्क विवरण और प्रोफ़ाइल फ़ोटो अपडेट करें। सहेजने पर प्राथमिक स्थिति बनी रहती है।'),
                style: AppText.tiny(context),
              ),
            ),
          Row(children: [
            Expanded(
              child: PillChoice(
                label: context.tr('👨‍👩‍👧‍👦 Family', '👨‍👩‍👧‍👦 परिवार'),
                selected: !f.isServiceman,
                onTap: () => setState(() => _form = _form.copyWith(isServiceman: false)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PillChoice(
                label: context.tr('🧹 Serviceman', '🧹 सेवक / कर्मचारी'),
                selected: f.isServiceman,
                onTap: () {
                  if (_isPrimary) {
                    _toast(context.tr('Primary member cannot be changed to staff',
                        'प्राथमिक सदस्य को कर्मचारी में नहीं बदला जा सकता'));
                    return;
                  }
                  setState(() => _form = _form.copyWith(isServiceman: true));
                },
              ),
            ),
          ]),
          const SizedBox(height: 12),
          AppTextField(controller: _name, hint: context.tr('Full Name *', 'पूरा नाम *')),
          const SizedBox(height: 12),
          AppTextField(
            controller: _phone,
            hint: contactOnly
                ? context.tr('Phone (contact only — no app login)', 'फोन (केवल संपर्क — ऐप प्रवेश नहीं)')
                : context.tr('Phone (optional, for shared flat login)', 'फोन (वैकल्पिक, साझा फ्लैट प्रवेश के लिए)'),
            keyboardType: TextInputType.phone,
            maxLength: 10,
            mono: true,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 12),
          if (!f.isServiceman)
            AppDropdown<String>(
              label: context.tr('Relation', 'संबंध'),
              items: relationOptionsFor(editingPrimary: _isPrimary, currentRelation: f.relation),
              value: f.relation.isEmpty ? null : f.relation,
              hint: context.tr('---Select---', '---चुनें---'),
              labelOf: (r) => r,
              onChanged: (v) {
                if (v == null) return;
                if (_isPrimary && !allowsPrimaryMember(v)) {
                  _toast(context.tr(
                      'Primary member cannot use Tenant or Others', 'प्राथमिक सदस्य किरायेदार या अन्य नहीं हो सकता'));
                  return;
                }
                setState(() => _form = _form.copyWith(relation: v));
              },
            )
          else ...[
            AppDropdown<String>(
              label: context.tr('Service Type', 'सेवा का प्रकार'),
              items: kHouseholdServiceTypes,
              value: f.serviceType.isEmpty ? null : f.serviceType,
              hint: context.tr('---Select---', '---चुनें---'),
              labelOf: (s) => s,
              onChanged: (v) => setState(() => _form = _form.copyWith(serviceType: v ?? '')),
            ),
            if (f.serviceType == 'Others') ...[
              const SizedBox(height: 8),
              AppTextField(controller: _custom, hint: context.tr('Specify type...', 'प्रकार बताएँ...')),
            ],
          ],
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: AppTextField(
                controller: _age,
                label: context.tr('Age', 'आयु'),
                hint: context.tr('Age', 'आयु'),
                keyboardType: TextInputType.number,
                maxLength: 3,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppDropdown<String>(
                label: context.tr('Gender', 'लिंग'),
                items: const ['male', 'female', 'other'],
                value: f.gender.isEmpty ? null : f.gender,
                hint: context.tr('---Select---', '---चुनें---'),
                labelOf: (g) => switch (g) {
                  'male' => context.tr('Male', 'पुरुष'),
                  'female' => context.tr('Female', 'महिला'),
                  _ => context.tr('Other', 'अन्य'),
                },
                onChanged: (v) => setState(() => _form = _form.copyWith(gender: v ?? '')),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          _Box(
            tint: 0.10,
            children: [
              Text(
                context
                    .tr('Profile photo (shown beside nominees & elected members)',
                        'प्रोफ़ाइल फ़ोटो (नामांकितों व निर्वाचित सदस्यों के पास दिखती है)')
                    .toUpperCase(),
                style: AppText.tiny(context).copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr(
                    'Add a face photo for family, mid-servants, guards, cleaners, sweepers, and other household staff. Election ballots and the committee roster use this automatically.',
                    'परिवार, सेवकों, गार्ड, सफ़ाईकर्मियों और अन्य घरेलू कर्मचारियों का चेहरे वाला फ़ोटो जोड़ें। चुनाव मतपत्र और समिति सूची इसे अपने आप उपयोग करते हैं।'),
                style: AppText.tiny(context),
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                OutlineChipButton(
                  icon: Icons.photo_camera_outlined,
                  label: context.tr('Upload photo', 'फ़ोटो अपलोड करें'),
                  done: f.photo.isNotEmpty,
                  onTap: () async {
                    final data = await ResidentMedia.pickImageDataUrl(context);
                    if (data != null && mounted) setState(() => _form = _form.copyWith(photo: data));
                  },
                ),
                if (f.photo.isNotEmpty)
                  ResidentThumb(
                      src: f.photo,
                      size: 48,
                      circle: true,
                      onRemove: () => setState(() => _form = _form.copyWith(photo: ''))),
              ]),
            ],
          ),
          if (f.showsRestrictedSection) ...[
            const SizedBox(height: 12),
            _Box(
              tint: 0.20,
              children: [
                Text(
                  context.tr(
                      'Tenant, other, and staff are not given resident app login. Add ID and optional details below.',
                      'किरायेदार, अन्य और कर्मचारियों को निवासी ऐप प्रवेश नहीं मिलता। नीचे पहचान पत्र और वैकल्पिक विवरण जोड़ें।'),
                  style: AppText.tiny(context),
                ),
                const SizedBox(height: 8),
                DocDraftsEditor(
                  docs: _docs,
                  kind: MemberDocDraft.kindPhotoId,
                  title: context.tr('Photo ID uploads', 'फ़ोटो पहचान पत्र अपलोड'),
                  addLabel: context.tr('Add ID', 'पहचान पत्र जोड़ें'),
                  emptyText: context.tr('No Photo IDs added yet.', 'अभी कोई फ़ोटो पहचान पत्र नहीं जोड़ा गया।'),
                  onChanged: (d) => setState(() => _docs = d),
                ),
                if (f.isTenantRelation) ...[
                  const SizedBox(height: 4),
                  DocDraftsEditor(
                    docs: _docs,
                    kind: MemberDocDraft.kindTenantDoc,
                    singleSide: true,
                    title: context.tr('Tenant documents (mandatory)', 'किरायेदार दस्तावेज़ (अनिवार्य)'),
                    addLabel: context.tr('Add doc', 'दस्तावेज़ जोड़ें'),
                    onChanged: (d) => setState(() => _docs = d),
                  ),
                ],
                const SizedBox(height: 8),
                AppDropdown<String>(
                  label: context.tr('Police verification', 'पुलिस सत्यापन'),
                  items: kPoliceVerificationStates,
                  value: f.policeVerification.isEmpty ? null : f.policeVerification,
                  hint: context.tr('---Select---', '---चुनें---'),
                  labelOf: (v) => switch (v) {
                    'pending' => context.tr('Pending', 'लंबित'),
                    'submitted' => context.tr('Submitted', 'जमा किया'),
                    _ => context.tr('Verified', 'सत्यापित'),
                  },
                  onChanged: (v) => setState(() => _form = _form.copyWith(policeVerification: v ?? '')),
                ),
                const SizedBox(height: 8),
                AppTextField(
                    controller: _spouse,
                    hint: context.tr('Spouse / husband name (optional)', 'पति / पत्नी का नाम (वैकल्पिक)')),
                Divider(height: 24, color: t.border),
                Text(context.tr('Service dates (optional)', 'सेवा तिथियाँ (वैकल्पिक)').toUpperCase(),
                    style: AppText.tiny(context).copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  context.tr(
                      'When this person started / finished working for your flat (e.g. staff start date, last working day).',
                      'यह व्यक्ति आपके फ्लैट के लिए कब से / कब तक काम करता रहा (जैसे कर्मचारी की आरंभ तिथि, अंतिम कार्य दिवस)।'),
                  style: AppText.tiny(context),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: ResidentDateField(
                      label: context.tr('Date of joining', 'कार्यारंभ तिथि'),
                      value: f.dateJoining,
                      clearable: true,
                      onChanged: (v) => setState(() => _form = _form.copyWith(dateJoining: v)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ResidentDateField(
                      label: context.tr('Date of leave', 'छोड़ने की तिथि'),
                      value: f.dateLeave,
                      clearable: true,
                      onChanged: (v) => setState(() => _form = _form.copyWith(dateLeave: v)),
                    ),
                  ),
                ]),
                // Web shows the vehicle block for tenants too but only saves it for
                // restricted members; tenants register vehicles in the Vehicles tab.
                if (!f.isTenantRelation) ...[
                  Divider(height: 24, color: t.border),
                  Text(context.tr('Vehicle (optional)', 'वाहन (वैकल्पिक)').toUpperCase(),
                      style: AppText.tiny(context).copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: AppDropdown<String>(
                        items: kStaffVehicleTypes,
                        value: f.vehicleCategory.isEmpty ? null : f.vehicleCategory,
                        hint: context.tr('---Select---', '---चुनें---'),
                        labelOf: _vehicleLabel,
                        onChanged: (v) => setState(() => _form = _form.copyWith(vehicleCategory: v ?? '')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: AppTextField(controller: _vName, hint: context.tr('Vehicle name', 'वाहन का नाम'))),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                        child: AppTextField(
                            controller: _vNumber, hint: context.tr('Registration no.', 'पंजीकरण संख्या'), mono: true)),
                    const SizedBox(width: 8),
                    Expanded(child: AppTextField(controller: _vColor, hint: context.tr('Color', 'रंग'))),
                  ]),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      context.tr(
                          'Tenant vehicles: add them from the Vehicles tab.', 'किरायेदार के वाहन: वाहन टैब से जोड़ें।'),
                      style: AppText.tiny(context),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: AppButton(
                label: editing != null ? context.tr('Update', 'अपडेट करें') : context.tr('Add Member', 'सदस्य जोड़ें'),
                loading: _saving,
                onPressed: _save,
              ),
            ),
            const SizedBox(width: 8),
            AppButton.secondary(
                label: context.t('common.cancel'), expand: false, onPressed: () => Navigator.of(context).pop(false)),
          ]),
        ],
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.children, required this.tint});

  final List<Widget> children;
  final double tint;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTokens.tint(t.secondary, tint + 0.3),
        border: Border.all(color: AppTokens.tint(t.border, 0.6)),
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}
