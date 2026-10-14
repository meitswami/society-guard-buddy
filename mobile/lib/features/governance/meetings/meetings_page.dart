import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../data/gov_backend.dart';
import '../data/meeting_repository.dart';
import '../logic/meeting_logic.dart';
import '../models/meeting_models.dart';
import '../widgets/gov_widgets.dart';
import 'meeting_detail_page.dart';
import 'meeting_print.dart';
import 'new_meeting_sheet.dart';

/// Who is using the meetings module (web `MeetingManager` props).
class MeetingViewer {
  const MeetingViewer({
    required this.societyId,
    required this.isResident,
    this.adminName = 'Admin',
    this.residentMemberId,
    this.residentName = '',
    this.residentFlatNumber = '',
  });

  final String societyId;
  final bool isResident;
  final String adminName;
  final String? residentMemberId;
  final String residentName;
  final String residentFlatNumber;
}

/// Port of web `MeetingManager.tsx` — list, type filter, prints, new notice.
/// Opening a meeting pushes [MeetingDetailPage].
class MeetingsPage extends StatefulWidget {
  const MeetingsPage({super.key, required this.viewer, this.resolveViewer});

  final MeetingViewer viewer;

  /// Resident: resolve the household member record (id / name) lazily.
  final Future<MeetingViewer> Function()? resolveViewer;

  @override
  State<MeetingsPage> createState() => _MeetingsPageState();
}

class _MeetingsPageState extends State<MeetingsPage> {
  late MeetingViewer _viewer = widget.viewer;
  late final MeetingRepository _repo =
      MeetingRepository(widget.viewer.societyId);
  List<MeetingRow> _meetings = const [];
  bool _loading = true;
  MeetingKind? _filter;
  String? _lastOpenedId;

  bool get _hi => context.lang == AppLang.hi;

  @override
  void initState() {
    super.initState();
    _load();
    final r = widget.resolveViewer;
    if (r != null) {
      r().then((v) {
        if (mounted) setState(() => _viewer = v);
      });
    }
  }

  Future<void> _load() async {
    try {
      final rows = await _repo.loadMeetings(residentOnly: _viewer.isResident);
      if (mounted) setState(() => _meetings = rows);
    } catch (e) {
      if (mounted) GovToast.error(context, GovBackend.errorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<MeetingRow> get _visible => _filter == null
      ? _meetings
      : _meetings.where((m) => m.meetingKind == _filter).toList();

  Future<void> _open(MeetingRow m) async {
    setState(() => _lastOpenedId = m.id);
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) =>
          MeetingDetailPage(viewer: _viewer, repo: _repo, initial: m),
    ));
    if (mounted) await _load();
  }

  Future<void> _newMeeting() async {
    final created = await showNewMeetingSheet(
      context,
      repo: _repo,
      societyId: _viewer.societyId,
      adminName: _viewer.adminName,
    );
    if (created == null || !mounted) return;
    await _load();
    if (mounted) await _open(created);
  }

  Future<void> _printFlat() => MeetingPrint.printFlat(
        _visible,
        _filter == null
            ? 'Meetings — current list'
            : '${_filter!.labelEn} — current list',
      );

  Future<void> _printGrouped() async {
    final ok = await MeetingPrint.printGrouped(_meetings);
    if (!ok && mounted) {
      GovToast.info(context,
          context.tr('No meetings to print.', 'प्रिंट करने को कोई बैठक नहीं।'));
    }
  }

