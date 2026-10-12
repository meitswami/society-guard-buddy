import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/export/export_kit.dart';
import '../../../core/ui/ui.dart';
import '../../../utils/member_categories.dart';
import '../../../utils/society_flat_layout.dart' show floorLabelFromFlatNumber;
import '../../shared/directory/directory_search.dart';
import '../../shared/directory/directory_widgets.dart';
import '../../shared/directory/person_avatar.dart';
import '../core/admin_module.dart';
import 'data/people_models.dart';
import 'data/residents_service.dart';
import 'export/residents_pdf.dart';
import 'export/society_letterhead.dart';
import 'flat360/flat360_models.dart';
import 'flat360/flat360_panel.dart';
import 'logic/residents_logic.dart';
import 'residents/flat_generator_page.dart';
import 'residents/member_form_page.dart';
import 'widgets/sensitive_verify.dart';

/// Admin → Residents — port of web `src/components/AdminResidentManager.tsx`:
/// flats (add / edit floor-wing-intercom / delete), household members (owner & tenant groups,
/// staff with ID documents and vehicles, primary member), shared flat login accounts
/// (show / reset password), resident self-service Photo ID policy, Flat 360° profile,
/// residents directory PDF (export + WhatsApp share) and bulk flat generation.
///
/// `ctx.initialQuery` pre-fills the search; `ctx.subTab` = `flat:<flatId>` opens that flat
/// (Directory → Edit).
class AdminResidentsModule extends StatefulWidget {
  const AdminResidentsModule({super.key, required this.ctx});

  final AdminModuleContext ctx;

  @override
  State<AdminResidentsModule> createState() => _AdminResidentsModuleState();
}

enum _DetailView { manage, profile360 }

class _AdminResidentsModuleState extends State<AdminResidentsModule> {
  final _service = ResidentsService();
  final _search = TextEditingController();

  ResidentsSnapshot _snap = ResidentsSnapshot.empty;
  bool _loading = true;
  Object? _error;

  Map<String, List<PeopleMember>> _membersByFlat = const {};
  Map<String, List<PeopleVehicle>> _vehiclesByNumber = const {};
  Map<String, List<ResidentLogin>> _loginsByFlat = const {};

  String? _expandedId;
  _DetailView _detail = _DetailView.manage;
  final Set<String> _showPassword = {};
  bool _exporting = false;
  String? _pendingExpand;

  // Add flat form.
  bool _addFlatOpen = false;
  bool _floorTouched = false;
  final _fNumber = TextEditingController();
  final _fFloor = TextEditingController();
  final _fWing = TextEditingController(text: 'A');
  final _fOwner = TextEditingController();
  final _fOwnerPhone = TextEditingController();
  final _fIntercom = TextEditingController();

  // Flat meta edit.
  String? _metaEditId;
  final _mFloor = TextEditingController();
  final _mWing = TextEditingController();
  final _mIntercom = TextEditingController();

  String get _sid => widget.ctx.societyId;

  @override
  void initState() {
    super.initState();
    _applyContext();
    _load();
  }

  @override
  void didUpdateWidget(covariant AdminResidentsModule old) {
    super.didUpdateWidget(old);
    if (old.ctx.initialQuery != widget.ctx.initialQuery || old.ctx.subTab != widget.ctx.subTab) {
      _applyContext();
      _applyPendingExpand();
    }
  }

  void _applyContext() {
    final q = widget.ctx.initialQuery?.trim();
    if (q != null && q.isNotEmpty) _search.text = q;
    final sub = widget.ctx.subTab;
    if (sub != null && sub.startsWith('flat:')) _pendingExpand = sub.substring(5);
  }

  void _applyPendingExpand() {
    final id = _pendingExpand;
    if (id == null || _snap.flats.isEmpty) return;
    _pendingExpand = null;
    final flat = _snap.flats.where((f) => f.id == id).firstOrNull;
    if (flat == null) return;
    setState(() {
      _expandedId = id;
      _detail = _DetailView.manage;
      _addFlatOpen = false;
      if (_search.text.trim().isEmpty) _search.text = flat.flatNumber;
    });
  }

