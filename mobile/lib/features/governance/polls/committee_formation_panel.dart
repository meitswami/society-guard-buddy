import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../data/gov_backend.dart';
import '../data/poll_repository.dart';
import '../logic/election_governance.dart';
import '../logic/election_tally.dart';
import '../models/poll_models.dart';
import '../widgets/gov_widgets.dart';

/// Port of web `CommitteeFormationPanel.tsx` — vacancy fill after tally
/// (voluntary interest + admin-proposed names; no runner-up seating).
class CommitteeFormationPanel extends StatefulWidget {
  const CommitteeFormationPanel({
    super.key,
    required this.poll,
    required this.repo,
    required this.viewer,
    required this.photoByMemberId,
    required this.onReload,
  });

  final PollRow poll;
  final PollRepository repo;
  final PollViewer viewer;
  final Map<String, String> photoByMemberId;
  final VoidCallback onReload;

  @override
  State<CommitteeFormationPanel> createState() =>
      _CommitteeFormationPanelState();
}

class _CommitteeFormationPanelState extends State<CommitteeFormationPanel> {
  final _execName = TextEditingController();
  final _execFlat = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _execName.dispose();
    _execFlat.dispose();
    super.dispose();
  }

  Future<void> _persist(String key, List<Map<String, dynamic>> entries) async {
    final results = widget.poll.electionResults;
    if (results == null) return;
    setState(() => _saving = true);
    try {
      await widget.repo.saveResults(
          widget.poll.id, resultsWithFormationEntries(results, key, entries));
      if (!mounted) return;
      GovToast.ok(context,
          context.tr('Committee formation updated', 'समिति गठन अद्यतन'));
      widget.onReload();
    } catch (e) {
      if (mounted) GovToast.error(context, GovBackend.errorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = widget.poll.electionResults;
    if (results == null) return const SizedBox.shrink();
    final t = context.tokens;
    final v = widget.viewer;
    final target = widget.poll.targetCommitteeSize;
    final formation = formationRawOf(results);
    final voluntary = formationEntries(formation, 'voluntary');
    final executive = formationEntries(formation, 'executive_proposed');
    final formed = countFormedCommittee(results);
    final remaining = (target - formed).clamp(0, 1 << 30);
    final already = v.memberId.isNotEmpty &&
        voluntary.any(
            (e) => e['member_id'] == v.memberId || e['name'] == v.memberName);

    Widget entry(Map<String, dynamic> e, VoidCallback? onRemove) {
      final mid = e['member_id'] as String?;
      final flat = (e['flat_number'] ?? '') as String;
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Expanded(
              child: PersonPhotoSide(
                name: '${e['name'] ?? ''}',
                photo: mid == null ? null : widget.photoByMemberId[mid],
                size: AvatarSize.sm,
                child: Padding(
                  padding: const EdgeInsets.only(top: 9),
                  child: Text(
                      '${e['name'] ?? ''}${flat.isNotEmpty ? ' · ${context.tr('Flat', 'फ्लैट')} $flat' : ''}',
                      style: const TextStyle(fontSize: 12)),
                ),
              ),
            ),
            if (onRemove != null)
              LinkText(context.tr('Remove', 'हटाएँ'),
                  color: t.destructive,
                  fontSize: 10,
                  onTap: _saving ? null : onRemove),
          ],
        ),
      );
    }

    return TintBox(
      color: t.warning,
      border: 0.35,
      margin: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.groups_outlined, size: 16, color: t.warning),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${context.tr('MANAGEMENT COMMITTEE', 'प्रबंध समिति')} ($minCommitteeSize ${context.tr('SEATS', 'पद')})',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                          color: t.warning),
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: '${context.tr('Progress', 'प्रगति')}: '),
                        TextSpan(
                            text: '$formed',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: t.foreground)),
                        TextSpan(text: ' / $target. '),
                        TextSpan(
                          text: remaining > 0
                              ? context.tr(
                                  '$remaining seat(s) open — fill by vacancy procedure (majority of remaining committee), not runner-up seating.',
                                  '$remaining पद रिक्त — रिक्ति प्रक्रिया (शेष समिति का बहुमत) से भरें, उपविजेता को नहीं बैठाएँ।')
                              : context.tr('Full roster.', 'सूची पूर्ण।'),
                        ),
                      ]),
                      style: AppText.caption(context).copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(context.tr('Voluntary interest', 'स्वैच्छिक रुचि'),
              style:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          if (voluntary.isEmpty)
            Text(context.tr('No volunteers yet.', 'अभी कोई स्वयंसेवक नहीं।'),
                style: AppText.tiny(context).copyWith(fontSize: 11)),
          for (final e in voluntary)
            entry(
              e,
              v.isResident
                  ? null
                  : () => _persist('voluntary',
                      voluntary.where((x) => x['key'] != e['key']).toList()),
            ),
          if (v.isResident && remaining > 0 && !already)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: MiniButton(
                  label: context.tr('I volunteer for the Committee',
                      'मैं समिति हेतु स्वेच्छा से तैयार हूँ'),
                  icon: Icons.person_add_alt_1_outlined,
                  variant: MiniVariant.warning,
                  busy: _saving,
                  onPressed: () {
                    if (v.memberName.trim().isEmpty) {
                      GovToast.error(
                          context,
                          context.tr(
                              'Your member profile is required to volunteer.',
                              'स्वयंसेवा हेतु आपकी सदस्य प्रोफ़ाइल आवश्यक है।'));
                      return;
                    }
                    final key =
                        'vol-${v.memberId.isNotEmpty ? v.memberId : v.memberName}-${v.flatNumber}';
                    if (voluntary.any((x) =>
                        x['key'] == key ||
                        (v.memberId.isNotEmpty &&
                            x['member_id'] == v.memberId))) {
                      GovToast.error(
                          context,
                          context.tr('You are already listed as a volunteer.',
                              'आप पहले से स्वयंसेवक सूची में हैं।'));
                      return;
                    }
                    final row = FormationMember(
                      key: key,
                      name: v.memberName.trim(),
                      flatNumber: v.flatNumber.isEmpty ? null : v.flatNumber,
                      flatId: v.flatId.isEmpty ? null : v.flatId,
                      memberId: v.memberId.isEmpty ? null : v.memberId,
                      source: 'voluntary',
                    ).toJson();
                    _persist('voluntary', [...voluntary, row]);
                  },
                ),
              ),
            ),
          if (!v.isResident) ...[
            const SizedBox(height: 10),
            Text(
                context.tr(
                    'Proposed for vacancy fill', 'रिक्ति हेतु प्रस्तावित'),
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            for (final e in executive)
              entry(
                  e,
                  () => _persist('executive_proposed',
                      executive.where((x) => x['key'] != e['key']).toList())),
            if (remaining > 0)
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    flex: 3,
                    child: AppTextField(
                        controller: _execName,
                        label: context.tr('Name', 'नाम'),
                        hint: context.tr('Member name', 'सदस्य का नाम'),
                        caps: false),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 2,
                    child: AppTextField(
                        controller: _execFlat,
                        label: context.tr('Flat', 'फ्लैट'),
                        hint: 'A-12',
                        caps: false),
                  ),
                  const SizedBox(width: 6),
                  MiniButton(
                    label: context.tr('Propose', 'प्रस्तावित करें'),
                    busy: _saving,
                    onPressed: () {
                      final name = _execName.text.trim();
                      if (name.isEmpty) {
                        GovToast.error(
                            context,
                            context.tr('Enter a member name.',
                                'सदस्य का नाम दर्ज करें।'));
                        return;
                      }
                      final row = FormationMember(
                        key:
                            'exec-${DateTime.now().millisecondsSinceEpoch}-$name',
                        name: name,
                        flatNumber: _execFlat.text.trim().isEmpty
                            ? null
                            : _execFlat.text.trim(),
                        source: 'executive_proposed',
                      ).toJson();
                      _execName.clear();
                      _execFlat.clear();
                      _persist('executive_proposed', [...executive, row]);
                    },
                  ),
                ],
              ),
          ],
          if (formed < minCommitteeSize)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                context.tr(
                    'Bye-laws require $minCommitteeSize Management Committee members before publishing the roster.',
                    'सूची प्रकाशित करने से पहले उपविधि के अनुसार $minCommitteeSize प्रबंध समिति सदस्य आवश्यक हैं।'),
                style: TextStyle(fontSize: 11, color: t.warning),
              ),
            ),
        ],
      ),
    );
  }
}
