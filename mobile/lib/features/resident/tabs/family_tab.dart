import 'package:flutter/material.dart';

import '../../../core/export/export_kit.dart';
import '../../../core/ui/ui.dart';
import '../../../models/session_models.dart';
import '../data/member_rules.dart';
import '../data/pass_rules.dart';
import '../data/resident_models.dart';
import '../data/resident_repository.dart';
import '../state/resident_controllers.dart';
import '../widgets/resident_i18n.dart';
import '../widgets/resident_widgets.dart';
import 'member_form_page.dart';

/// Family & staff tab — web `tab === 'family'` (owner / tenant groups, add / edit / delete,
/// committee protection, photos, ID documents, staff vehicles). Mobile adds a WhatsApp
/// invite for members who can use the shared flat login.
class ResidentFamilyTab extends StatefulWidget {
  const ResidentFamilyTab({super.key, required this.session, required this.household, this.onChanged});

  final SessionResident session;
  final ResidentHousehold household;
  /// Called after a save / delete (vehicles may have changed).
  final VoidCallback? onChanged;

  @override
  State<ResidentFamilyTab> createState() => ResidentFamilyTabState();
}

class ResidentFamilyTabState extends State<ResidentFamilyTab> {
  final _repo = const ResidentRepository();
  bool _opening = false;

  ResidentHousehold get _h => widget.household;

