import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/ui/ui.dart';
import '../../../models/session_models.dart';
import '../../shared/widgets/biometric_settings_tile.dart';
import '../data/member_rules.dart';
import '../data/resident_models.dart';
import '../data/resident_repository.dart';
import '../state/resident_controllers.dart';
import '../widgets/resident_i18n.dart';
import '../widgets/resident_widgets.dart';

/// Profile tab — web `tab === 'profile'`: Member 360°, profile card + flatmates, WhatsApp /
/// email channels, own photo ID (when the society enables it), password change for the
/// flat, biometric setup; plus logout.
class ResidentProfileTab extends StatefulWidget {
  const ResidentProfileTab({
    super.key,
    required this.session,
    required this.household,
    required this.onEditMember,
    required this.onOpenFlat360,
    required this.onLogout,
  });

  final SessionResident session;
  final ResidentHousehold household;
  final ValueChanged<HouseholdMember> onEditMember;
  final VoidCallback onOpenFlat360;
  final VoidCallback onLogout;

  @override
  State<ResidentProfileTab> createState() => _ResidentProfileTabState();
}

class _ResidentProfileTabState extends State<ResidentProfileTab> {
  final _repo = const ResidentRepository();
  final _whatsapp = TextEditingController();
  final _email = TextEditingController();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _showPass = false;
  bool _passLoading = false;
  bool _savingChannels = false;
  List<MemberDocDraft> _selfDocs = const [];
  String? _selfDocsFor;
  bool _savingSelfId = false;

  ResidentHousehold get _h => widget.household;

  @override
  void initState() {
    super.initState();
    _loadChannels();
    _h.addListener(_onHousehold);
    _onHousehold();
  }