  @override
  void dispose() {
    for (final c in [_search, _fNumber, _fFloor, _fWing, _fOwner, _fOwnerPhone, _fIntercom, _mFloor, _mWing, _mIntercom]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _snap.flats.isEmpty;
      _error = null;
    });
    try {
      final snap = await _service.load(_sid);
      if (!mounted) return;
      final logins = <String, List<ResidentLogin>>{};
      for (final l in snap.logins) {
        (logins[l.flatId] ??= []).add(l);
      }
      setState(() {
        _snap = snap;
        _membersByFlat = membersByFlatId(snap.members);
        _vehiclesByNumber = vehiclesByFlatNumber(snap.vehicles);
        _loginsByFlat = logins;
        _loading = false;
      });
      _applyPendingExpand();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  /// Web `runSensitive`: password / biometric re-verification, then the action.
  Future<void> _sensitive(String action, String title, Future<void> Function() fn) async {
    final ok = await SensitiveVerify.confirm(
      context,
      societyId: _sid,
      adminId: widget.ctx.adminId,
      adminName: widget.ctx.adminName,
      title: title,
      actionLabel: action,
    );
    if (!ok || !mounted) return;
    try {
      await fn();
    } catch (e) {
      if (mounted) AppFeedback.toast(context, '$e', tone: BadgeTone.alert);
    }
  }

  void _toast(String en, String hi, {BadgeTone tone = BadgeTone.success}) {
    if (mounted) AppFeedback.toast(context, context.tr(en, hi), tone: tone);
  }

  // ---- Flats -----------------------------------------------------------------
  void _toggleAddFlat() {
    setState(() {
      if (!_addFlatOpen) {
        _floorTouched = false;
        for (final c in [_fNumber, _fFloor, _fOwner, _fOwnerPhone, _fIntercom]) {
          c.clear();
        }
        _fWing.text = 'A';
      }
      _addFlatOpen = !_addFlatOpen;
    });
  }

  void _onFlatNumberChanged(String v) {
    if (_floorTouched) return;
    final sug = floorLabelFromFlatNumber(v);
    if (sug != null) {
      _fFloor.text = sug;
    } else if (v.trim().isEmpty) {
      _fFloor.clear();
    }
  }

  Future<void> _saveFlat() async {
    final number = _fNumber.text;
    if (number.isEmpty) {
      _toast('Flat number is required', 'फ्लैट नंबर आवश्यक है', tone: BadgeTone.alert);
      return;
    }
    if (_snap.flats.any((f) => f.flatNumber == number)) {
      _toast('Flat number already exists', 'यह फ्लैट नंबर पहले से मौजूद है', tone: BadgeTone.alert);
      return;
    }
    await _sensitive('add_flat', context.tr('Add flat', 'फ्लैट जोड़ें'), () async {
      await _service.addFlat(
        societyId: _sid,
        flatNumber: number,
        floor: _fFloor.text,
        wing: _fWing.text,
        ownerName: _fOwner.text,
        ownerPhone: _fOwnerPhone.text,
        intercom: _fIntercom.text,
      );
      _toast('Flat added successfully', 'फ्लैट सफलतापूर्वक जोड़ा गया');
      setState(() {
        _addFlatOpen = false;
        _floorTouched = false;
      });
      await _load();
    });
  }

  void _startMetaEdit(PeopleFlat f) {
    setState(() {
      _metaEditId = f.id;
      _mFloor.text = f.floor ?? '';
      _mWing.text = f.wing ?? '';
      _mIntercom.text = f.intercom ?? '';
    });
  }

  Future<void> _saveMeta() async {
    final id = _metaEditId;
    if (id == null) return;
    await _sensitive('edit_flat_meta', context.tr('Update flat details', 'फ्लैट विवरण अद्यतन करें'), () async {
      await _service.updateFlatMeta(flatId: id, floor: _mFloor.text, wing: _mWing.text, intercom: _mIntercom.text);
      _toast('Flat details updated', 'फ्लैट विवरण अद्यतन हुआ');
      setState(() => _metaEditId = null);
      await _load();
    });
  }

  Future<void> _removeFlat(PeopleFlat f) async {
    final ok = await AppFeedback.confirm(
      context,
      title: context.tr('Delete Flat?', 'फ्लैट हटाएँ?'),
      message: context.tr('This will remove the flat, all members and login accounts.', 'इससे फ्लैट, सभी सदस्य और लॉगिन खाते हट जाएँगे।'),
      confirmLabel: context.t('common.delete'),
      cancelLabel: context.t('common.cancel'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    await _sensitive('remove_flat', context.tr('Delete flat and all members', 'फ्लैट और सभी सदस्य हटाएँ'), () async {
      await _service.removeFlat(f.id);
      if (!mounted) return;
      await AppFeedback.success(context, title: context.tr('Deleted!', 'हटाया गया!'), message: context.tr('Flat and all data removed', 'फ्लैट और सारा डेटा हटाया गया'));
      setState(() => _expandedId = null);
      await _load();
    });
  }

  Future<void> _resetPassword(PeopleFlat f) async {
    final ok = await AppFeedback.confirm(
      context,
      title: context.tr('Reset Password?', 'पासवर्ड रीसेट करें?'),
      message: context.tr('Generate a new password for all members of this flat?', 'इस फ्लैट के सभी सदस्यों के लिए नया पासवर्ड बनाएँ?'),
      confirmLabel: context.tr('Yes, Reset', 'हाँ, रीसेट करें'),
      cancelLabel: context.t('common.cancel'),
    );
    if (!ok || !mounted) return;
    await _sensitive('reset_flat_password', context.tr('Reset resident login password', 'निवासी लॉगिन पासवर्ड रीसेट करें'), () async {
      final pass = await _service.resetFlatPassword(f.id);
      if (!mounted) return;
      await showPasswordDialog(context, title: context.tr('Password Reset!', 'पासवर्ड रीसेट!'), password: pass);
      await _load();
    });
  }

  Future<void> _toggleSelfId(bool on) async {
    await _sensitive('resident_self_id_policy', context.tr('Change resident ID upload policy', 'निवासी आईडी अपलोड नीति बदलें'), () async {
      await _service.setSelfIdUploadEnabled(_sid, on);
      if (!mounted) return;
      setState(() => _snap = ResidentsSnapshot(
            flats: _snap.flats,
            members: _snap.members,
            vehicles: _snap.vehicles,
            logins: _snap.logins,
            selfIdUploadEnabled: on,
          ));
      on
          ? _toast('Residents can add or edit their own Photo ID in the app (Profile).', 'निवासी ऐप (प्रोफ़ाइल) में अपनी फ़ोटो आईडी जोड़/बदल सकते हैं।')
          : _toast('Self-service Photo ID turned off', 'स्व-सेवा फ़ोटो आईडी बंद की गई');
    });
  }

  // ---- Members -----------------------------------------------------------------
  Future<void> _openMemberForm(PeopleFlat flat, {PeopleMember? editing}) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => MemberFormPage(
        societyId: _sid,
        adminId: widget.ctx.adminId,
        adminName: widget.ctx.adminName,
        flat: flat,
        flatMembers: _membersByFlat[flat.id] ?? const [],
        editing: editing,
      ),
    ));
    if (changed == true) await _load();
  }

