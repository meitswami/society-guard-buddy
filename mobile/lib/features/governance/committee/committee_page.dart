import 'package:flutter/material.dart';

import '../../../core/export/export_kit.dart';
import '../../../core/ui/ui.dart';
import '../data/committee_repository.dart';
import '../data/gov_backend.dart';
import '../logic/committee_logic.dart';
import '../widgets/gov_widgets.dart';
import 'committee_member_form.dart';
import 'duties_chart.dart';

/// Port of web `CommitteeManager.tsx` (admin + resident).
class CommitteePage extends StatefulWidget {
  const CommitteePage({super.key, required this.societyId, required this.isResident});

  final String societyId;
  final bool isResident;

  @override
  State<CommitteePage> createState() => _CommitteePageState();
}

class _CommitteePageState extends State<CommitteePage> {
  late final CommitteeRepository _repo = CommitteeRepository(widget.societyId);
  List<CommitteeMemberRow> _rows = const [];
  List<CommitteeFlatOption> _flats = const [];
  bool _loading = true;
  bool _showPrevious = false;
  Key _dutiesKey = UniqueKey();

  bool get _hi => context.lang == AppLang.hi;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _repo.loadRoster(),
        if (!widget.isResident) _repo.loadFlats(),
      ]);
      if (!mounted) return;
      setState(() {
        _rows = results[0] as List<CommitteeMemberRow>;
        if (!widget.isResident) _flats = results[1] as List<CommitteeFlatOption>;
      });
    } catch (e) {
      if (mounted) GovToast.error(context, GovBackend.errorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() => _dutiesKey = UniqueKey());
    await _load();
  }

  Future<void> _openForm({CommitteeMemberRow? editing, required int defaultSort}) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => CommitteeMemberFormPage(
        societyId: widget.societyId,
        flats: _flats,
        editing: editing,
        defaultSortOrder: defaultSort,
      ),
    ));
    if (saved == true) await _load();
  }

  Future<void> _remove(CommitteeMemberRow row) async {
    final ok = await govConfirm(
      context,
      title: context.tr('Remove member?', 'सदस्य हटाएँ?'),
      message: context.tr('${row.name} will be removed from the committee list.', '${row.name} समिति सूची से हटाए जाएँगे।'),
      confirmLabel: context.tr('Remove', 'हटाएँ'),
      destructive: true,
    );
    if (!ok) return;
    try {
      await _repo.removeMember(row.id);
      if (!mounted) return;
      GovToast.ok(context, context.tr('Removed', 'हटाया गया'));
      await _load();
    } catch (e) {
      if (mounted) GovToast.error(context, GovBackend.errorText(e));
    }
  }

  Widget _phoneLink(String phone, {double size = 12}) {
    final t = context.tokens;
    return InkWell(
      onTap: () => ExportKit.call(phone),
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.phone_outlined, size: size, color: t.mutedForeground),
            const SizedBox(width: 4),
            Text(phone, style: AppText.mono(context, size: size, color: t.mutedForeground)),
          ],
        ),
      ),
    );
  }

  Widget _card(CommitteeMemberRow row) {
    final t = context.tokens;
    final labels = committeeDisplayLabels(row, hi: _hi);
    final tenure = committeeTenureLabel(termFrom: row.termFrom, termTo: row.termTo, hi: _hi);
    final showFemaleRep = row.gender == 'female' && row.showRepresentative && (row.repName ?? '').isNotEmpty;
    String d(String s) => Fmt.isoToDisplay(s.substring(0, s.length >= 10 ? 10 : s.length));
    return CardSection(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PersonAvatar(name: labels.primaryName, photo: row.photo, size: AvatarSize.xl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(labels.primaryName, style: AppText.sectionTitle(context)),
                    Text(positionLabel(row.position, hi: _hi),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: t.primary)),
                    if (labels.subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(labels.subtitle!, style: AppText.tiny(context)),
                      ),
                    if (row.selectionType != null && row.selectionType!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: TinyTag(selectionTypeLabel(row.selectionType, hi: _hi)),
                      ),
                    if (tenure != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${context.tr('Tenure', 'कार्यकाल')}: ${d(row.termFrom!)} → ${row.termTo != null && row.termTo!.isNotEmpty ? d(row.termTo!) : context.tr('Until retirement', 'सेवानिवृत्ति तक')}',
                          style: AppText.tiny(context),
                        ),
                      ),
                    if ((row.phone ?? '').isNotEmpty) _phoneLink(row.phone!),
                  ],
                ),
              ),
              if (!widget.isResident) ...[
                IconPillButton(
                  icon: Icons.edit_outlined,
                  tooltip: context.tr('Edit', 'संपादित'),
                  color: t.secondaryForeground,
                  onPressed: () => _openForm(editing: row, defaultSort: row.sortOrder),
                ),
                const SizedBox(width: 4),
                IconPillButton(
                  icon: Icons.delete_outline,
                  tooltip: context.tr('Remove', 'हटाएँ'),
                  color: t.destructive,
                  background: AppTokens.tint(t.destructive, 0.1),
                  onPressed: () => _remove(row),
                ),
              ],
            ],
          ),
          if (labels.isRepresentative && !showFemaleRep) ...[
            Divider(height: 24, color: t.border),
            Row(
              children: [
                Icon(Icons.groups_outlined, size: 12, color: t.mutedForeground),
                const SizedBox(width: 4),
                Flexible(child: Text(context.tr('REPRESENTATIVE FOR THIS POST', 'इस पद के प्रतिनिधि'), style: AppText.tiny(context))),
              ],
            ),
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(children: [
                TextSpan(text: '${context.tr('Flat owner', 'फ्लैट स्वामी')}: '),
                TextSpan(
                  text: row.flatOwnerName ?? '',
                  style: TextStyle(color: t.foreground, fontWeight: FontWeight.w500),
                ),
              ]),
              style: AppText.caption(context),
            ),
          ],
          if (showFemaleRep) ...[
            Divider(height: 24, color: t.border),
            Row(
              children: [
                Icon(Icons.groups_outlined, size: 12, color: t.mutedForeground),
                const SizedBox(width: 4),
                Flexible(child: Text(context.tr('REPRESENTATIVE CONTACT', 'प्रतिनिधि संपर्क'), style: AppText.tiny(context))),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppTokens.tint(t.secondary, 0.5),
                borderRadius: BorderRadius.circular(AppTokens.radiusSm),
              ),
              child: Row(
                children: [
                  PersonAvatar(name: row.repName ?? 'R', photo: row.repPhoto, size: AvatarSize.sm),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (row.repName ?? '').isEmpty ? context.tr('Representative', 'प्रतिनिधि') : row.repName!,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        if ((row.repPhone ?? '').isNotEmpty) _phoneLink(row.repPhone!, size: 10),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final split = splitCommitteeTerms(_rows);
    final displayed = _showPrevious ? split.previous : split.current;
    final hasPrevious = split.previous.isNotEmpty;
    final title = _showPrevious
        ? context.t('committee.previousYearTitle')
        : widget.isResident
            ? context.t('committee.managingTitle')
            : context.t('committee.membersTitle');
    final hint = _showPrevious
        ? context.t('committee.previousYearHint')
        : widget.isResident
            ? context.t('committee.residentHint')
            : context.t('committee.adminHint');
    return PageContainer(
      onRefresh: _refresh,
      children: [
        PageHeader(
          icon: Icons.account_balance_outlined,
          title: title,
          subtitle: hint,
          actions: [
            if (hasPrevious)
              MiniButton(
                label: _showPrevious ? context.t('committee.currentButton') : context.t('committee.previousYearButton'),
                icon: Icons.history,
                variant: MiniVariant.secondary,
                onPressed: () => setState(() => _showPrevious = !_showPrevious),
              ),
            if (!widget.isResident && !_showPrevious) ...[
              const SizedBox(width: 6),
              MiniButton(
                label: context.tr('Add', 'जोड़ें'),
                icon: Icons.add,
                variant: MiniVariant.primary,
                onPressed: () => _openForm(defaultSort: displayed.length),
              ),
            ],
          ],
        ),
        if (!_showPrevious) CommitteeDutiesChart(key: _dutiesKey, societyId: widget.societyId, isResident: widget.isResident),
        if (_loading)
          Text(context.tr('Loading…', 'लोड हो रहा है…'), style: AppText.caption(context))
        else if (displayed.isEmpty)
          CardSection(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            child: Column(
              children: [
                Icon(Icons.account_circle_outlined, size: 40, color: AppTokens.tint(t.mutedForeground, 0.5)),
                const SizedBox(height: 8),
                Text(
                  _showPrevious
                      ? context.t('committee.previousEmpty')
                      : widget.isResident
                          ? context.t('committee.residentEmpty')
                          : context.t('committee.adminEmpty'),
                  textAlign: TextAlign.center,
                  style: AppText.body(context).copyWith(color: t.mutedForeground),
                ),
              ],
            ),
          )
        else
          for (final r in displayed) _card(r),
      ],
    );
  }
}