  Widget _meetingCard(MeetingRow m) {
    final t = context.tokens;
    final selected = _lastOpenedId == m.id;
    return CardSection(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      borderColor: selected ? t.primary : null,
      onTap: () => _open(m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TinyTag(m.meetingKind.short(_hi), filled: false),
              const SizedBox(width: 8),
              Expanded(
                child: Text(m.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyMedium(context)),
              ),
              if (m.published)
                TinyTag(context.tr('Published', 'प्रकाशित'), color: t.primary),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 2,
            children: [
              Icon(Icons.calendar_today_outlined,
                  size: 12, color: t.mutedForeground),
              Text(Fmt.dateTimeFull(m.meetingAt),
                  style: AppText.caption(context).copyWith(fontSize: 11)),
              if ((m.location ?? '').isNotEmpty) ...[
                const SizedBox(width: 4),
                Icon(Icons.place_outlined, size: 12, color: t.mutedForeground),
                Text(m.location!,
                    style: AppText.caption(context).copyWith(fontSize: 11)),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
              '${context.tr('Status', 'स्थिति')}: ${meetingStatusLabel(m.status, hi: _hi)}',
              style: AppText.tiny(context)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final visible = _visible;
    return PageContainer(
      onRefresh: _load,
      children: [
        PageHeader(
          icon: Icons.groups_outlined,
          title: _viewer.isResident
              ? context.tr('Society meetings', 'सोसायटी बैठकें')
              : context.tr('Meetings', 'बैठकें'),
          subtitle: _viewer.isResident
              ? context.tr(
                  'Published meeting notices — suggest topics and propose agenda items before the day. Session records unlock on the meeting day.',
                  'प्रकाशित बैठक सूचनाएँ — दिन से पहले विषय सुझाएँ और कार्यसूची प्रस्तावित करें। सत्र अभिलेख बैठक के दिन खुलते हैं।')
              : context.tr(
                  'Create a notice (date, time, venue, purpose, agenda, documents) and notify residents. Attendance, minutes, and recording unlock on the meeting day. Published notices stay editable.',
                  'सूचना बनाएँ (तिथि, समय, स्थान, उद्देश्य, कार्यसूची, दस्तावेज़) और निवासियों को सूचित करें। उपस्थिति, कार्यवृत्त व रिकॉर्डिंग बैठक के दिन खुलते हैं। प्रकाशित सूचनाएँ संपादन योग्य रहती हैं।'),
          actions: [
            if (!_viewer.isResident)
              MiniButton(
                label: context.tr('New meeting', 'नई बैठक'),
                icon: Icons.add,
                variant: MiniVariant.primary,
                onPressed: _newMeeting,
              ),
          ],
        ),
        Text(context.tr('VIEW BY TYPE', 'प्रकार अनुसार देखें'),
            style: AppText.tiny(context)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            MiniButton(
              label: context.tr('All', 'सभी'),
              variant:
                  _filter == null ? MiniVariant.primary : MiniVariant.outline,
              fontSize: 11,
              onPressed: () => setState(() => _filter = null),
            ),
            for (final k in MeetingKind.values)
              MiniButton(
                label: k.short(_hi),
                variant:
                    _filter == k ? MiniVariant.primary : MiniVariant.outline,
                fontSize: 11,
                onPressed: () => setState(() => _filter = k),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            MiniButton(
              label: context.tr(
                  'Print list (current view)', 'सूची प्रिंट (वर्तमान दृश्य)'),
              icon: Icons.print_outlined,
              fontSize: 11,
              onPressed: _printFlat,
            ),
            MiniButton(
              label: context.tr(
                  'Print all types (grouped)', 'सभी प्रकार प्रिंट (समूहित)'),
              icon: Icons.print_outlined,
              fontSize: 11,
              onPressed: _printGrouped,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loading)
          const LoadingView()
        else if (_meetings.isEmpty)
          Text(context.tr('No meetings yet.', 'अभी कोई बैठक नहीं।'),
              style: AppText.body(context).copyWith(color: t.mutedForeground))
        else if (visible.isEmpty)
          Text(
              context.tr(
                  'No meetings in this category — pick another type or All.',
                  'इस श्रेणी में कोई बैठक नहीं — अन्य प्रकार या सभी चुनें।'),
              style: AppText.body(context).copyWith(color: t.mutedForeground))
        else
          for (final m in visible) _meetingCard(m),
      ],
    );
  }
}