  Future<void> _removeMember(PeopleMember m) async {
    final ok = await AppFeedback.confirm(
      context,
      title: context.tr('Delete Member?', 'सदस्य हटाएँ?'),
      message: context.tr('This member will be removed permanently.', 'यह सदस्य स्थायी रूप से हटा दिया जाएगा।'),
      confirmLabel: context.t('common.delete'),
      cancelLabel: context.t('common.cancel'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    await _sensitive('remove_member', context.tr('Remove household member', 'परिवार सदस्य हटाएँ'), () async {
      await _service.removeMember(m);
      _toast('Member removed', 'सदस्य हटाया गया');
      await _load();
    });
  }

  Future<void> _setPrimary(PeopleMember m) async {
    if (!allowsPrimaryMember(m.relation)) {
      _toast('Only household members can be primary (not tenant, staff, or other)',
          'केवल परिवार सदस्य प्राथमिक हो सकते हैं (किरायेदार, स्टाफ़ या अन्य नहीं)',
          tone: BadgeTone.alert);
      return;
    }
    await _sensitive('set_primary_member', context.tr('Change primary member', 'प्राथमिक सदस्य बदलें'), () async {
      await _service.setPrimaryMember(target: m, flatMembers: _membersByFlat[m.flatId] ?? const []);
      if (!mounted) return;
      await AppFeedback.success(context, title: context.tr('Updated!', 'अद्यतन!'), message: context.tr('Primary member changed', 'प्राथमिक सदस्य बदला गया'));
      await _load();
    });
  }

  // ---- Export -----------------------------------------------------------------
  Future<(String, Uint8List)?> _buildPdf({bool warn = true}) async {
    final name = await _service.societyName(_sid);
    final lh = await resolveLetterheadContext(_sid, fallbackName: name);
    if (warn && lh.warning != null && mounted) {
      AppFeedback.toast(context, context.tr(lh.warning!, 'आधिकारिक सोसाइटी लेटरहेड कॉन्फ़िगर नहीं है।'), tone: BadgeTone.warning);
    }
    final bytes = await buildResidentsDirectoryPdf(flats: _snap.flats, members: _snap.members, letterhead: lh);
    return (residentsDirectoryPdfFilename(name), bytes);
  }

  Future<void> _export({required bool share}) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    final message = context.tr('Resident directory', 'निवासी निर्देशिका');
    try {
      final r = await _buildPdf(warn: !share);
      if (r == null) return;
      if (share) {
        await ExportKit.sharePdf(r.$2, r.$1, text: message);
      } else {
        await ExportKit.printPdf(r.$2, name: r.$1);
      }
    } catch (_) {
      _toast('Could not share PDF', 'PDF साझा नहीं हो सका', tone: BadgeTone.alert);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _openGenerator() async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => FlatGeneratorPage(societyId: _sid, adminId: widget.ctx.adminId, adminName: widget.ctx.adminName),
    ));
    if (changed == true) await _load();
  }

  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    if (_error != null && _snap.flats.isEmpty) return ErrorView(onRetry: _load);
    final t = context.tokens;
    final query = _search.text;
    final flats = filterAdminFlats(flats: _snap.flats, membersByFlat: _membersByFlat, query: query);