  Future<void> _openForm({HouseholdMember? editing, MemberFormData? form, List<MemberDocDraft> docs = const []}) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => ResidentMemberFormPage(
        session: widget.session,
        household: _h,
        editing: editing,
        initialForm: form,
        initialDocs: docs,
      ),
    ));
    if (saved == true) {
      await _h.loadMembers();
      widget.onChanged?.call();
    }
  }

  /// Web "Add" button / `sgb_open_family_tab`.
  Future<void> openAdd() => _openForm();

  /// Web `startEditMember`.
  Future<void> startEdit(HouseholdMember m) async {
    if (_h.onCommittee(m)) {
      AppFeedback.toast(
        context,
        context.tr('This member appears on the committee roster. Only the admin can change those details.',
            'यह सदस्य समिति सूची में है। ये विवरण केवल व्यवस्थापक बदल सकते हैं।'),
        tone: BadgeTone.alert,
      );
      return;
    }
    if (_opening) return;
    setState(() => _opening = true);
    try {
      var form = memberFormFromRow(m.raw);
      final docs = await _repo.fetchMemberDocs(m.id);
      final v = await _repo.fetchMemberVehicle(m.id);
      if (v != null) {
        form = form.copyWith(
          vehicleCategory: v.vehicleType,
          vehicleName: v.displayName ?? '',
          vehicleNumber: v.vehicleNumber == 'N/A' ? '' : v.vehicleNumber,
          vehicleColor: v.color ?? '',
        );
      }
      if (!mounted) return;
      setState(() => _opening = false);
      await _openForm(editing: m, form: form, docs: docs);
    } catch (e) {
      if (!mounted) return;
      setState(() => _opening = false);
      AppFeedback.toast(context, '$e', tone: BadgeTone.alert);
    }
  }

  Future<void> _delete(HouseholdMember m) async {
    if (m.isPrimary) {
      AppFeedback.toast(context, context.tr('Cannot delete primary member', 'प्राथमिक सदस्य को हटाया नहीं जा सकता'), tone: BadgeTone.alert);
      return;
    }
    if (_h.onCommittee(m)) {
      AppFeedback.toast(
        context,
        context.tr('Committee members cannot be removed here. Contact the society admin.',
            'समिति सदस्यों को यहाँ से नहीं हटाया जा सकता। सोसाइटी व्यवस्थापक से संपर्क करें।'),
        tone: BadgeTone.alert,
      );
      return;
    }
    final ok = await AppFeedback.confirm(
      context,
      title: context.tr('Delete member?', 'सदस्य हटाएँ?'),
      message: context.tr('Remove ${m.name}?', '${m.name} को हटाएँ?'),
      confirmLabel: context.t('swal.yes'),
      cancelLabel: context.t('swal.no'),
      destructive: true,
    );
    if (!ok) return;
    try {
      await _repo.deleteMember(m, widget.session.resident.flatId);
      if (!mounted) return;
      await AppFeedback.success(context, title: context.tr('Removed!', 'हटा दिया!'), message: context.tr('Member removed successfully', 'सदस्य सफलतापूर्वक हटाया गया'));
      await _h.loadMembers();
      widget.onChanged?.call();
    } catch (e) {
      if (mounted) AppFeedback.toast(context, '$e', tone: BadgeTone.alert);
    }
  }

  Future<void> _invite(HouseholdMember m) async {
    final msg = memberInviteMessage(
      memberName: m.name,
      phone: m.phone ?? '',
      flatNumber: widget.session.resident.flatNumber,
      societyName: widget.session.societyName,
      invitedBy: widget.session.resident.name,
      hindi: context.lang == AppLang.hi,
    );
    final ok = await ExportKit.openWhatsApp(msg, phone: m.phone);
    if (!ok && mounted) AppFeedback.toast(context, context.tr('WhatsApp is not available', 'व्हाट्सऐप उपलब्ध नहीं है'), tone: BadgeTone.alert);
  }

  Widget _member(HouseholdMember m) {
    final t = context.tokens;
    final onCommittee = _h.onCommittee(m);
    final canInvite = allowsResidentLogin(m.relation) && (m.phone ?? '').isNotEmpty && digitsOnly(m.phone!) != digitsOnly(widget.session.resident.phone);
    final avatarProvider = residentImageProvider(m.photo);
    return CardSection(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppTokens.tint(t.primary, 0.1),
          backgroundImage: avatarProvider,
          child: avatarProvider == null
              ? Text(m.name.isEmpty ? '?' : m.name.characters.first.toUpperCase(),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: t.primary))
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text.rich(
              TextSpan(children: [
                TextSpan(text: m.name),
                if (m.isPrimary) TextSpan(text: '  ★ ${context.tr('Primary', 'प्राथमिक')}', style: TextStyle(fontSize: 10, color: t.primary)),
              ]),
              style: AppText.bodyMedium(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              memberSubtitle(relation: m.relation, age: m.age, gender: m.gender, phone: m.phone),
              style: AppText.tiny(context),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ]),
        ),
        if (onCommittee)
          Text(context.tr('Committee · admin only', 'समिति · केवल व्यवस्थापक'), style: AppText.tiny(context))
        else ...[
          if (canInvite)
            IconButton(
              tooltip: context.rt('resident.m.invite'),
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.send_outlined, size: 16, color: t.success),
              onPressed: () => _invite(m),
            ),
          IconButton(
            tooltip: m.isPrimary ? context.tr('Edit primary profile & photo', 'प्राथमिक प्रोफ़ाइल व फ़ोटो संपादित करें') : context.tr('Edit member', 'सदस्य संपादित करें'),
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.edit_outlined, size: 16, color: t.mutedForeground),
            onPressed: () => startEdit(m),
          ),
          if (!m.isPrimary)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.delete_outline, size: 16, color: t.mutedForeground),
              onPressed: () => _delete(m),
            ),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _h,
      builder: (context, _) {
        final members = _h.members;
        final owners = members.where((m) => memberHouseholdGroup(householdGroup: m.householdGroup, relation: m.relation) == 'owner').toList();
        final tenants = members.where((m) => memberHouseholdGroup(householdGroup: m.householdGroup, relation: m.relation) == 'tenant').toList();
        return PageContainer(
          onRefresh: () async {
            await Future.wait([_h.loadMembers(), _h.loadRoster()]);
          },
          children: [
            PageHeader(
              title: context.t('resident.family'),
              subtitle: context.tr('Family, tenants and household staff of your flat', 'आपके फ्लैट का परिवार, किरायेदार और घरेलू कर्मचारी'),
              icon: Icons.groups_outlined,
            ),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(context.tr('My Family & Staff (${members.length})', 'मेरा परिवार व कर्मचारी (${members.length})').toUpperCase(),
                      style: AppText.fieldLabel(context)),
                  const SizedBox(height: 2),
                  Text(
                    context.tr(
                        'Photos for family, servants, guards, cleaners & sweepers auto-fill election nominees and elected roster.',
                        'परिवार, सेवकों, गार्ड, सफ़ाईकर्मियों के फ़ोटो चुनाव नामांकन और निर्वाचित सूची में अपने आप भरते हैं।'),
                    style: AppText.tiny(context),
                  ),
                ]),
              ),
              const SizedBox(width: 8),
              TintAddButton(label: context.tr('Add', 'जोड़ें'), solid: true, onTap: openAdd),
            ]),
            const SizedBox(height: 12),
            if (_opening) const LinearProgressIndicator(minHeight: 2),
            if (_h.loading && members.isEmpty) const LoadingView(),
            if (_h.failed) ErrorView(onRetry: _h.loadMembers),
            if (!_h.loading && !_h.failed && members.isEmpty) EmptyView(message: context.tr('No members added yet', 'अभी तक कोई सदस्य नहीं जोड़ा गया')),
            if (members.isNotEmpty) ...[
              Text(context.tr('Owner group (${owners.length})', 'मालिक समूह (${owners.length})').toUpperCase(),
                  style: AppText.tiny(context).copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.8)),
              const SizedBox(height: 8),
              for (final m in owners) _member(m),
              const SizedBox(height: 8),
              Text(context.tr('Tenant group (${tenants.length})', 'किरायेदार समूह (${tenants.length})').toUpperCase(),
                  style: AppText.tiny(context).copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.8)),
              const SizedBox(height: 8),
              for (final m in tenants) _member(m),
            ],
          ],
        );
      },
    );
  }
}