  @override
  void dispose() {
    _h.removeListener(_onHousehold);
    for (final c in [_whatsapp, _email, _current, _new, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadChannels() async {
    try {
      final ch = await _repo.fetchContactChannels(widget.session.resident.id);
      if (!mounted) return;
      _whatsapp.text = ch.whatsapp ?? widget.session.resident.phone;
      _email.text = ch.email ?? '';
    } catch (_) {
      _whatsapp.text = widget.session.resident.phone;
    }
  }

  /// Web effect on `[residentSelfIdUploadEnabled, myMemberRecord?.id]`.
  Future<void> _onHousehold() async {
    final me = _h.myMember;
    if (!_h.selfIdUploadEnabled || me == null) {
      if (_selfDocsFor != null) {
        setState(() {
          _selfDocs = const [];
          _selfDocsFor = null;
        });
      }
      return;
    }
    if (_selfDocsFor == me.id) return;
    _selfDocsFor = me.id;
    try {
      final docs = await _repo.fetchMemberDocs(me.id, kind: MemberDocDraft.kindPhotoId, defaultType: 'aadhaar');
      if (!mounted) return;
      if (docs.isNotEmpty) {
        setState(() => _selfDocs = docs);
        return;
      }
      final front = (me.raw['id_photo_front'] ?? '').toString();
      final back = (me.raw['id_photo_back'] ?? '').toString();
      setState(() => _selfDocs = front.isNotEmpty || back.isNotEmpty
          ? [MemberDocDraft(kind: MemberDocDraft.kindPhotoId, type: 'other', front: front, back: back)]
          : const []);
    } catch (_) {}
  }

  void _err(String m) => AppFeedback.toast(context, m, tone: BadgeTone.alert);

  Future<void> _saveChannels() async {
    setState(() => _savingChannels = true);
    final wa = _whatsapp.text.trim();
    final email = _email.text.trim();
    try {
      await _repo.saveContactChannels(
        residentId: widget.session.resident.id,
        memberId: _h.myMember?.id,
        whatsapp: wa.isEmpty ? null : wa,
        email: email.isEmpty ? null : email,
      );
      if (mounted) {
        AppFeedback.toast(
            context,
            context.tr('WhatsApp and email saved for directory despatch',
                'निर्देशिका प्रेषण के लिए व्हाट्सऐप और ईमेल सहेजे गए'),
            tone: BadgeTone.success);
      }
    } catch (e) {
      if (mounted) _err('$e');
    }
    if (mounted) setState(() => _savingChannels = false);
  }

  Future<void> _saveSelfId() async {
    final me = _h.myMember;
    if (me == null) return;
    if (digitsOnly(me.phone ?? '') != digitsOnly(widget.session.resident.phone)) {
      _err(context.tr('Profile does not match your login', 'प्रोफ़ाइल आपके प्रवेश से मेल नहीं खाती'));
      return;
    }
    setState(() => _savingSelfId = true);
    try {
      await _repo.saveSelfIdDocs(me.id, _selfDocs);
      if (!mounted) return;
      AppFeedback.toast(context, context.tr('Photo ID saved', 'फ़ोटो पहचान पत्र सहेजा गया'), tone: BadgeTone.success);
      await _h.loadMembers();
    } catch (e) {
      if (mounted) _err('$e');
    }
    if (mounted) setState(() => _savingSelfId = false);
  }

  Future<void> _changePassword() async {
    final cur = _current.text, next = _new.text, conf = _confirm.text;
    if (cur.isEmpty || next.isEmpty || conf.isEmpty) return _err(context.tr('Fill all fields', 'सभी फ़ील्ड भरें'));
    if (next != conf) return _err(context.tr('Passwords do not match', 'कूटशब्द मेल नहीं खाते'));
    if (next.length < 4) {
      return _err(context.tr('Password must be at least 4 characters', 'कूटशब्द कम से कम 4 अक्षर का होना चाहिए'));
    }
    setState(() => _passLoading = true);
    try {
      final ok = await _repo.verifyPassword(residentId: widget.session.resident.id, password: cur);
      if (!ok) {
        if (mounted) _err(context.tr('Current password is wrong', 'वर्तमान कूटशब्द गलत है'));
      } else {
        await _repo.setFlatPassword(flatId: widget.session.resident.flatId, password: next);
        if (mounted) {
          AppFeedback.toast(
              context, context.tr('Password changed for all flatmates', 'सभी फ्लैट सदस्यों के लिए कूटशब्द बदला गया'),
              tone: BadgeTone.success);
          _current.clear();
          _new.clear();
          _confirm.clear();
        }
        await _h.loadFlatmates();
      }
    } catch (e) {
      if (mounted) _err('$e');
    }
    if (mounted) setState(() => _passLoading = false);
  }

  Widget _passField(TextEditingController c, String hint, {Widget? suffix}) => TextField(
        controller: c,
        obscureText: !_showPass,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(hintText: hint, suffixIcon: suffix),
      );

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final r = widget.session.resident;
    return ListenableBuilder(
      listenable: _h,
      builder: (context, _) {
        final me = _h.myMember;
        final onCommittee = me != null && _h.onCommittee(me);
        final others = _h.flatmates.where((f) => f.id != r.id).toList();
        final photo = residentImageProvider(me?.photo);
        return PageContainer(
          onRefresh: _h.loadAll,
          children: [
            PageHeader(
              title: context.t('resident.profile'),
              subtitle: '${context.t('common.flat')} ${r.flatNumber} · ${widget.session.societyName}',
              icon: Icons.person_outline,
            ),
            // Web: compact Flat360ProfilePanel for the resident's own flat.
            CardSection(
              margin: const EdgeInsets.only(bottom: 16),
              onTap: widget.onOpenFlat360,
              child: Row(children: [
                Icon(Icons.insights_outlined, size: 20, color: t.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(context.rt('resident.m.member360'), style: AppText.sectionTitle(context)),
                    Text(
                      context.tr('Payments, meetings, parking and activity of flat ${r.flatNumber}',
                          'फ्लैट ${r.flatNumber} के भुगतान, बैठकें, पार्किंग और गतिविधि'),
                      style: AppText.tiny(context),
                    ),
                  ]),
                ),
                Icon(Icons.chevron_right, color: t.mutedForeground),
              ]),
            ),
            CardSection(
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTokens.tint(t.primary, 0.1),
                    backgroundImage: photo,
                    child: photo == null ? Icon(Icons.person, color: t.primary) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(text: me?.name ?? r.name),
                          if (me?.isPrimary ?? false)
                            TextSpan(
                                text: '  ★ ${context.tr('Primary', 'प्राथमिक')}',
                                style: TextStyle(fontSize: 10, color: t.primary)),
                        ]),
                        style: AppText.sectionTitle(context),
                      ),
                      Text('${context.t('common.flat')} ${r.flatNumber} · 📱 ${r.phone}',
                          style: AppText.caption(context)),
                      if (onCommittee)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            context.tr('You are listed on the committee roster — name/post changes are admin-only.',
                                'आप समिति सूची में हैं — नाम / पद बदलाव केवल व्यवस्थापक कर सकते हैं।'),
                            style: TextStyle(fontSize: 10, color: t.primary),
                          ),
                        ),
                    ]),
                  ),
                ]),
                if (me != null && !onCommittee) ...[
                  const SizedBox(height: 12),
                  AppButton(
                    label: context.tr('Edit profile & photo', 'प्रोफ़ाइल व फ़ोटो संपादित करें'),
                    icon: Icons.edit_outlined,
                    dense: true,
                    onPressed: () => widget.onEditMember(me),
                  ),
                ],
                if (others.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(context.tr('Flatmates (shared login)', 'फ्लैट सदस्य (साझा प्रवेश)').toUpperCase(),
                      style: AppText.tiny(context).copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.8)),
                  const SizedBox(height: 6),
                  for (final f in others) Text('📱 ${f.phone} — ${f.name}', style: AppText.caption(context)),
                ],
              ]),
            ),
            CardSection(
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(context.tr('WhatsApp & email for notices', 'सूचनाओं के लिए व्हाट्सऐप व ईमेल'),
                    style: AppText.sectionTitle(context)),
                const SizedBox(height: 4),
                Text(
                  context.tr(
                      'Used for emergency alerts, meeting notices, bills, and receipts when admin enables those channels. Leave WhatsApp blank to use your login phone (${r.phone}).',
                      'व्यवस्थापक द्वारा चैनल चालू करने पर आपात अलर्ट, बैठक सूचना, बिल और रसीदों के लिए उपयोग होता है। लॉगिन फोन (${r.phone}) उपयोग करने के लिए व्हाट्सऐप खाली छोड़ें।'),
                  style: AppText.tiny(context),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _whatsapp,
                  hint: context.tr('10-digit WhatsApp number', '10 अंकों का व्हाट्सऐप नंबर'),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  mono: true,
                ),
                const SizedBox(height: 8),
                AppTextField(
                    controller: _email,
                    hint: context.tr('Email ID', 'ईमेल आईडी'),
                    keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                AppButton(
                  label: _savingChannels
                      ? context.tr('Saving…', 'सहेज रहे हैं…')
                      : context.tr('Save contact channels', 'संपर्क चैनल सहेजें'),
                  loading: _savingChannels,
                  dense: true,
                  onPressed: _saveChannels,
                ),
              ]),
            ),
            if (_h.selfIdUploadEnabled)
              CardSection(
                margin: const EdgeInsets.only(bottom: 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(context.tr('Your Photo ID', 'आपका फ़ोटो पहचान पत्र'), style: AppText.sectionTitle(context)),
                  const SizedBox(height: 4),
                  Text(
                    context.tr(
                        'Upload or update the ID images for your own member record only (linked to your login phone). Other flats never see this here.',
                        'केवल अपने सदस्य रिकॉर्ड (आपके लॉगिन फोन से जुड़ा) के पहचान पत्र चित्र अपलोड या अपडेट करें। अन्य फ्लैट इसे यहाँ नहीं देखते।'),
                    style: AppText.tiny(context),
                  ),
                  const SizedBox(height: 12),
                  if (me == null)
                    Text(
                      context.tr(
                          'No household member row matches your login phone. Ask the society admin to set your phone on your member profile so you can upload ID.',
                          'आपके लॉगिन फोन से कोई सदस्य रिकॉर्ड मेल नहीं खाता। पहचान पत्र अपलोड करने के लिए सोसाइटी व्यवस्थापक से अपने सदस्य प्रोफ़ाइल पर फोन जोड़ने को कहें।'),
                      style: TextStyle(fontSize: 12, color: t.warning),
                    )
                  else ...[
                    DocDraftsEditor(
                      docs: _selfDocs,
                      kind: MemberDocDraft.kindPhotoId,
                      title: context.tr('Photo ID uploads', 'फ़ोटो पहचान पत्र अपलोड'),
                      addLabel: context.tr('Add ID', 'पहचान पत्र जोड़ें'),
                      emptyText: context.tr('No Photo IDs added yet.', 'अभी कोई फ़ोटो पहचान पत्र नहीं जोड़ा गया।'),
                      onChanged: (d) => setState(() => _selfDocs = d),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AppButton(
                        label: _savingSelfId
                            ? context.tr('Saving…', 'सहेज रहे हैं…')
                            : context.tr('Save Photo ID', 'फ़ोटो पहचान पत्र सहेजें'),
                        loading: _savingSelfId,
                        dense: true,
                        expand: false,
                        onPressed: _saveSelfId,
                      ),
                    ),
                  ],
                ]),
              ),
            CardSection(
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SectionTitle(context.tr('Change Password', 'कूटशब्द बदलें'), icon: Icons.lock_outline),
                Text(
                  context.tr('⚠️ Changing password will update it for all flatmates',
                      '⚠️ कूटशब्द बदलने से सभी फ्लैट सदस्यों के लिए बदल जाएगा'),
                  style: AppText.tiny(context),
                ),
                const SizedBox(height: 12),
                _passField(
                  _current,
                  context.tr('Current Password', 'वर्तमान कूटशब्द'),
                  suffix: IconButton(
                    icon: Icon(_showPass ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                    onPressed: () => setState(() => _showPass = !_showPass),
                  ),
                ),
                const SizedBox(height: 10),
                _passField(_new, context.tr('New Password', 'नया कूटशब्द')),
                const SizedBox(height: 10),
                _passField(_confirm, context.tr('Confirm New Password', 'नए कूटशब्द की पुष्टि करें')),
                const SizedBox(height: 12),
                AppButton(
                  label: _passLoading
                      ? context.tr('Changing...', 'बदल रहे हैं...')
                      : context.tr('Change Password', 'कूटशब्द बदलें'),
                  loading: _passLoading,
                  onPressed: _changePassword,
                ),
              ]),
            ),
            CardSection(
              margin: const EdgeInsets.only(bottom: 16),
              padding: EdgeInsets.zero,
              child: BiometricSettingsTile(session: widget.session),
            ),
            AppButton.destructive(
                label: context.t('swal.confirmLogoutUser'), icon: Icons.logout, onPressed: widget.onLogout),
          ],
        );
      },
    );
  }
}