    final header = <Widget>[
      PageHeader(
        icon: Icons.groups_outlined,
        title: context.t('admin.manageResidents'),
        subtitle: context.tr('${_snap.flats.length} flats · ${_snap.members.length} members', '${_snap.flats.length} फ्लैट · ${_snap.members.length} सदस्य'),
        bottomSpacing: 12,
      ),
      Wrap(spacing: 8, runSpacing: 8, children: [
        AppButton.secondary(
          label: _exporting ? 'PDF…' : context.t('mobile.exportPdf'),
          icon: Icons.file_download_outlined,
          dense: true,
          expand: false,
          onPressed: _exporting ? null : () => _export(share: false),
        ),
        _TintButton(
          label: context.tr('Share on WhatsApp', 'व्हाट्सऐप पर साझा करें'),
          icon: Icons.share_outlined,
          color: t.success,
          onPressed: _exporting ? null : () => _export(share: true),
        ),
        _TintButton(
          label: context.tr('Add Flat', 'फ्लैट जोड़ें'),
          icon: _addFlatOpen ? Icons.close : Icons.add,
          color: t.primary,
          onPressed: _toggleAddFlat,
        ),
        _TintButton(
          label: context.tr('Generate flats', 'फ्लैट बनाएँ'),
          icon: Icons.grid_view_outlined,
          color: t.accent,
          onPressed: _openGenerator,
        ),
      ]),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTokens.tint(t.card, 0.5),
          border: Border.all(color: t.border),
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.tr('Resident self-service Photo ID', 'निवासी स्व-सेवा फ़ोटो आईडी'),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: t.foreground)),
              Text(
                context.tr(
                  'When on, logged-in residents see Profile options to upload or change their own ID (front/back) only for their linked member row.',
                  'चालू होने पर, लॉग-इन निवासी प्रोफ़ाइल में केवल अपनी सदस्य पंक्ति की आईडी (आगे/पीछे) अपलोड या बदल सकते हैं।',
                ),
                style: AppText.tiny(context),
              ),
            ]),
          ),
          Switch(value: _snap.selfIdUploadEnabled, onChanged: _toggleSelfId),
        ]),
      ),
      const SizedBox(height: 16),
      if (_addFlatOpen) ...[_addFlatCard(context), const SizedBox(height: 16)],
      DirectorySearchField(
        controller: _search,
        hint: context.tr('Search flat, owner, phone...', 'फ्लैट, मालिक, फ़ोन खोजें...'),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 6, children: [
        _CountChip(context.tr('${_snap.flats.length} Flats', '${_snap.flats.length} फ्लैट'), primary: true),
        _CountChip(context.tr('${_snap.members.length} Members', '${_snap.members.length} सदस्य')),
        _CountChip(context.tr('${_snap.vehicles.length} Vehicles', '${_snap.vehicles.length} वाहन')),
        _CountChip(context.tr('${_snap.logins.length} Logins', '${_snap.logins.length} लॉगिन')),
      ]),
      const SizedBox(height: 16),
      if (flats.isEmpty) EmptyView(message: context.tr('No flats found', 'कोई फ्लैट नहीं मिला')),
    ];

    return LazyListPage(
      onRefresh: _load,
      header: header,
      itemCount: flats.length,
      itemBuilder: (context, i) => _flatCard(context, flats[i], query),
    );
  }

  Widget _addFlatCard(BuildContext context) {
    return CardSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.tr('Add New Flat', 'नया फ्लैट जोड़ें'), style: AppText.sectionTitle(context)),
          const SizedBox(height: 4),
          Text(
            context.tr(
              'Floor is filled automatically for 3-digit flats (101–199 → 1st Floor, … 601–699 → 6th Floor). Change it anytime for your society’s numbering.',
              '3-अंकों वाले फ्लैट के लिए मंज़िल अपने-आप भरती है (101–199 → 1st Floor, … 601–699 → 6th Floor)। अपनी सोसाइटी की नंबरिंग के अनुसार कभी भी बदलें।',
            ),
            style: AppText.tiny(context),
          ),
          const SizedBox(height: 12),
          AppTextField(
            label: context.tr('Flat no.', 'फ्लैट नं.'),
            required: true,
            hint: context.tr('e.g. 103, 607', 'जैसे 103, 607'),
            controller: _fNumber,
            onChanged: _onFlatNumberChanged,
          ),
          const SizedBox(height: 12),
          AppTextField(
            label: context.tr('Floor', 'मंज़िल'),
            hint: context.tr('Auto or e.g. Ground, 1st Floor', 'स्वतः या जैसे Ground, 1st Floor'),
            controller: _fFloor,
            onChanged: (_) => _floorTouched = true,
          ),
          const SizedBox(height: 12),
          AppTextField(label: context.tr('Wing', 'विंग'), hint: context.tr('e.g. A', 'जैसे A'), controller: _fWing),
          const SizedBox(height: 12),
          AppTextField(label: context.tr('Primary / owner name', 'प्राथमिक / मालिक का नाम'), hint: context.tr('Owner name', 'मालिक का नाम'), controller: _fOwner),
          const SizedBox(height: 12),
          AppTextField(
            label: context.tr('Owner phone', 'मालिक का फ़ोन'),
            hint: context.tr('For resident login', 'निवासी लॉगिन हेतु'),
            controller: _fOwnerPhone,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
          ),
          const SizedBox(height: 12),
          AppTextField(label: context.tr('Intercom', 'इंटरकॉम'), hint: context.tr('Optional', 'वैकल्पिक'), controller: _fIntercom),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: AppButton(label: context.tr('Add Flat', 'फ्लैट जोड़ें'), onPressed: _saveFlat)),
            const SizedBox(width: 8),
            Expanded(
              child: AppButton.secondary(
                label: context.t('common.cancel'),
                onPressed: () => setState(() {
                  _floorTouched = false;
                  _addFlatOpen = false;
                }),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _flatCard(BuildContext context, PeopleFlat flat, String query) {
    final t = context.tokens;
    final expanded = _expandedId == flat.id;
    final members = _membersByFlat[flat.id] ?? const <PeopleMember>[];
    final vehicles = _vehiclesByNumber[flat.flatNumber] ?? const <PeopleVehicle>[];
    final logins = _loginsByFlat[flat.id] ?? const <ResidentLogin>[];
    final primary = members.where((m) => m.isPrimary).firstOrNull;
    final hits = adminNameHits(members, query);

    return CardSection(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() {
              if (expanded) {
                _expandedId = null;
                if (_metaEditId == flat.id) _metaEditId = null;
              } else {
                _expandedId = flat.id;
              }
              _detail = _DetailView.manage;
            }),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                PersonAvatar(name: primary?.name ?? flat.ownerName ?? flat.flatNumber, photo: primary?.photo),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        Text(flat.flatNumber, style: AppText.mono(context, size: 14, weight: FontWeight.w600)),
                        if (flat.wing != null) TagChip(context.tr('Wing ${flat.wing}', 'विंग ${flat.wing}')),
                        if (!flat.isOccupied) TagChip.warning(context, context.tr('Vacant', 'खाली')),
                      ]),
                      const SizedBox(height: 2),
                      Text(
                        '${primary?.name ?? flat.ownerName ?? context.tr('No owner', 'कोई मालिक नहीं')} · '
                        '${context.tr('${members.length} members', '${members.length} सदस्य')} · '
                        '${context.tr('${vehicles.length} vehicles', '${vehicles.length} वाहन')}'
                        '${logins.isNotEmpty ? ' · ${context.tr('${logins.length} logins', '${logins.length} लॉगिन')}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption(context),
                      ),
                      NameHitChips(members: hits),
                    ],
                  ),
                ),
                Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 18, color: t.mutedForeground),
              ]),
            ),
          ),
          if (expanded)
            Container(
              decoration: BoxDecoration(border: Border(top: BorderSide(color: t.border))),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DetailToggle(
                    value: _detail,
                    onChanged: (v) => setState(() => _detail = v),
                  ),
                  const SizedBox(height: 12),
                  if (_detail == _DetailView.profile360)
                    Flat360ProfilePanel(
                      params: Flat360FetchParams(societyId: _sid, flatId: flat.id, flatNumber: flat.flatNumber, includeVisitors: true),
                    )
                  else
                    ..._manageSection(context, flat, members, vehicles, logins, primary),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _manageSection(
    BuildContext context,
    PeopleFlat flat,
    List<PeopleMember> members,
    List<PeopleVehicle> vehicles,
    List<ResidentLogin> logins,
    PeopleMember? primary,
  ) {
    final t = context.tokens;
    final ownerGroup = members.where((m) => m.group == 'owner').toList();
    final tenantGroup = members.where((m) => m.group == 'tenant').toList();
    final showPass = _showPassword.contains(flat.id);
    final flatPass = logins.isNotEmpty ? logins.first.password : null;

    return [
      if (_metaEditId == flat.id)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppTokens.tint(t.secondary, 0.3), borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(context.tr('Edit flat / floor', 'फ्लैट / मंज़िल संपादित करें'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.foreground)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: AppTextField(label: context.tr('Floor', 'मंज़िल'), hint: context.tr('e.g. 1st Floor, Ground', 'जैसे 1st Floor, Ground'), controller: _mFloor)),
              const SizedBox(width: 8),
              Expanded(child: AppTextField(label: context.tr('Wing', 'विंग'), hint: context.tr('Wing', 'विंग'), controller: _mWing)),
            ]),
            const SizedBox(height: 8),
            AppTextField(label: context.tr('Intercom', 'इंटरकॉम'), hint: context.tr('Intercom', 'इंटरकॉम'), controller: _mIntercom),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: AppButton(label: context.t('common.save'), dense: true, onPressed: _saveMeta)),
              const SizedBox(width: 8),
              Expanded(child: AppButton.secondary(label: context.t('common.cancel'), dense: true, onPressed: () => setState(() => _metaEditId = null))),
            ]),
          ]),
        )
      else ...[
        TwoColGrid(children: [
          InfoPair(context.tr('Floor', 'मंज़िल'), flat.floor ?? '-'),
          InfoPair(context.tr('Type', 'प्रकार'), capitalizeWords(flat.flatType)),
          InfoPair(context.tr('Owner lives here', 'मालिक यहीं रहते हैं'), flat.ownerLivesHere ? context.tr('Yes', 'हाँ') : context.tr('No', 'नहीं')),
          InfoPair(context.tr('Tenant household', 'किरायेदार परिवार'), flat.tenantHouseholdType == null ? '-' : capitalizeWords(flat.tenantHouseholdType!)),
          if (flat.wing != null) InfoPair(context.tr('Wing', 'विंग'), flat.wing!),
        ]),
        if (flat.intercom != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: InfoPair(context.tr('Intercom', 'इंटरकॉम'), flat.intercom!, mono: true),
          ),
        if (flat.ownerPhone != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: InkWell(
              onTap: () => ExportKit.call(flat.ownerPhone!),
              child: Row(children: [
                Icon(Icons.phone_outlined, size: 12, color: t.mutedForeground),
                const SizedBox(width: 4),
                Text(flat.ownerPhone!, style: AppText.mono(context, size: 12, weight: FontWeight.w600, color: t.primary)),
              ]),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => _startMetaEdit(flat),
            child: Text(context.tr('Edit floor / wing / intercom', 'मंज़िल / विंग / इंटरकॉम संपादित करें'),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: t.primary)),
          ),
        ),
      ],
      if (logins.isNotEmpty) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTokens.tint(t.primary, 0.05),
            border: Border.all(color: AppTokens.tint(t.primary, 0.1)),
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: TinyLabel(context.tr('Login Credentials', 'लॉगिन विवरण'), color: t.primary, icon: Icons.key_outlined)),
              TintIconButton(
                icon: showPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                filled: false,
                padding: 4,
                size: 14,
                color: t.mutedForeground,
                tooltip: context.tr('Show/Hide Password', 'पासवर्ड दिखाएँ/छिपाएँ'),
                onPressed: () => setState(() => showPass ? _showPassword.remove(flat.id) : _showPassword.add(flat.id)),
              ),
              TintIconButton(
                icon: Icons.refresh,
                filled: false,
                padding: 4,
                size: 14,
                color: t.mutedForeground,
                tooltip: context.tr('Reset Password', 'पासवर्ड रीसेट करें'),
                onPressed: () => _resetPassword(flat),
              ),
            ]),
            const SizedBox(height: 4),
            Text.rich(TextSpan(style: AppText.tiny(context), children: [
              TextSpan(text: context.tr('Password (shared): ', 'पासवर्ड (साझा): ')),
              TextSpan(
                text: showPass ? (flatPass ?? '') : '••••••••',
                style: AppText.mono(context, size: 11, weight: FontWeight.w600),
              ),
            ])),
            const SizedBox(height: 4),
            for (final u in logins)
              Text.rich(TextSpan(style: AppText.tiny(context), children: [
                const TextSpan(text: '📱 '),
                TextSpan(text: u.phone, style: AppText.mono(context, size: 10, color: t.mutedForeground)),
                TextSpan(text: ' — ${u.name}'),
              ])),
          ]),
        ),
      ],
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: TinyLabel(context.tr('Members (${members.length})', 'सदस्य (${members.length})'))),
        TextButton.icon(
          onPressed: () => _openMemberForm(flat),
          icon: Icon(Icons.person_add_alt_1_outlined, size: 14, color: t.primary),
          label: Text(context.t('common.add'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: t.primary)),
        ),
      ]),
      if (members.isNotEmpty) ...[
        TinyLabel(context.tr('Owner group (${ownerGroup.length})', 'मालिक समूह (${ownerGroup.length})')),
        const SizedBox(height: 4),
        if (ownerGroup.isEmpty) Text(context.tr('No owner-group members yet.', 'अभी मालिक समूह में कोई सदस्य नहीं।'), style: AppText.tiny(context)),
        for (final m in ownerGroup) _memberRow(context, flat, m),
        const SizedBox(height: 8),
        TinyLabel(context.tr('Tenant group (${tenantGroup.length})', 'किरायेदार समूह (${tenantGroup.length})')),
        const SizedBox(height: 4),
        if (tenantGroup.isEmpty) Text(context.tr('No tenant-group members yet.', 'अभी किरायेदार समूह में कोई सदस्य नहीं।'), style: AppText.tiny(context)),
        for (final m in tenantGroup) _memberRow(context, flat, m),
      ],
      if (vehicles.isNotEmpty) ...[
        const SizedBox(height: 12),
        TinyLabel(context.tr('Vehicles (${vehicles.length})', 'वाहन (${vehicles.length})')),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [for (final v in vehicles) VehicleChip(number: v.vehicleNumber, type: v.vehicleType)]),
      ],
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () => _removeFlat(flat),
          child: Text(context.tr('Remove this flat', 'यह फ्लैट हटाएँ'), style: TextStyle(fontSize: 11, color: t.destructive)),
        ),
      ),
    ];
  }

  Widget _memberRow(BuildContext context, PeopleFlat flat, PeopleMember m) {
    final t = context.tokens;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: AppTokens.tint(t.secondary, 0.5), borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PersonAvatar(name: m.name, photo: m.photo, size: PersonAvatarSize.xs),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: m.name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: t.foreground)),
                    if (m.isPrimary) TextSpan(text: '  ★ ${context.tr('Primary', 'प्राथमिक')}', style: TextStyle(fontSize: 9, color: t.primary)),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(memberDetailLine(m), style: AppText.tiny(context)),
                if (m.idPhotoFront != null || m.idPhotoBack != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(spacing: 4, children: [
                      if (m.idPhotoFront != null) ImageThumb(src: m.idPhotoFront!, width: 56, height: 36),
                      if (m.idPhotoBack != null) ImageThumb(src: m.idPhotoBack!, width: 56, height: 36),
                    ]),
                  ),
              ],
            ),
          ),
          if (!m.isPrimary && allowsPrimaryMember(m.relation))
            TintIconButton(
              icon: Icons.star_border,
              filled: false,
              padding: 4,
              size: 14,
              color: t.mutedForeground,
              tooltip: context.tr('Set primary (household only)', 'प्राथमिक बनाएँ (केवल परिवार)'),
              onPressed: () => _setPrimary(m),
            ),
          TintIconButton(
            icon: Icons.edit_outlined,
            filled: false,
            padding: 4,
            size: 14,
            color: t.mutedForeground,
            tooltip: context.tr('Edit', 'संपादित करें'),
            onPressed: () => _openMemberForm(flat, editing: m),
          ),
          TintIconButton(
            icon: Icons.delete_outline,
            filled: false,
            padding: 4,
            size: 14,
            color: t.destructive,
            tooltip: context.t('common.delete'),
            onPressed: () => _removeMember(m),
          ),
        ],
      ),
    );
  }
}

