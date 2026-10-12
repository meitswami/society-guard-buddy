import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/export/export_kit.dart';
import '../../../core/ui/ui.dart';
import '../../shared/directory/directory_widgets.dart';
import '../core/admin_module.dart';
import 'data/guards_service.dart';
import 'data/people_audit.dart';
import 'data/people_models.dart';
import 'widgets/image_capture.dart';

/// Admin → Guards — port of web `src/components/AdminGuardManager.tsx`: guard CRUD
/// (password / OTP login), KYC (police verification + alert days, pending banner),
/// worker photo, Photo ID front/back per document type, multiple attachments
/// (images / PDFs) in the `guard-documents` bucket, password show / reset.
class AdminGuardsModule extends StatefulWidget {
  const AdminGuardsModule({super.key, required this.ctx});

  final AdminModuleContext ctx;

  @override
  State<AdminGuardsModule> createState() => _AdminGuardsModuleState();
}

const _idDocLabels = [
  'Aadhaar Card',
  'PAN Card',
  'Driving License',
  'Voter ID',
  'Passport',
  'Other'
];

class _AdminGuardsModuleState extends State<AdminGuardsModule> {
  final _service = GuardsService();
  GuardsSnapshot _snap = GuardsSnapshot.empty;
  bool _loading = true;
  Object? _error;

  // Add form.
  bool _showForm = false;
  final _gId = TextEditingController();
  final _gName = TextEditingController();
  final _gPassword = TextEditingController();
  final _gPhone = TextEditingController();
  final _gKyc = TextEditingController(text: '7');
  String _authMode = 'password';
  String _police = 'pending';
  bool _adding = false;

  final Set<String> _showPasswords = {};
  String? _resetId;
  final _newPassword = TextEditingController();
  String? _expandedId;
  String? _editingId;
  final _eId = TextEditingController();
  final _eName = TextEditingController();
  final _ePhone = TextEditingController();
  final _eKyc = TextEditingController();
  String _eAuth = 'password';
  String _ePolice = 'pending';

