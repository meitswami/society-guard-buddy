import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/ui/ui.dart';
import 'data/guard_duty_service.dart';
import 'data/guard_duty_types.dart';

/// Admin review of guard duty sheets — web `src/components/guardDuty/GuardDutyReview.tsx`
/// (latest 30 sheets, expandable: absent / late staff, problem checks, incidents).
/// A body without page chrome: the admin Logs module embeds it under its "Guard duty" tab.
class GuardDutyReviewPanel extends StatefulWidget {
  const GuardDutyReviewPanel({super.key, required this.societyId});

  final String societyId;

  @override
  State<GuardDutyReviewPanel> createState() => _GuardDutyReviewPanelState();
}

class _GuardDutyReviewPanelState extends State<GuardDutyReviewPanel> {
  late Future<List<GuardDutyBundle>> _future = _fetch();

  Future<List<GuardDutyBundle>> _fetch() =>
      const GuardDutyService().fetchDutyHistory(widget.societyId);

  @override
  void didUpdateWidget(GuardDutyReviewPanel old) {
    super.didUpdateWidget(old);
    if (old.societyId != widget.societyId) _future = _fetch();
  }

  Future<void> _reload() async {
    final f = _fetch();
    setState(() => _future = f);
    try {
      await f;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return FutureBuilder<List<GuardDutyBundle>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                Text(context.t('duty.loadError'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: t.destructive)),
                const SizedBox(height: 12),
                AppButton.secondary(
                    label: context.t('mobile.retry'),
                    icon: Icons.refresh,
                    expand: false,
                    onPressed: _reload),
              ],
            ),
          );
        }
        final data = snap.data ?? const [];
        if (data.isEmpty) {
          return CardSection(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            child: Text(context.t('duty.noReports'),
                textAlign: TextAlign.center,
                style:
                    AppText.body(context).copyWith(color: t.mutedForeground)),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconPillButton(
                  icon: Icons.refresh,
                  tooltip: context.t('mobile.retry'),
                  onPressed: _reload),
            ),
            const SizedBox(height: 8),
            for (final b in data) ...[
              DutyReviewCard(bundle: b),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

/// One expandable duty sheet (web `DutyCard`).
class DutyReviewCard extends StatefulWidget {
  const DutyReviewCard({super.key, required this.bundle});

  final GuardDutyBundle bundle;

  @override
  State<DutyReviewCard> createState() => _DutyReviewCardState();
}

class _DutyReviewCardState extends State<DutyReviewCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final b = widget.bundle;
    final problems = dutyProblemChecks(b);
    final absent = dutyAbsentStaff(b);
    final date = parseDutyDate(b.duty.dutyDate);
    final summary = [
      b.duty.isSubmitted
          ? context.t('duty.alreadySubmitted')
          : context.t('duty.inProgress'),
      if (problems.isNotEmpty) '${problems.length} ${context.t('duty.issues')}',
      if (b.incidents.isNotEmpty)
        '${b.incidents.length} ${context.t('duty.reports')}',
    ].join(' · ');

    Widget group(String title, List<String> lines) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: t.mutedForeground)),
              const SizedBox(height: 8),
              for (final l in lines)
                Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(l, style: AppText.body(context))),
            ],
          ),
        );

    return CardSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(Icons.assignment_turned_in_outlined,
                      size: 20, color: t.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${date == null ? b.duty.dutyDate : DateFormat('dd MMM yyyy').format(date)} · ${b.duty.guardName}',
                        style: AppText.sectionTitle(context)
                            .copyWith(fontSize: 15),
                      ),
                      Text(summary, style: AppText.caption(context)),
                    ],
                  ),
                ),
                Icon(_open ? Icons.expand_less : Icons.expand_more,
                    size: 20, color: t.foreground),
              ],
            ),
          ),
          if (_open) ...[
            const SizedBox(height: 16),
            Divider(height: 1, color: t.border),
            const SizedBox(height: 16),
            if (absent.isNotEmpty)
              group(context.t('duty.staffTitle'), [
                for (final s in absent)
                  '${findIcon(kStaffRoles, s.staffRole)} ${context.t('duty.staff.${s.staffRole}')} — ${context.t('duty.attendance.${s.status}')}'
                      '${(s.absenceReason ?? '').isNotEmpty ? ' (${context.t('duty.absence.${s.absenceReason}')})' : ''}',
              ]),
            if (problems.isNotEmpty)
              group(context.t('duty.checksTitle'), [
                for (final c in problems)
                  '${findIcon(kSystemChecks, c.checkKey)} ${context.t('duty.check.${c.checkKey}')} — ${context.t('duty.checkStatus.${c.status}')}'
                      '${(c.problemPreset ?? '').isNotEmpty ? ' · ${context.t('duty.preset.${c.problemPreset}')}' : ''}',
              ]),
            if (b.incidents.isNotEmpty)
              group(context.t('duty.incidentTitle'), [
                for (final i in b.incidents)
                  '${findIcon(kIncidentCategories, i.category)} ${context.t('duty.incident.${i.category}')}'
                      '${(i.flatNumber ?? '').isNotEmpty ? ' · ${i.flatNumber}' : ''}'
                      ' — ${context.t('duty.severity.${i.severity}')}'
                      '${(i.problemPreset ?? '').isNotEmpty ? ' · ${context.t('duty.preset.${i.problemPreset}')}' : ''}',
              ]),
            if (absent.isEmpty && problems.isEmpty && b.incidents.isEmpty)
              Text(context.t('duty.noIssues'),
                  style:
                      AppText.body(context).copyWith(color: t.mutedForeground)),
          ],
        ],
      ),
    );
  }
}