class _DetailToggle extends StatelessWidget {
  const _DetailToggle({required this.value, required this.onChanged});

  final _DetailView value;
  final ValueChanged<_DetailView> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget seg(_DetailView v, String label) {
      final on = v == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(v),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 7),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? t.background : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              boxShadow: on ? [BoxShadow(color: AppTokens.tint(t.foreground, 0.06), blurRadius: 2)] : null,
            ),
            child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: on ? t.foreground : t.mutedForeground)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: AppTokens.tint(t.secondary, 0.5), borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
      child: Row(children: [
        seg(_DetailView.manage, context.tr('Manage', 'प्रबंधन')),
        const SizedBox(width: 4),
        seg(_DetailView.profile360, context.tr('360° Profile', '360° प्रोफ़ाइल')),
      ]),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip(this.label, {this.primary = false});

  final String label;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: primary ? AppTokens.tint(t.primary, 0.1) : t.secondary,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: primary ? t.primary : t.secondaryForeground)),
    );
  }
}

/// `px-3 py-1.5 rounded-lg bg-x/10 text-x text-xs font-medium` action.
class _TintButton extends StatelessWidget {
  const _TintButton({required this.label, required this.icon, required this.color, required this.onPressed});

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: Material(
        color: AppTokens.tint(color, 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          side: BorderSide(color: AppTokens.tint(color, 0.3)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color)),
            ]),
          ),
        ),
      ),
    );
  }
}