  String _docLabel = _idDocLabels.first;
  final _attachLabel = TextEditingController(text: 'Document');
  bool _uploadingDoc = false;
  String? _uploadingProfile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _gId,
      _gName,
      _gPassword,
      _gPhone,
      _gKyc,
      _newPassword,
      _eId,
      _eName,
      _ePhone,
      _eKyc,
      _attachLabel
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _snap.guards.isEmpty;
      _error = null;
    });
    try {
      final s = await _service.load(widget.ctx.societyId);
      if (!mounted) return;
      setState(() {
        _snap = s;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  /// `parseInt(v) || 7`.
  int _days(String v) {
    final n = int.tryParse(v) ?? 0;
    return n == 0 ? 7 : n;
  }

  void _toast(String msg, {BadgeTone tone = BadgeTone.success}) {
    if (mounted) AppFeedback.toast(context, msg, tone: tone);
  }

  Future<void> _addGuard() async {
    final id = _gId.text.trim();
    final name = _gName.text.trim();
    if (id.isEmpty || name.isEmpty) {
      _toast(context.t('admin.fillAllFields'), tone: BadgeTone.alert);
      return;
    }
    if (_authMode == 'password' && _gPassword.text.isEmpty) {
      _toast(
          context.tr('Password required for password login',
              'पासवर्ड लॉगिन हेतु पासवर्ड आवश्यक है'),
          tone: BadgeTone.alert);
      return;
    }
    if (_authMode == 'otp' && _gPhone.text.isEmpty) {
      _toast(
          context.tr(
              'Phone required for OTP login', 'OTP लॉगिन हेतु फ़ोन आवश्यक है'),
          tone: BadgeTone.alert);
      return;
    }
    setState(() => _adding = true);
    try {
      await _service.addGuard(
        societyId: widget.ctx.societyId,
        guardId: id,
        name: name,
        password: _gPassword.text,
        authMode: _authMode,
        policeVerification: _police,
        kycAlertDays: _days(_gKyc.text),
        phone: _gPhone.text,
      );
      for (final c in [_gId, _gName, _gPassword, _gPhone]) {
        c.clear();
      }
      _gKyc.text = '7';
      setState(() {
        _authMode = 'password';
        _police = 'pending';
        _showForm = false;
      });
      await _load();
      if (mounted)
        await AppFeedback.success(context,
            title: context.t('swal.success'),
            message: context.t('admin.guardAdded'));
    } catch (e) {
      _toast('$e', tone: BadgeTone.alert);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _deleteGuard(GuardRow g) async {
    final ok = await AppFeedback.confirm(
      context,
      title: context.t('swal.confirmDelete'),
      message:
          context.tr('Delete guard ${g.guardId}?', 'गार्ड ${g.guardId} हटाएँ?'),
      destructive: true,
    );
    if (!ok) return;
    try {
      await _service.deleteGuard(g.id);
      await _load();
    } catch (e) {
      _toast('$e', tone: BadgeTone.alert);
    }
  }

  Future<void> _resetPassword(GuardRow g) async {
    final p = _newPassword.text;
    if (p.isEmpty || p.length < 4) {
      _toast(context.t('admin.passwordTooShort'), tone: BadgeTone.alert);
      return;
    }
    try {
      await _service.resetPassword(g.id, p);
      PeopleAudit.passwordReset(
          societyId: widget.ctx.societyId,
          userType: 'guard',
          userId: g.id,
          userName: 'guard',
          resetBy: 'admin');
      if (!mounted) return;
      _toast(context.t('admin.passwordChanged'));
      setState(() {
        _resetId = null;
        _newPassword.clear();
      });
      await _load();
    } catch (e) {
      _toast('$e', tone: BadgeTone.alert);
    }
  }

  void _toggleEdit(GuardRow g) {
    setState(() {
      if (_editingId == g.id) {
        _editingId = null;
      } else {
        _editingId = g.id;
        _eId.text = g.guardId;
        _eName.text = g.name;
        _ePhone.text = g.phone ?? '';
        _eKyc.text = '${g.kycAlertDays}';
        _eAuth = g.authMode;
        _ePolice = g.policeVerification;
      }
    });
  }

  Future<void> _updateGuard(GuardRow g) async {
    final name = _eName.text.trim();
    final gid = _eId.text.trim().toUpperCase();
    if (name.isEmpty) {
      _toast(context.tr('Name is required', 'नाम आवश्यक है'),
          tone: BadgeTone.alert);
      return;
    }
    if (gid.isEmpty) {
      _toast(context.tr('Guard ID is required', 'गार्ड आईडी आवश्यक है'),
          tone: BadgeTone.alert);
      return;
    }
    final phone = _ePhone.text.replaceAll(RegExp(r'\D'), '');
    if (_eAuth == 'otp' && phone.length < 10) {
      _toast(
          context.tr('OTP login requires a 10-digit phone number',
              'OTP लॉगिन हेतु 10-अंकों का फ़ोन नंबर आवश्यक है'),
          tone: BadgeTone.alert);
      return;
    }
    try {
      await _service.updateGuard(
        id: g.id,
        name: name,
        guardId: gid,
        authMode: _eAuth,
        policeVerification: _ePolice,
        kycAlertDays: _days(_eKyc.text),
        phoneDigits: phone,
      );
      if (!mounted) return;
      _toast(context.tr('Guard updated', 'गार्ड अद्यतन हुआ'));
      setState(() => _editingId = null);
      await _load();
    } catch (e) {
      _toast('$e', tone: BadgeTone.alert);
    }
  }

  Future<PickedImage?> _camera({int maxSide = 1600, int quality = 85}) =>
      PeopleImagePicker.pickFrom(ImageSource.camera,
          maxSide: maxSide, quality: quality);

  Future<PickedImage?> _gallery({int maxSide = 1600, int quality = 85}) =>
      PeopleImagePicker.pickFrom(ImageSource.gallery,
          maxSide: maxSide, quality: quality);

  Future<void> _profilePhoto(GuardRow g, ImageSource source) async {
    final p = await PeopleImagePicker.pickFrom(source);
    if (p == null) return;
    setState(() => _uploadingProfile = g.id);
    try {
      await _service.setProfilePhoto(
          guardUuid: g.id, bytes: p.bytes, fileName: p.name);
      if (!mounted) return;
      _toast(context.tr('Worker photo saved', 'कर्मचारी फ़ोटो सहेजी गई'));
      await _load();
    } catch (_) {
      if (mounted)
        _toast(context.tr('Photo upload failed', 'फ़ोटो अपलोड विफल'),
            tone: BadgeTone.alert);
    } finally {
      if (mounted) setState(() => _uploadingProfile = null);
    }
  }

  Future<void> _removeProfilePhoto(GuardRow g) async {
    final ok = await AppFeedback.confirm(
      context,
      title: context.tr('Remove photo?', 'फ़ोटो हटाएँ?'),
      message: context.tr('The worker profile photo will be cleared.',
          'कर्मचारी प्रोफ़ाइल फ़ोटो हटा दी जाएगी।'),
    );
    if (!ok) return;
    try {
      await _service.removeProfilePhoto(g.id);
      await _load();
    } catch (e) {
      _toast('$e', tone: BadgeTone.alert);
    }
  }

  Future<void> _uploadDoc(
      GuardRow g, String side, Future<PickedImage?> Function() pick,
      {String? existingDocId}) async {
    final p = await pick();
    if (p == null) return;
    setState(() => _uploadingDoc = true);
    try {
      await _service.uploadDoc(
        guardUuid: g.id,
        bytes: p.bytes,
        fileName: p.name,
        side: side,
        docLabel: _docLabel,
        existingDocId: existingDocId,
      );
      if (!mounted) return;
      _toast(side == 'front'
          ? context.tr('Front uploaded', 'आगे का भाग अपलोड हुआ')
          : context.tr('Back uploaded', 'पीछे का भाग अपलोड हुआ'));
      await _load();
    } catch (_) {
      if (mounted)
        _toast(context.tr('Upload failed', 'अपलोड विफल'),
            tone: BadgeTone.alert);
    } finally {
      if (mounted) setState(() => _uploadingDoc = false);
    }
  }

  Future<void> _uploadAttachments(GuardRow g, {required bool camera}) async {
    final files = <({Uint8List bytes, String name})>[];
    if (camera) {
      final p = await _camera();
      if (p == null) return;
      files.add((bytes: p.bytes, name: p.name));
    } else {
      final res = await FilePicker.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: const [
          'jpg',
          'jpeg',
          'png',
          'webp',
          'gif',
          'heic',
          'heif',
          'pdf'
        ],
        withData: true,
      );
      if (res == null) return;
      for (final f in res.files) {
        final b = f.bytes;
        if (b != null) files.add((bytes: b, name: f.name));
      }
      if (files.isEmpty) return;
    }
    setState(() => _uploadingDoc = true);
    try {
      final n = await _service.uploadAttachments(
        guardUuid: g.id,
        files: files,
        docLabel: _attachLabel.text,
        existingCount: (_snap.attachments[g.id] ?? const []).length,
      );
      if (!mounted) return;
      _toast(n == 1
          ? context.tr('Document saved', 'दस्तावेज़ सहेजा गया')
          : context.tr('$n documents saved', '$n दस्तावेज़ सहेजे गए'));
      await _load();
    } catch (_) {
      if (mounted)
        _toast(context.tr('Document upload failed', 'दस्तावेज़ अपलोड विफल'),
            tone: BadgeTone.alert);
      await _load();
    } finally {
      if (mounted) setState(() => _uploadingDoc = false);
    }
  }

  Future<void> _deleteDoc(GuardDoc d) async {
    final ok = await AppFeedback.confirm(
      context,
      title: context.tr('Delete Document?', 'दस्तावेज़ हटाएँ?'),
      message: context.tr('This ID document will be removed.',
          'यह आईडी दस्तावेज़ हटा दिया जाएगा।'),
      destructive: true,
    );
    if (!ok) return;
    try {
      await _service.deleteDoc(d.id);
      await _load();
    } catch (e) {
      _toast('$e', tone: BadgeTone.alert);
    }
  }

  Future<void> _deleteAttachment(GuardAttachment a) async {
    final ok = await AppFeedback.confirm(
      context,
      title: context.tr('Delete document?', 'दस्तावेज़ हटाएँ?'),
      message:
          context.tr('This file will be removed.', 'यह फ़ाइल हटा दी जाएगी।'),
      destructive: true,
    );
    if (!ok) return;
    try {
      await _service.deleteAttachment(a.id);
      await _load();
    } catch (e) {
      _toast('$e', tone: BadgeTone.alert);
    }
  }

  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    if (_error != null && _snap.guards.isEmpty)
      return ErrorView(onRetry: _load);
    final t = context.tokens;
    final kycPending =
        _snap.guards.where((g) => g.policeVerification != 'done').toList();
    final header = <Widget>[
      PageHeader(
        icon: Icons.shield_outlined,
        title: context.t('admin.manageGuards'),
        subtitle:
            '${_snap.guards.length} ${context.t('admin.guardsRegistered')}',
        actions: [
          TintIconButton(
              icon: _showForm ? Icons.close : Icons.add,
              size: 20,
              onPressed: () => setState(() => _showForm = !_showForm))
        ],
      ),
      if (kycPending.isNotEmpty) ...[
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTokens.tint(t.warning, 0.1),
            border: Border.all(color: AppTokens.tint(t.warning, 0.3)),
            borderRadius: BorderRadius.circular(AppTokens.radius),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.warning_amber_rounded, size: 16, color: t.warning),
              const SizedBox(width: 8),
              Text(
                  context.tr('KYC Pending (${kycPending.length})',
                      'KYC लंबित (${kycPending.length})'),
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: t.warning)),
            ]),
            const SizedBox(height: 6),
            for (final g in kycPending)
              Padding(
                padding: const EdgeInsets.only(left: 24, top: 2),
                child: Text(
                  context.tr(
                      '• ${g.name} (${g.guardId}) - Police verification pending',
                      '• ${g.name} (${g.guardId}) - पुलिस सत्यापन लंबित'),
                  style: TextStyle(fontSize: 12, color: t.warning),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 16),
      ],
      if (_showForm) ...[_addForm(context), const SizedBox(height: 16)],
      if (_snap.guards.isEmpty)
        EmptyView(message: context.tr('No guards yet', 'अभी कोई गार्ड नहीं')),
    ];
    return LazyListPage(
      onRefresh: _load,
      header: header,
      itemCount: _snap.guards.length,
      itemBuilder: (context, i) => _guardCard(context, _snap.guards[i]),
    );
  }

  Widget _modeButton(String label, bool selected, VoidCallback onTap) {
    final t = context.tokens;
    return Expanded(
      child: Material(
        color: selected ? AppTokens.tint(t.primary, 0.1) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          side: BorderSide(color: selected ? t.primary : t.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Center(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: selected ? t.primary : t.mutedForeground)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _addForm(BuildContext context) {
    return CardSection(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AppTextField(
            hint: context.tr('Guard ID (e.g. G002)', 'गार्ड आईडी (जैसे G002)'),
            controller: _gId,
            mono: true,
            inputFormatters: [_Upper()]),
        const SizedBox(height: 12),
        AppTextField(
            hint: context.tr('Full Name', 'पूरा नाम'), controller: _gName),
        const SizedBox(height: 12),
        FieldLabel(context.tr('Login Method', 'लॉगिन विधि')),
        Row(children: [
          _modeButton(
              context.tr('Password', 'पासवर्ड'),
              _authMode == 'password',
              () => setState(() => _authMode = 'password')),
          const SizedBox(width: 8),
          _modeButton(context.tr('OTP (Phone)', 'OTP (फ़ोन)'),
              _authMode == 'otp', () => setState(() => _authMode = 'otp')),
        ]),
        const SizedBox(height: 12),
        if (_authMode == 'password')
          AppTextField(
              hint: context.tr('Password', 'पासवर्ड'),
              controller: _gPassword,
              caps: false)
        else
          AppTextField(
            hint: context.tr('Phone (10 digits)', 'फ़ोन (10 अंक)'),
            controller: _gPhone,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            mono: true,
            prefixIcon: Icons.phone_outlined,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        const SizedBox(height: 12),
        AppDropdown<String>(
          label: context.tr('Police Verification', 'पुलिस सत्यापन'),
          items: const ['pending', 'done'],
          value: _police,
          labelOf: (v) => v == 'done'
              ? context.tr('Done', 'पूर्ण')
              : context.tr('Pending', 'लंबित'),
          onChanged: (v) => setState(() => _police = v ?? 'pending'),
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: context.tr(
              'KYC Alert (days if pending)', 'KYC अलर्ट (लंबित होने पर दिन)'),
          controller: _gKyc,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            _RangeFormatter(1, 365)
          ],
        ),
        const SizedBox(height: 16),
        AppButton(
            label: context.t('common.add'),
            loading: _adding,
            onPressed: _addGuard),
      ]),
    );
  }

  Widget _badge(String text, Color color, {bool muted = false}) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: muted ? t.muted : AppTokens.tint(color, 0.1),
          borderRadius: BorderRadius.circular(999)),
      child: Text(text,
          style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: muted ? t.mutedForeground : color)),
    );
  }

  Widget _photoThumb(GuardRow g, double size) {
    final t = context.tokens;
    final url = g.photoUrl;
    return GestureDetector(
      onTap: url == null ? null : () => PhotoViewer.show(context, url),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            color: t.muted,
            border: Border.all(color: t.border),
            borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
        clipBehavior: Clip.antiAlias,
        child: url == null
            ? Icon(Icons.shield_outlined, size: 20, color: t.mutedForeground)
            : ImageThumb(
                src: url,
                width: size,
                height: size,
                radius: AppTokens.radiusSm,
                onTap: () => PhotoViewer.show(context, url)),
      ),
    );
  }

  Widget _guardCard(BuildContext context, GuardRow g) {
    final t = context.tokens;
    final showPass = _showPasswords.contains(g.id);
    return CardSection(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _photoThumb(g, 48),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(g.name, style: AppText.sectionTitle(context)),
                    g.authMode == 'otp'
                        ? _badge('OTP', t.accent)
                        : _badge('PWD', t.mutedForeground, muted: true),
                    _badge('KYC: ${g.policeVerification}',
                        g.policeVerification == 'done' ? t.success : t.warning),
                  ]),
              Text(g.guardId,
                  style: AppText.mono(context,
                      size: 12,
                      weight: FontWeight.w600,
                      color: t.mutedForeground)),
              if (g.phone != null)
                Text('📞 ${g.phone}', style: AppText.caption(context)),
              if (g.authMode == 'password')
                Row(children: [
                  Text(showPass ? g.password : '••••••',
                      style: AppText.caption(context)),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => setState(() => showPass
                        ? _showPasswords.remove(g.id)
                        : _showPasswords.add(g.id)),
                    child: Icon(
                        showPass
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 14,
                        color: t.mutedForeground),
                  ),
                ]),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TintIconButton(
            icon: Icons.image_outlined,
            color: t.accent,
            tooltip: context.tr('Photo & documents', 'फ़ोटो और दस्तावेज़'),
            onPressed: () =>
                setState(() => _expandedId = _expandedId == g.id ? null : g.id),
          ),
          const SizedBox(width: 4),
          TintIconButton(
              icon: Icons.edit_outlined,
              tooltip:
                  context.tr('Edit guard details', 'गार्ड विवरण संपादित करें'),
              onPressed: () => _toggleEdit(g)),
          const SizedBox(width: 4),
          TintIconButton(
            icon: Icons.key_outlined,
            color: t.warning,
            tooltip: context.t('admin.newPassword'),
            onPressed: () => setState(() {
              _resetId = _resetId == g.id ? null : g.id;
              _newPassword.clear();
            }),
          ),
          const SizedBox(width: 4),
          TintIconButton(
              icon: Icons.delete_outline,
              color: t.destructive,
              tooltip: context.t('common.delete'),
              onPressed: () => _deleteGuard(g)),
        ]),
        if (_editingId == g.id) ...[
          const SizedBox(height: 12),
          _editPanel(context, g)
        ],
        if (_resetId == g.id) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: AppTextField(
                    hint: context.t('admin.newPassword'),
                    controller: _newPassword,
                    caps: false)),
            const SizedBox(width: 8),
            AppButton(
                label: context.t('common.save'),
                expand: false,
                onPressed: () => _resetPassword(g)),
          ]),
        ],
        if (_expandedId == g.id) ...[
          const SizedBox(height: 12),
          _docsPanel(context, g)
        ],
      ]),
    );
  }

  Widget _editPanel(BuildContext context, GuardRow g) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTokens.tint(t.muted, 0.5),
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(context.tr('Edit guard', 'गार्ड संपादित करें'),
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: t.foreground)),
        const SizedBox(height: 8),
        AppTextField(
            hint: context.tr('Guard ID', 'गार्ड आईडी'),
            controller: _eId,
            mono: true,
            inputFormatters: [_Upper()]),
        const SizedBox(height: 8),
        AppTextField(
            hint: context.tr('Full name', 'पूरा नाम'), controller: _eName),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: AppDropdown<String>(
              items: const ['password', 'otp'],
              value: _eAuth,
              labelOf: (v) => v == 'otp'
                  ? context.tr('OTP Login', 'OTP लॉगिन')
                  : context.tr('Password Login', 'पासवर्ड लॉगिन'),
              onChanged: (v) => setState(() => _eAuth = v ?? 'password'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AppDropdown<String>(
              items: const ['pending', 'done'],
              value: _ePolice,
              labelOf: (v) => v == 'done'
                  ? context.tr('KYC Done', 'KYC पूर्ण')
                  : context.tr('KYC Pending', 'KYC लंबित'),
              onChanged: (v) => setState(() => _ePolice = v ?? 'pending'),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        AppTextField(
          hint: _eAuth == 'otp'
              ? context.tr('Phone (10 digits, required for OTP)',
                  'फ़ोन (10 अंक, OTP हेतु आवश्यक)')
              : context.tr('Phone (optional)', 'फ़ोन (वैकल्पिक)'),
          controller: _ePhone,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          mono: true,
          prefixIcon: Icons.phone_outlined,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: 8),
        Row(children: [
          Text(context.tr('KYC alert (days):', 'KYC अलर्ट (दिन):'),
              style: AppText.caption(context)),
          const SizedBox(width: 8),
          Expanded(
            child: AppTextField(
              controller: _eKyc,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                _RangeFormatter(1, 365)
              ],
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Text(
          context.tr(
            'Use the key button below to change password. OTP guards use the phone number above.',
            'पासवर्ड बदलने के लिए चाबी बटन का उपयोग करें। OTP गार्ड ऊपर दिए फ़ोन नंबर का उपयोग करते हैं।',
          ),
          style: AppText.tiny(context),
        ),
        const SizedBox(height: 10),
        AppButton(
            label: context.tr('Save changes', 'परिवर्तन सहेजें'),
            onPressed: () => _updateGuard(g)),
      ]),
    );
  }

  Widget _linkAction(IconData icon, String label, VoidCallback? onTap) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: t.mutedForeground),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: t.mutedForeground,
                  decoration: TextDecoration.underline)),
        ]),
      ),
    );
  }

  Widget _docsPanel(BuildContext context, GuardRow g) {
    final t = context.tokens;
    final docs = _snap.docs[g.id] ?? const <GuardDoc>[];
    final atts = _snap.attachments[g.id] ?? const <GuardAttachment>[];
    final uploadingProfile = _uploadingProfile == g.id;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppTokens.tint(t.muted, 0.5),
          borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Worker photo
        Text(context.tr('Worker photo', 'कर्मचारी फ़ोटो'),
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: t.foreground)),
        Text(
          context.tr(
              'Shown in the list next to guard ID. Tap the thumbnail to enlarge.',
              'सूची में गार्ड आईडी के पास दिखती है। बड़ा देखने के लिए थंबनेल दबाएँ।'),
          style: AppText.tiny(context),
        ),
        const SizedBox(height: 8),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _photoThumb(g, 40),
              AppButton.secondary(
                label: context.tr('Take photo', 'फ़ोटो लें'),
                icon: Icons.photo_camera_outlined,
                dense: true,
                expand: false,
                loading: uploadingProfile,
                onPressed: uploadingProfile
                    ? null
                    : () => _profilePhoto(g, ImageSource.camera),
              ),
              AppButton.secondary(
                label: context.tr('Gallery', 'गैलरी'),
                icon: Icons.add_photo_alternate_outlined,
                dense: true,
                expand: false,
                onPressed: uploadingProfile
                    ? null
                    : () => _profilePhoto(g, ImageSource.gallery),
              ),
              if (g.photoUrl != null)
                TextButton(
                  onPressed: () => _removeProfilePhoto(g),
                  child: Text(context.tr('Remove photo', 'फ़ोटो हटाएँ'),
                      style: TextStyle(
                          fontSize: 12,
                          color: t.destructive,
                          decoration: TextDecoration.underline)),
                ),
            ]),
        const SizedBox(height: 16),
        // Photo ID
        Text(context.tr('Photo ID', 'फ़ोटो आईडी'),
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: t.foreground)),
        Text(
          context.tr(
              'Add ID cards with front and back images. Tap a thumbnail to enlarge.',
              'आगे और पीछे की फ़ोटो के साथ आईडी कार्ड जोड़ें। बड़ा देखने के लिए थंबनेल दबाएँ।'),
          style: AppText.tiny(context),
        ),
        const SizedBox(height: 8),
        for (final d in docs)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: t.background,
                borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.docLabel,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: t.foreground)),
                      const SizedBox(height: 4),
                      Wrap(spacing: 8, children: [
                        if (d.frontUrl != null) _docThumb(d.frontUrl!),
                        if (d.backUrl != null) _docThumb(d.backUrl!),
                      ]),
                      const SizedBox(height: 4),
                      Wrap(spacing: 10, children: [
                        _linkAction(
                            Icons.photo_camera_outlined,
                            d.frontUrl != null
                                ? context.tr('Replace front', 'आगे बदलें')
                                : context.tr('Front (camera)', 'आगे (कैमरा)'),
                            _uploadingDoc
                                ? null
                                : () => _uploadDoc(g, 'front', _camera,
                                    existingDocId: d.id)),
                        _linkAction(
                            Icons.add_photo_alternate_outlined,
                            context.tr('Front (gallery)', 'आगे (गैलरी)'),
                            _uploadingDoc
                                ? null
                                : () => _uploadDoc(g, 'front', _gallery,
                                    existingDocId: d.id)),
                        _linkAction(
                            Icons.photo_camera_outlined,
                            d.backUrl != null
                                ? context.tr('Replace back', 'पीछे बदलें')
                                : context.tr('Back (camera)', 'पीछे (कैमरा)'),
                            _uploadingDoc
                                ? null
                                : () => _uploadDoc(g, 'back', _camera,
                                    existingDocId: d.id)),
                        _linkAction(
                            Icons.add_photo_alternate_outlined,
                            context.tr('Back (gallery)', 'पीछे (गैलरी)'),
                            _uploadingDoc
                                ? null
                                : () => _uploadDoc(g, 'back', _gallery,
                                    existingDocId: d.id)),
                      ]),
                    ]),
              ),
              TintIconButton(
                  icon: Icons.delete_outline,
                  filled: false,
                  size: 14,
                  padding: 4,
                  color: t.destructive,
                  onPressed: () => _deleteDoc(d)),
            ]),
          ),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: AppDropdown<String>(
              label: context.tr('ID document type', 'आईडी दस्तावेज़ प्रकार'),
              items: _idDocLabels,
              value: _docLabel,
              labelOf: (v) => v,
              onChanged: (v) =>
                  setState(() => _docLabel = v ?? _idDocLabels.first),
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _uploadingDoc
                ? const SizedBox(
                    width: 32,
                    height: 32,
                    child: Padding(
                        padding: EdgeInsets.all(6),
                        child: CircularProgressIndicator(strokeWidth: 2)))
                : TintIconButton(
                    icon: Icons.upload_outlined,
                    tooltip: context.tr(
                        'Add new ID (front)', 'नई आईडी जोड़ें (आगे)'),
                    onPressed: () => _uploadDoc(g, 'front', _gallery),
                  ),
          ),
        ]),
        const SizedBox(height: 16),
        // Attachments
        DottedBox(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(context.tr('Documents', 'दस्तावेज़'),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: t.foreground)),
            Text(
              context.tr(
                'Save multiple images or PDFs per worker. Use Browse to pick many files at once, or Take photo for the camera.',
                'प्रत्येक कर्मचारी के लिए कई फ़ोटो या PDF सहेजें। एक साथ कई फ़ाइलें चुनने के लिए ब्राउज़ करें, या कैमरे से फ़ोटो लें।',
              ),
              style: AppText.tiny(context),
            ),
            const SizedBox(height: 8),
            AppTextField(
              label: context.tr('Label', 'लेबल'),
              hint: context.tr('e.g. Police verification, Contract',
                  'जैसे पुलिस सत्यापन, अनुबंध'),
              controller: _attachLabel,
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              AppButton(
                label: context.tr('Browse files', 'फ़ाइलें चुनें'),
                dense: true,
                expand: false,
                loading: _uploadingDoc,
                onPressed: _uploadingDoc
                    ? null
                    : () => _uploadAttachments(g, camera: false),
              ),
              AppButton.secondary(
                label: context.tr('Take photo', 'फ़ोटो लें'),
                icon: Icons.photo_camera_outlined,
                dense: true,
                expand: false,
                onPressed: _uploadingDoc
                    ? null
                    : () => _uploadAttachments(g, camera: true),
              ),
            ]),
            if (atts.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 10, runSpacing: 10, children: [
                for (final a in atts)
                  SizedBox(
                    width: 60,
                    child: Stack(clipBehavior: Clip.none, children: [
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            isPdfUrl(a.fileUrl)
                                ? InkWell(
                                    onTap: () => ExportKit.openUrl(a.fileUrl),
                                    child: Container(
                                      width: 56,
                                      height: 56,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: t.background,
                                        border: Border.all(color: t.border),
                                        borderRadius: BorderRadius.circular(
                                            AppTokens.radiusSm),
                                      ),
                                      child: Text('PDF',
                                          style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w500,
                                              color: t.primary)),
                                    ),
                                  )
                                : ImageThumb(
                                    src: a.fileUrl,
                                    width: 56,
                                    height: 56,
                                    radius: AppTokens.radiusSm),
                            const SizedBox(height: 2),
                            Text(a.docLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 9, color: t.mutedForeground)),
                          ]),
                      Positioned(
                        top: -4,
                        right: -2,
                        child: GestureDetector(
                          onTap: () => _deleteAttachment(a),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                                color: t.destructive, shape: BoxShape.circle),
                            child: Icon(Icons.close,
                                size: 10, color: t.destructiveForeground),
                          ),
                        ),
                      ),
                    ]),
                  ),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _docThumb(String url) {
    final t = context.tokens;
    if (isPdfUrl(url)) {
      return InkWell(
        onTap: () => ExportKit.openUrl(url),
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: t.muted,
              border: Border.all(color: t.border),
              borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
          child: Text('PDF',
              style: TextStyle(fontSize: 9, color: t.mutedForeground)),
        ),
      );
    }
    return ImageThumb(
        src: url, width: 56, height: 56, radius: AppTokens.radiusSm);
  }
}

/// Dashed-looking bordered box (`border border-dashed border-border rounded-lg p-3`).
class DottedBox extends StatelessWidget {
  const DottedBox({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: context.tokens.border, width: 1.2),
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      ),
      child: child,
    );
  }
}

class _Upper extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
          TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}

/// Keeps numeric input within `min..max` (`<input type=number min max>`).
class _RangeFormatter extends TextInputFormatter {
  _RangeFormatter(this.min, this.max);

  final int min;
  final int max;

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final n = int.tryParse(newValue.text);
    if (n == null || n > max) return oldValue;
    return newValue;
  }
}
